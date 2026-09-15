import { act } from 'react';
import { createRoot } from 'react-dom/client';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { CaptainPage } from '../HostPage';

const mocks = vi.hoisted(() => ({
  stop: vi.fn(), captureFrame: vi.fn(() => 'jpeg'), sendPreviewFrame: vi.fn(),
  startCamera: vi.fn(), startSession: vi.fn(), capturePhoto: vi.fn(() => "photo"), sendFinalPhoto: vi.fn(),
}));
vi.mock('../CameraCapture', () => ({ startCamera: mocks.startCamera }));
vi.mock('../components/QRCodePanel', () => ({ QRCodePanel: () => null }));
vi.mock('../CaptainClient', () => ({ CaptainClient: class {
  subscribe(listener: (state: unknown) => void) {
    listener({ status: 'active', sessionCode: 'ABC123', participants: [] });
    return () => {};
  }
  stop() {}
  startSession = mocks.startSession;
  sendPreviewFrame = mocks.sendPreviewFrame;
  sendFinalPhoto = mocks.sendFinalPhoto;
} }));
let container: HTMLDivElement;
let root: ReturnType<typeof createRoot>;
beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true });
  vi.spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue();
  container = document.createElement('div');
  document.body.append(container);
  root = createRoot(container);
  mocks.startCamera.mockResolvedValue({ stream: {}, stop: mocks.stop, captureFrame: mocks.captureFrame, capturePhoto: mocks.capturePhoto });
});
afterEach(async () => {
  await act(async () => root.unmount());
  container.remove();
  vi.useRealTimers();
  vi.restoreAllMocks();
});
const mount = () => act(async () => { root.render(<MemoryRouter><CaptainPage /></MemoryRouter>); });
it('stops the camera when the host page unmounts', async () => {
  await mount();
  await act(async () => root.unmount());
  expect(mocks.stop).toHaveBeenCalled();
});
it('applies preview quality and size settings to captured frames', async () => {
  await mount();
  await act(async () => container.querySelector<HTMLButtonElement>('[aria-label="Settings"]')!.click());
  for (const label of ['70%', '480p']) {
    await act(async () => Array.from(container.querySelectorAll('button')).find(b => b.textContent === label)!.click());
  }
  await act(async () => vi.advanceTimersByTime(334));
  expect(mocks.captureFrame).toHaveBeenLastCalledWith(0.7, 480);
});
it('stops a late camera result without creating a session after navigation', async () => {
  let resolve!: (camera: unknown) => void;
  mocks.startCamera.mockReturnValue(new Promise(r => { resolve = r; }));
  await mount();
  await act(async () => root.unmount());
  await act(async () => resolve({ stream: {}, stop: mocks.stop }));
  expect(mocks.stop).toHaveBeenCalled();
  expect(mocks.startSession).not.toHaveBeenCalled();
});

it('cancelling the countdown prevents capture', async () => {
  await mount();
  const button = (label: string) => Array.from(container.querySelectorAll('button')).find(b => b.textContent?.includes(label))!;
  await act(async () => button('Start 10s').click());
  await act(async () => button('Cancel').click());
  await act(async () => vi.advanceTimersByTimeAsync(11000));
  expect(mocks.capturePhoto).not.toHaveBeenCalled();
  expect(mocks.sendFinalPhoto).not.toHaveBeenCalled();
});
it('shows the supported captain-only trigger policy', async () => {
  await mount();
  await act(async () => container.querySelector<HTMLButtonElement>('[aria-label="Settings"]')!.click());
  expect(container.textContent).toContain('The captain controls the timer and shutter in browser-hosted sessions.');
  expect(container.textContent).not.toContain('Pirate can trigger');
});
