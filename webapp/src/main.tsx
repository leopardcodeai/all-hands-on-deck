import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { JoinPage } from './JoinPage';
import { HomePage } from './HomePage';
import { CaptainPage } from './HostPage';
import { logger } from './lib/logger';
import './styles.css';

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
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/host" element={<CaptainPage />} />
        <Route path="/join/:sessionId" element={<JoinPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>
);
