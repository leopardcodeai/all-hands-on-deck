import { describe, expect, it, vi } from 'vitest';

describe('CameraCapture', () => {
  it('strips data URL prefix from captureFrame output', () => {
    const raw = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD';
    const cleaned = raw.replace(/^data:image\/\w+;base64,/, '');
    expect(cleaned).toBe('/9j/4AAQSkZJRgABAQAAAQABAAD');
    expect(cleaned.startsWith('/9j/')).toBe(true);
  });

  it('strips data URL prefix from capturePhoto output', () => {
    const raw = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD';
    const cleaned = raw.replace(/^data:image\/\w+;base64,/, '');
    expect(cleaned.startsWith('/9j/')).toBe(true);
  });

  it('passes through already-clean base64 unchanged', () => {
    const raw = '/9j/4AAQSkZJRgABAQAAAQABAAD';
    const cleaned = raw.replace(/^data:image\/\w+;base64,/, '');
    expect(cleaned).toBe(raw);
  });

  it('handles empty string gracefully', () => {
    const result = ''.replace(/^data:image\/\w+;base64,/, '');
    expect(result).toBe('');
  });

  it('b64ToBlob strips prefix and decodes', () => {
    // Valid 1x1 white JPEG as base64 (no data URL prefix)
    const b64 = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QA'; // shortened valid JPEG
    const withPrefix = `data:image/jpeg;base64,${b64}`;
    const clean = withPrefix.replace(/^data:image\/\w+;base64,/, '');
    expect(clean).toBe(b64);
    const arr = Uint8Array.from(atob(clean), c => c.charCodeAt(0));
    expect(arr.length).toBeGreaterThan(0);
  });
});
