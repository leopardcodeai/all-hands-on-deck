interface DebugState {
  framesReceived: number;
  framesPerSecond: number;
  firebaseEvents: number;
  lastEvent: string;
  lastEvents: string[];
  status: string;
  transport: string;
  sessionId: string;
}

let frameTickStart = Date.now();
let frameTickCount = 0;
const state: DebugState = {
  framesReceived: 0,
  framesPerSecond: 0,
  firebaseEvents: 0,
  lastEvent: '',
  lastEvents: [],
  status: 'idle',
  transport: '—',
  sessionId: '',
};

export function getDebugState(): Readonly<DebugState> {
  return state;
}

export function recordFrame() {
  state.framesReceived++;
  frameTickCount++;
  const elapsed = Date.now() - frameTickStart;
  if (elapsed >= 1000) {
    state.framesPerSecond = Math.round((frameTickCount / elapsed) * 1000);
    frameTickCount = 0;
    frameTickStart = Date.now();
  }
}

export function recordEvent(label: string) {
  state.firebaseEvents++;
  state.lastEvent = label;
  state.lastEvents.push(label);
  if (state.lastEvents.length > 5) state.lastEvents.shift();
}

export function setDebugSessionId(id: string) { state.sessionId = id; }
export function setDebugStatus(s: string) { state.status = s; }
export function setDebugTransport(t: string) { state.transport = t; }
