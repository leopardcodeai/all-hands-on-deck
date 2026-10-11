import type { VercelRequest, VercelResponse } from '@vercel/node';

export default function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'POST only' });
    return;
  }

  const { entries } = req.body as { entries?: Array<{ t: string; l: string; c: string; m: string; d?: unknown }> };
  if (!entries || !Array.isArray(entries)) {
    res.status(400).json({ error: 'entries array required' });
    return;
  }

  for (const entry of entries) {
    const prefix = `[${entry.c}][${entry.l}]`;
    if (entry.l === 'error') {
      console.error(prefix, entry.m, entry.d ?? '');
    } else {
      console.log(prefix, entry.m, entry.d ?? '');
    }
  }

  res.status(200).json({ ok: true, count: entries.length });
}
