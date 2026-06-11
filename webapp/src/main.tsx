import React, { Suspense } from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { logger } from './lib/logger';
import './styles.css';

// Route-level code splitting: the landing page must not pull in the
// Supabase/session/camera code that only /host and /join need.
const HomePage = React.lazy(() => import('./HomePage').then(m => ({ default: m.HomePage })));
const CaptainPage = React.lazy(() => import('./HostPage').then(m => ({ default: m.CaptainPage })));
const JoinPage = React.lazy(() => import('./JoinPage').then(m => ({ default: m.JoinPage })));

window.addEventListener('error', (e) => {
  logger.error('Global', 'Unhandled error', { message: e.message, filename: e.filename, lineno: e.lineno });
  void logger.sendToServer();
});
window.addEventListener('unhandledrejection', (e) => {
  logger.error('Global', 'Unhandled rejection', { reason: String(e.reason) });
  void logger.sendToServer();
});

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <Suspense fallback={null}>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/host" element={<CaptainPage />} />
          <Route path="/join/:sessionId" element={<JoinPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  </React.StrictMode>
);
