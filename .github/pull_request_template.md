## Summary

<!-- 1–3 bullet points: what changed and why -->

### 🔗 Linear

<!-- Link to Linear issue(s): e.g. APP-46 -->
- Linear issue: 

### 🔗 GitHub Issue

<!-- Link to matching GitHub Issue -->
- GitHub Issue: #

## Affected components

- [ ] iOS app (`AllHandsOnDeck/`)
- [ ] Apple Watch (`AllHandsOnDeckWatch/`)
- [ ] Webapp (`webapp/`)
- [ ] Relay server (`server/`)
- [ ] Build / CI / infra
- [ ] Docs only

## Test plan

- [ ] `xcodebuild test` — iOS unit + UI tests pass
- [ ] `cd webapp && npm test && npx playwright test` — webapp green
- [ ] `cd server && npm test && npm run build` — server green
- [ ] Simulator QA: fresh install, first launch, offline, dark mode
- [ ] Manual smoke (host iPhone + viewer iPhone, host iPhone + web viewer)

## Screenshots / Simulator Evidence

<!-- Add screenshots if UI changed -->

## Review checklist

- [ ] Acceptance criteria met (see Linear issue)
- [ ] All tests green
- [ ] No SwiftLint warnings
- [ ] DesignLabels used for all user-facing strings
- [ ] Preview states: loading, empty, error present (if applicable)
- [ ] Accessibility identifiers added for new UI elements
- [ ] Version bumped if user-visible change

## Risk / rollback

<!-- Low / Medium / High — what could break, how to revert -->

## Post-merge

- [ ] Set Linear issue to **Done**
- [ ] Close GitHub Issue
