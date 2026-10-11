import { beforeEach } from 'vitest';

// Wipe storage between tests so state never leaks across cases. jsdom exposes
// these as Storage instances; guard each call so a missing API is surfaced
// (rather than silently passing) but doesn't block the suite from running.
beforeEach(() => {
  if (typeof sessionStorage !== 'undefined' && typeof sessionStorage.clear === 'function') {
    sessionStorage.clear();
  }
  if (typeof localStorage !== 'undefined' && typeof localStorage.clear === 'function') {
    localStorage.clear();
  }
});
