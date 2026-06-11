type LogLevel = 'info' | 'warn' | 'error';

interface LogEntry {
  t: string;
  l: LogLevel;
  c: string;
  m: string;
  d?: Record<string, unknown>;
}

const MAX_ENTRIES = 200;
const buffer: LogEntry[] = [];

function log(level: LogLevel, component: string, message: string, data?: Record<string, unknown>) {
  const entry: LogEntry = {
    t: new Date().toISOString(),
    l: level,
    c: component,
    m: message,
    d: data,
  };
  buffer.push(entry);
  if (buffer.length > MAX_ENTRIES) buffer.shift();

  const prefix = `[${component}]`;
  switch (level) {
    case 'error':
      console.error(prefix, message, data ?? '');
      break;
    case 'warn':
      console.warn(prefix, message, data ?? '');
      break;
    default:
      console.log(prefix, message, data ?? '');
  }
}

async function persistToSupabase(entry: LogEntry) {
  try {
    // Dynamic import keeps @supabase/supabase-js out of the entry chunk —
    // the landing page imports the logger but must not ship the SDK.
    const { getSupabaseClient } = await import('./supabase');
    await getSupabaseClient().from('logs').insert({
      level: entry.l,
      component: entry.c,
      message: entry.m,
      data: entry.d ?? {},
      created_at: entry.t,
    });
  } catch {}
}

export const logger = {
  info: (c: string, m: string, d?: Record<string, unknown>) => {
    const entry = logToEntry('info', c, m, d);
    log('info', c, m, d);
    void persistToSupabase(entry);
  },
  warn: (c: string, m: string, d?: Record<string, unknown>) => {
    const entry = logToEntry('warn', c, m, d);
    log('warn', c, m, d);
    void persistToSupabase(entry);
  },
  error: (c: string, m: string, d?: Record<string, unknown>) => {
    const entry = logToEntry('error', c, m, d);
    log('error', c, m, d);
    void persistToSupabase(entry);
  },

  getEntries: () => [...buffer],

  sendToServer: async () => {
    try {
      await fetch('/api/log', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ entries: buffer }),
      });
    } catch {}
  },
};

function logToEntry(l: LogLevel, c: string, m: string, d?: Record<string, unknown>): LogEntry {
  return { t: new Date().toISOString(), l, c, m, d };
}
