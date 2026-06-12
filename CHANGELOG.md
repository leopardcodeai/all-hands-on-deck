# Changelog — All Hands on Deck

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed — 2026-06-12 Streaming & Performance
- **Preview frames now travel over Supabase Realtime Broadcast** (topic `session-frames:{sessions.id}`, event `preview_frame`) instead of `session_events` INSERTs — no more database churn from ~3 fps frame traffic (was 42 MB / 95% of all rows after ~100 test sessions)
- iOS host sends frames via REST `POST /realtime/v1/api/broadcast` (fire-and-forget); iOS viewers receive through a new minimal Phoenix-websocket client (`SupabaseRealtimeFrameChannel.swift`) with heartbeat + reconnect
- Webapp captain broadcasts via REST; webapp viewers subscribe via supabase-js broadcast channel (legacy table path kept as fallback for old iOS builds)
- iOS event polling tightened: excludes `previewFrame` rows, caps at 200 rows, filters own events server-side
- Webapp code-split with `React.lazy` + dynamic supabase-js import in the logger — landing page payload 148 → 78 kB gzip, Vite chunk-size warning gone
- Fixed dev-only "Connect failed" on React StrictMode remounts (supabase-js reuses channel instances per topic; postgres_changes channels now use unique topic suffixes)

### Added — 2026-06-12 Database hygiene
- Migration `20260611221500_db_hygiene_and_cleanup.sql`: drops duplicate indexes, adds FK indexes, fixes RLS initplan re-evaluation, pins `search_path` on helper functions, revokes `rls_auto_enable()` from anon/authenticated, caps `logs` payload size
- pg_cron job `cleanup-session-events` (every 30 min): purges `previewFrame` events after 1 h and all session events after 24 h, logs after 7 days
- `CLAUDE.md` with build commands, streaming-architecture contract, and Xcode-27-beta caveats; README screenshots

### Added
- Project-wide AI Coding Rules (CONTRIBUTING.md)
- GitHub Actions CI: iOS UITests + Webapp Playwright E2E
- SwiftLint rules (.swiftlint.yml)
- Definition of Done checklist (CHECKLIST.md)
- Design System Spacing tokens (Theme.swift)
- Secrets via .xcconfig template
- Accessibility identifiers for key UI elements
- PR template with Test Plan + Screenshot Evidence
- SwiftUI Preview states for HomeView

### Changed
- AGENTS.md: AI Coding Rules section, new test commands
- PR template: expanded with screenshots + preview states
- CI workflows: iOS (incl. UITests), Webapp (incl. Playwright)
- project.yml: XCUITest target, duplicate exclusions
- .gitignore: Secrets.xcconfig added

### Fixed
- HostView: button spacing for notch/Dynamic Island (top: 50)
- HostView: bottom buttons more compact, viewer-style (HStack spacing: 10)
- Hardcoded "Cancel"/"Now" → DesignLabels.cancel/now
- Duplicates: CameraPreviewView, QRScannerView, StatusPillView excluded
