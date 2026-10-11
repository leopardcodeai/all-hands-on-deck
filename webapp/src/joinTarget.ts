const SESSION_CODE = /^[A-Z0-9]{6,10}$/i;

/** Convert a code or invite to a local route without changing token case. */
export function parseJoinTarget(input: string): string | null {
  const value = input.trim();
  if (SESSION_CODE.test(value)) return `/join/${value.toUpperCase()}`;
  if (!/^https?:\/\//i.test(value) && !value.startsWith('/join/')) return null;
  try {
    const url = new URL(value, 'https://join.invalid');
    const match = url.pathname.match(/^\/join\/([A-Z0-9]{6,10})\/?$/i);
    if (!match) return null;
    // Navigate locally, even when the invitation came from another host.
    return `/join/${match[1].toUpperCase()}${url.search}`;
  } catch {
    return null;
  }
}
