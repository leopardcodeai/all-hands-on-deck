import test from 'node:test';
import assert from 'node:assert/strict';
import { createLiveKitToken } from '../src/livekitToken.js';

test('LiveKit token endpoint requires session and participant ids', async () => {
  const result = await createLiveKitToken({}, {});

  assert.equal(result.status, 400);
  assert.equal(result.body.error, 'session_id and participant_id are required');
});

test('LiveKit token endpoint fails gracefully when beta env is missing', async () => {
  const result = await createLiveKitToken({ session_id: 'ABC123', participant_id: 'p1' }, {});

  assert.equal(result.status, 503);
  assert.match(String(result.body.error), /LIVEKIT_API_SECRET/);
});
