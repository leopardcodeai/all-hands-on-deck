# All Hands On Deck — Development Workflow

## Project Structure

| System | Purpose |
|--------|-------|
| **Linear** (leopardcode-ai) | Project management: planning, status, progress |
| **GitHub** (leopardcodeai/all-hands-on-deck) | Code: Issues, Branches, PRs, Reviews, Tests |

## Workflow States

```
Backlog → Todo → In Progress → In Review → Testing / QA → Done
```

## AI Coding Rules (see CONTRIBUTING.md)

- Views only state + user intents. No business logic.
- ViewModels coordinate. Services talk to external systems.
- Dependency Injection via Protocols.
- DesignLabels for all user-facing strings.
- No hardcoded strings, no magic numbers (use spacing tokens).
- Accessibility identifiers for UI test elements.
- Preview states (loading, empty, error) for all views.
- PR template with test plan + screenshot evidence.
- Definition of Done in CHECKLIST.md.

## Rules

### 1. Linear as leading system

- Every task has a Linear issue in the **"All Hands On Deck"** project
- Clear title, description, acceptance criteria
- Status reflects actual work progress

### 2. GitHub Issues in parallel

- Every technical Linear issue gets a GitHub issue
- Cross-linking (Linear ↔ GitHub)
- GitHub issue contains Linear link in body

### 3. Branch Convention

```
feature/AHOD-{id}-short-description
fix/AHOD-{id}-short-description
```

### 4. PR Convention

- PR title: `[APP-XX] Description`
- PR body: Linear link, GitHub issue link, summary, test plan, checklist
- Merge PR only after green tests and review
- After merge: set Linear to **Done**, close GitHub issue

### 5. Test-Driven

- Before implementation: describe expected tests
- Tests must be green before review
- Ticket Done only when: tests green + review passed + PR merged

### 6. Versioning

- Bump version on every user-facing change (all surfaces)
- Version in: `DebugOverlayView.swift`, `webapp/src/HomePage.tsx`, `webapp/src/JoinPage.tsx`

### 7. DesignLabels

- All user-facing strings via `DesignLabels.swift` (iOS) / `DesignLabels.ts` (webapp)
- No hardcoded strings in UI components
- English is source of truth

## Commands

```bash
# iOS
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test

# iOS Unit only
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:AllHandsOnDeckTests test

# iOS UI only
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:AllHandsOnDeckUITests test

# Webapp
cd webapp && npm run build && npm test

# Webapp E2E
cd webapp && npx playwright test

# Webapp all
cd webapp && npm run build && npm test && npx playwright test

# Multi-Device E2E (requires idb + 3 booted simulators)
python3 scripts/happy_path_e2e.py

# Deploy webapp
cd webapp && npm run build
```

---
## Agent Configuration (Dual-Model)

This project uses an **Advisor-Strategy** approach with two models:

| Agent | Model | Purpose |
|-------|--------|-------|
| **Flash** | deepseek-v4-flash | Fast, small tasks, analysis, planning |
| **Pro** | deepseek-v4-pro | Complex code changes, refactoring, critical tools |

### Switch Triggers (Flash → Pro)

| Trigger | Description |
|---------|-------------|
| Code changes >100 lines or multiple files | → Pro |
| Refactoring with dependency analysis | → Pro |
| Production tools (git push, hosting deploy, PR merge) | → Pro |
| Troubleshooting >3 iterations | → Pro |
| Flash recognizes: more logical depth needed | → Pro |

Flash stays for: answering questions, checking status, creating plans, simple edits.

---
## Front — Version Changes & Redesigns

*Fundamental changes, redesigns, and version jumps are documented here.*

| Date | Version | Reason | Agent |
|-------|---------|-------|-------|
| 2026-05-03 | 2.3.4 → 2.3.9 | DesignLabels centralization, viewer crew popup, retake fix, countdown sync, QR pirate flag, adaptive grid | Pro |

---
## Middle — Large Jobs & Complexity (Pro)

*Complex tasks, tool usage, and Pro assignments are documented here.*

| Date | Issue | Description | Status |
|-------|-------|-------------|--------|
| 2026-05-04 | APP-78 | Happy Path E2E Test: 3-device (iOS Host + iOS Viewer + Safari Webapp) | ✅ Merged |
| 2026-05-04 | APP-79 | Better Software Developer — project structure, CI, coding rules | ✅ Done |
| 2026-05-04 | APP-80 | Host View UI Fix: notch spacing + bottom buttons more compact + DesignLabels | ✅ Done |
| 2026-05-03 | APP-69 | Host View: crew icon round + popup above QR | ✅ Merged PR #31 |
| 2026-05-03 | APP-70 | Popup restructure: crew top, QR bottom, liquid glass, landscape+portrait | PR #33 In Review |
| 2026-05-03 | APP-46–56 | 11 Issues: DesignLabels, Viewer/Host Crew Popups, QR, Countdown, Webapp | ✅ Merged PR #18 |
| 2026-05-03 | — | Linear + GitHub workflow initialization (23 Issues) | ✅ Done |

---
## Back — Small Tasks & Changes (Flash)

*Quick, straightforward tasks and Flash assignments are documented here.*

| Date | Task | Agent |
|-------|---------|-------|
| 2026-05-03 | AGENTS.md dual-model configuration + restructuring | Flash |
| 2026-05-03 | Cleanup .DS_Store + .gitignore | Flash |
| 2026-05-03 | Merge PR #18 (11 issues finalized) | Pro |
| 2026-05-03 | 23 Linear issues → set to Done | Pro |
