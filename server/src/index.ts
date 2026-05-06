/**
 * All Hands on Deck — minimal signaling/relay server.
 *
 * Responsibilities:
 *  - Accept WebSocket connections at /ws
 *  - Each client joins a "room" keyed by sessionId, with a role ("host" | "viewer")
 *  - Relay binary frames + JSON control envelopes from host to all viewers in the
 *    same room (and viewer→host for control events like captureRequested)
 *  - Garbage-collect empty rooms; sessions auto-expire after TTL_MS of inactivity
 *
 * Wire format mirrors the iOS `SessionWireMessage` envelope so the same JSON
 * decoder works on both sides. Preview frames piggy-back on the same JSON
 * envelope (binary blob is base64-encoded inside `event.previewFrame.jpeg`).
 */

import { WebSocketServer, WebSocket } from 'ws';
import { createServer, IncomingMessage, ServerResponse } from 'http';
import { URL } from 'url';
import { readFile } from 'fs/promises';
import { join, extname, dirname } from 'path';
import { fileURLToPath } from 'url';
import { RoomRegistry, parseJoinParams, type Member, type JoinParams } from './rooms.js';
import { createLiveKitToken } from './livekitToken.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PUBLIC_DIR = join(__dirname, '..', 'public');

const MIME_TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.js':   'application/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.svg':  'image/svg+xml'
};

const PORT = Number(process.env.PORT ?? 8787);
const TTL_MS = 30 * 60 * 1000; // 30 minutes idle → garbage collect

const registry = new RoomRegistry<WebSocket>();

// ---- HTTP server with health endpoint --------------------------------------

async function serveStatic(path: string, res: ServerResponse): Promise<boolean> {
  try {
    const filePath = join(PUBLIC_DIR, path);
    if (!filePath.startsWith(PUBLIC_DIR)) return false; // path traversal guard
    const data = await readFile(filePath);
    const mime = MIME_TYPES[extname(filePath)] ?? 'application/octet-stream';
    // Apple specifically requires the AASA to be served as application/json
    // with no extension; the readFile + content-type combo handles that.
    if (path.endsWith('apple-app-site-association')) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
    } else {
      res.writeHead(200, { 'Content-Type': mime });
    }
    res.end(data);
    return true;
  } catch {
    return false;
  }
}

const httpServer = createServer(async (req: IncomingMessage, res: ServerResponse) => {
  const url = new URL(req.url ?? '/', `http://${req.headers.host}`);

  if (url.pathname === '/api/livekit/token' && req.method === 'POST') {
    const body = await readJsonBody(req);
    const result = await createLiveKitToken(body);
    res.writeHead(result.status, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(result.body));
    return;
  }

  if (url.pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok: true,
      rooms: registry.size,
      uptime: process.uptime()
    }));
    return;
  }

  // Apple Universal Links validation file. Must be accessible at exactly
  // `/.well-known/apple-app-site-association` over HTTPS in prod.
  if (url.pathname === '/.well-known/apple-app-site-association' ||
      url.pathname === '/apple-app-site-association') {
    await warnIfPlaceholderAASA();
    if (await serveStatic('.well-known/apple-app-site-association', res)) return;
  }

  // Otherwise: try serving from public/, falling back to index.html so the
  // SPA's client-side router can take over (`/join/<id>` etc.).
  const trimmed = url.pathname.replace(/^\/+/, '');
  if (trimmed && await serveStatic(trimmed, res)) return;
  if (await serveStatic('index.html', res)) return;

  res.writeHead(404);
  res.end();
});

async function readJsonBody(req: IncomingMessage): Promise<Record<string, unknown>> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  if (chunks.length === 0) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8')) as Record<string, unknown>;
  } catch {
    return {};
  }
}

const wss = new WebSocketServer({ noServer: true });

httpServer.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url ?? '/', `http://${req.headers.host}`);
  if (url.pathname !== '/ws') {
    socket.destroy();
    return;
  }
  const params = parseJoinParams(url.searchParams);
  if (!params) {
    socket.destroy();
    return;
  }

  wss.handleUpgrade(req, socket, head, (ws) => {
    handleConnection(ws, params);
  });
});

function handleConnection(ws: WebSocket, p: JoinParams) {
  const room = registry.getOrCreate(p.sessionId);

  // Only one host per room.
  if (p.role === 'host' && registry.host(room)) {
    ws.send(JSON.stringify({ kind: 'error', reason: 'host_already_present' }));
    ws.close(1008, 'host_already_present');
    return;
  }

  const member: Member<WebSocket> = {
    ws,
    role: p.role,
    participantId: p.participantId,
    joinedAt: Date.now()
  };
  room.members.add(member);
  room.lastActivity = Date.now();

  ws.send(JSON.stringify({ kind: 'joined', sessionId: p.sessionId, role: p.role }));

  // Notify host of viewer join so it can broadcast metadata back.
  if (p.role === 'viewer') {
    const h = registry.host(room);
    if (h) {
      h.ws.send(JSON.stringify({
        kind: 'viewerJoined',
        participantId: p.participantId
      }));
    }
  }

  ws.on('message', (data, isBinary) => {
    room.lastActivity = Date.now();
    const payload = isBinary ? (data as Buffer) : data.toString();
    registry.route(room, member, payload);
  });

  ws.on('close', () => {
    if (member.role === 'host') {
      // Tell every viewer the session ended, then drop the room.
      const sessionEnded = JSON.stringify({
        sessionId: p.sessionId,
        senderId: 'server',
        createdAt: new Date().toISOString(),
        event: { sessionEnded: {} }
      });
      registry.broadcast(room, sessionEnded, member);
      registry.delete(p.sessionId);
    } else {
      registry.removeMember(room, member);
      const h = registry.host(room);
      if (h) {
        h.ws.send(JSON.stringify({
          kind: 'viewerLeft',
          participantId: p.participantId
        }));
      }
    }
  });

  ws.on('error', () => {
    // Silent close; the close handler will tear down state.
  });
}

// ---- Idle cleanup -----------------------------------------------------------

// Warn — once, loudly — if the deployed AASA still has the TEAMID
// placeholder in it. swcd caches AASAs for ~24h, so silently shipping
// a broken file means a full day of dead Universal Links.
let aasaWarned = false;
async function warnIfPlaceholderAASA(): Promise<void> {
  if (aasaWarned) return;
  try {
    const data = await readFile(join(PUBLIC_DIR, '.well-known/apple-app-site-association'), 'utf8');
    if (data.includes('TEAMID')) {
      console.warn(
        '\n[allhands] ⚠️  apple-app-site-association still contains the TEAMID ' +
        'placeholder. Replace it with your real Apple Team ID before relying ' +
        'on Universal Links — iOS will silently mark this domain unverified ' +
        'and cache the failure for ~24h.\n'
      );
    }
  } catch { /* file missing, no warning needed */ }
  aasaWarned = true;
}

setInterval(() => registry.reap(TTL_MS), 60_000).unref();

httpServer.listen(PORT, () => {
  console.log(`[allhands] signaling server listening on :${PORT}`);
});
