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

<!-- Tick what was actually run -->

- [ ] `xcodebuild test` — iOS unit tests pass (62/62)
- [ ] `cd webapp && npm test && npm run build` — webapp green (18/18)
- [ ] `cd server && npm test && npm run build` — server green
- [ ] Manual smoke (host iPhone + viewer iPhone, host iPhone + web viewer)

## Review checklist

- [ ] Acceptance criteria met (see Linear issue)
- [ ] All tests green
- [ ] No lint warnings
- [ ] DesignLabels used for all user-facing strings
- [ ] Version bumped if user-visible change

## Risk / rollback

<!-- What could break, how to revert -->

## Post-merge

- [ ] Set Linear issue to **Done**
- [ ] Close GitHub Issue
