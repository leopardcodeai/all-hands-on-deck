import { logger } from './lib/logger';

export interface CameraCapture {
  stream: MediaStream;
  stop: () => void;
  captureFrame: (quality?: number, width?: number) => string;
  capturePhoto: (quality?: number) => string;
}

export async function startCamera(): Promise<CameraCapture> {
  logger.info('Camera', 'Requesting camera access');
  const stream = await navigator.mediaDevices.getUserMedia({
    video: { width: { ideal: 1280 }, height: { ideal: 720 } },
    audio: false,
  });
  logger.info('Camera', 'Camera access granted', { tracks: stream.getTracks().length });

  const video = document.createElement('video');
  video.srcObject = stream;
  video.playsInline = true;
  video.muted = true;
  await video.play();
  logger.info('Camera', 'Video element playing', { width: video.videoWidth, height: video.videoHeight });

  const PHOTO_WIDTH = 1080;

  const toBase64 = (canvas: HTMLCanvasElement, quality: number): string => {
    return canvas.toDataURL('image/jpeg', quality).replace(/^data:image\/\w+;base64,/, '');
  };

  return {
    stream,
    stop: () => {
      logger.info('Camera', 'Stopping camera');
      stream.getTracks().forEach(t => t.stop());
      video.pause();
      video.srcObject = null;
    },
    captureFrame: (quality = 0.3, width = 240) => {
      try {
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = width / (video.videoWidth / video.videoHeight || 1.5);
        const ctx = canvas.getContext('2d')!;
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        return toBase64(canvas, quality);
      } catch (e) {
        logger.error('Camera', 'Frame capture failed', { error: String(e) });
        return '';
      }
    },
    capturePhoto: (quality = 0.85) => {
      try {
        const canvas = document.createElement('canvas');
        canvas.width = Math.min(PHOTO_WIDTH, video.videoWidth || PHOTO_WIDTH);
        canvas.height = canvas.width / (video.videoWidth / video.videoHeight || 1.5);
        const ctx = canvas.getContext('2d')!;
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        const data = toBase64(canvas, quality);
        logger.info('Camera', 'Photo captured', { width: canvas.width, height: canvas.height, size: data.length });
        return data;
      } catch (e) {
        logger.error('Camera', 'Photo capture failed', { error: String(e) });
        return '';
      }
    },
  };
}
