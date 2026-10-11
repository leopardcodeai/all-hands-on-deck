import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RoomRegistry, OPEN, parseJoinParams, type Member } from '../src/rooms.js';

interface FakeSocket {
  readyState: number;
  sent: Array<string | Buffer>;
  send(payload: string | Buffer): void;
}

function fakeSocket(open = true): FakeSocket {
  const s: FakeSocket = {
    readyState: open ? OPEN : 0,
    sent: [],
    send(payload) { this.sent.push(payload); }
  };
  return s;
}

function makeMember(role: 'host' | 'viewer', id: string, ws: FakeSocket): Member<FakeSocket> {
  return { ws, role, participantId: id, joinedAt: 0 };
}

test('getOrCreate returns the same room for repeated sessionIds', () => {
  const r = new RoomRegistry<FakeSocket>();
  const a = r.getOrCreate('S1');
  const b = r.getOrCreate('S1');
  assert.equal(a, b);
  assert.equal(r.size, 1);
});

test('host broadcasts to every viewer but not itself', () => {
  const r = new RoomRegistry<FakeSocket>();
  const room = r.getOrCreate('S1');

  const hostWs = fakeSocket();
  const v1 = fakeSocket();
  const v2 = fakeSocket();
  const host = makeMember('host', 'h', hostWs);
  const viewer1 = makeMember('viewer', 'v1', v1);
  const viewer2 = makeMember('viewer', 'v2', v2);
  room.members.add(host);
  room.members.add(viewer1);
  room.members.add(viewer2);

  const delivered = r.route(room, host, 'frame-payload');
  assert.equal(delivered, 2);
  assert.equal(hostWs.sent.length, 0);
  assert.deepEqual(v1.sent, ['frame-payload']);
  assert.deepEqual(v2.sent, ['frame-payload']);
});

test('viewer messages are forwarded to host only', () => {
  const r = new RoomRegistry<FakeSocket>();
  const room = r.getOrCreate('S1');

  const hostWs = fakeSocket();
  const v1 = fakeSocket();
  const v2 = fakeSocket();
  const host = makeMember('host', 'h', hostWs);
  const viewer1 = makeMember('viewer', 'v1', v1);
  const viewer2 = makeMember('viewer', 'v2', v2);
  room.members.add(host);
  room.members.add(viewer1);
  room.members.add(viewer2);

  const delivered = r.route(room, viewer1, 'capture-request');
  assert.equal(delivered, 1);
  assert.deepEqual(hostWs.sent, ['capture-request']);
  assert.equal(v2.sent.length, 0);
});

test('closed sockets are skipped during routing', () => {
  const r = new RoomRegistry<FakeSocket>();
  const room = r.getOrCreate('S1');

  const hostWs = fakeSocket();
  const liveWs = fakeSocket();
  const deadWs = fakeSocket(false); // CLOSED

  room.members.add(makeMember('host', 'h', hostWs));
  room.members.add(makeMember('viewer', 'live', liveWs));
  room.members.add(makeMember('viewer', 'dead', deadWs));

  const host = [...room.members][0];
  const delivered = r.route(room, host, 'p');
  assert.equal(delivered, 1, 'only the open viewer receives');
  assert.equal(deadWs.sent.length, 0);
  assert.equal(liveWs.sent.length, 1);
});

test('removeMember drops the room when last member leaves', () => {
  const r = new RoomRegistry<FakeSocket>();
  const room = r.getOrCreate('S1');
  const m = makeMember('viewer', 'v', fakeSocket());
  room.members.add(m);

  const wasEmptied = r.removeMember(room, m);
  assert.equal(wasEmptied, true);
  assert.equal(r.has('S1'), false);
});

test('removeMember keeps the room alive while members remain', () => {
  const r = new RoomRegistry<FakeSocket>();
  const room = r.getOrCreate('S1');
  const m1 = makeMember('host', 'h', fakeSocket());
  const m2 = makeMember('viewer', 'v', fakeSocket());
  room.members.add(m1);
  room.members.add(m2);

  const wasEmptied = r.removeMember(room, m2);
  assert.equal(wasEmptied, false);
  assert.equal(r.has('S1'), true);
});

test('reap removes only empty + idle rooms', () => {
  const r = new RoomRegistry<FakeSocket>();
  const old = r.getOrCreate('OLD', 0);
  const fresh = r.getOrCreate('FRESH', 0);
  const occupied = r.getOrCreate('OCCUPIED', 0);
  occupied.members.add(makeMember('host', 'h', fakeSocket()));

  // Touch FRESH so it's not "idle".
  fresh.lastActivity = 9_999;

  const dropped = r.reap(/* ttlMs */ 1_000, /* now */ 10_000);
  assert.equal(dropped, 1, 'only OLD is reaped');
  assert.equal(r.has('OLD'), false);
  assert.equal(r.has('FRESH'), true);
  assert.equal(r.has('OCCUPIED'), true);
  void old;
});

test('parseJoinParams accepts valid combos', () => {
  const q = new URLSearchParams('session=ABC&role=host&pid=p1');
  assert.deepEqual(parseJoinParams(q), { sessionId: 'ABC', role: 'host', participantId: 'p1' });

  const q2 = new URLSearchParams('session=ABC&role=viewer&pid=p2');
  assert.deepEqual(parseJoinParams(q2), { sessionId: 'ABC', role: 'viewer', participantId: 'p2' });
});

test('parseJoinParams rejects invalid input', () => {
  assert.equal(parseJoinParams(new URLSearchParams('')), null);
  assert.equal(parseJoinParams(new URLSearchParams('session=A')), null);
  assert.equal(parseJoinParams(new URLSearchParams('session=A&role=admin&pid=p')), null);
  assert.equal(parseJoinParams(new URLSearchParams('role=host&pid=p')), null);
  assert.equal(parseJoinParams(new URLSearchParams('session=A&role=host')), null);
});

test('host() returns the only host or undefined', () => {
  const r = new RoomRegistry<FakeSocket>();
  const room = r.getOrCreate('S');
  assert.equal(r.host(room), undefined);

  const h = makeMember('host', 'h', fakeSocket());
  room.members.add(h);
  assert.equal(r.host(room), h);

  // viewer-only room has no host.
  const room2 = r.getOrCreate('S2');
  room2.members.add(makeMember('viewer', 'v', fakeSocket()));
  assert.equal(r.host(room2), undefined);
});
