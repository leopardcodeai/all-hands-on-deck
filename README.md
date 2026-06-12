# All Hands on Deck

[![iOS CI](https://github.com/leopardcodeai/all-hands-on-deck/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/leopardcodeai/all-hands-on-deck/actions/workflows/ios-ci.yml)
[![Webapp CI](https://github.com/leopardcodeai/all-hands-on-deck/actions/workflows/webapp-ci.yml/badge.svg)](https://github.com/leopardcodeai/all-hands-on-deck/actions/workflows/webapp-ci.yml)
[![Server CI](https://github.com/leopardcodeai/all-hands-on-deck/actions/workflows/server-ci.yml/badge.svg)](https://github.com/leopardcodeai/all-hands-on-deck/actions/workflows/server-ci.yml)

**Everyone sees the group photo before it's taken.**

All Hands on Deck is an iOS-first group photo app with a live shared viewfinder. One person sets up their iPhone as the camera; everyone else sees the frame in real time on their own devices — natively on iOS/watchOS or in any browser, with no installation required.

Built and maintained by [LeopardCode.AI](https://leopardcode.ai).

---

## The Experiment

This app was built end-to-end through **agentic coding with Claude Code** — describing intent, reviewing AI-generated implementations, and steering iteration by iteration. No Swift, TypeScript, or SQL was written by hand.

The hypothesis: can a solo developer with an idea, a capable AI coding agent, and zero infrastructure budget ship a real, multi-platform product — iOS, watchOS, and web — without a team?

**Stack — 100% free and open source:**

| Layer | Technology | Cost |
|-------|------------|------|
| iOS + Watch App | SwiftUI, Multipeer Connectivity, Vision | $0 |
| Web Viewer | Vite, React, TypeScript | $0 |
| Project Config | XcodeGen | $0 |
| Realtime Backend | Supabase (free tier) | $0 |
| Web Hosting | Vercel (free tier) | $0 |
| CI/CD | GitHub Actions | $0 |
| AI Coding Agent | Claude Code | — |

The result: a fully functional group-photo app with live viewfinder streaming, AI-powered best-shot burst capture, face-in-frame detection, Apple Watch remote control, universal links, reactions, install-free web viewers, and a complete test suite — without a backend bill.

---

## Screenshots

| iOS — Home | iOS — Viewer (live frame) | Web — Captain | Web — Viewer (live frame) |
|---|---|---|---|
| ![iOS Home](docs/screenshots/ios_01_home_join_crew.jpg) | ![iOS Viewer](docs/screenshots/ios_08_viewer_session_live.jpg) | ![Web Captain](docs/screenshots/web_host_captain.jpg) | ![Web Viewer](docs/screenshots/web_join_live_frame.jpg) |

## Key Features

- **Live shared viewfinder** — every participant sees the camera frame in real time
- **AI best-shot capture** — burst capture with Vision-based selection of the best frame
- **Face-in-frame detection** — confirms everyone is visible before the shot
- **Apple Watch remote** — trigger and monitor the session from the wrist
- **Install-free web viewers** — join via universal link in any browser
- **Reactions** — real-time feedback from viewers to the photographer

## Quick Start

```bash
# iOS
xcodegen generate
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build

# Webapp
cd webapp && npm ci && npm run dev

# Server (optional)
cd server && npm ci && npm run dev
```

## Repository Layout

| Directory | Purpose |
|-----------|---------|
| `AllHandsOnDeck/` | iOS app (SwiftUI) |
| `AllHandsOnDeckTests/` | XCTest unit tests |
| `AllHandsOnDeckUITests/` | XCUITest UI tests |
| `AllHandsOnDeckWatch/` | Apple Watch companion app |
| `webapp/` | Vite + React web viewer |
| `server/` | Node/TypeScript signaling & token server |
| `supabase/` | Database migrations & configuration |
| `scripts/` | E2E test & utility scripts |
| `docs/` | Full documentation |

## Architecture

**Tech stack:** SwiftUI, Multipeer Connectivity, Vision, Supabase (Postgres + Realtime Broadcast), Vite/React, WebSocket relay.

**Streaming (since 2026-06):** Live preview frames travel over **Supabase Realtime Broadcast** (ephemeral pub/sub, no database writes). The events table carries only low-volume control messages, kept clean by a pg_cron job. The webapp is code-split — the landing page loads ~78 kB gzipped instead of 148 kB.

## Documentation

- [Project Details](docs/README.md) — architecture, features, pipelines
- [Setup Guide](docs/SETUP.md) — Supabase, environment, deployment
- [Contributing](docs/contributing/CONTRIBUTING.md) — coding rules & conventions
- [Checklist](docs/contributing/CHECKLIST.md) — definition of done
- [Changelog](docs/CHANGELOG.md)
- [App Store Listing](docs/STORE.md) — draft for App Store Connect

## Status

Feature-complete and App Store ready. Web viewers are currently a beta feature.

---

<p align="center">
  <sub>Built with agentic coding by <a href="https://leopardcode.ai">LeopardCode.AI</a> — free & open source</sub>
</p>
