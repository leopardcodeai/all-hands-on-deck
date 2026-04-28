## Summary

<!-- 1–3 bullet points: what changed and why -->

## Affected components

- [ ] iOS app (`AllHandsOnDeck/`)
- [ ] Apple Watch (`AllHandsOnDeckWatch/`)
- [ ] Webapp (`webapp/`)
- [ ] Relay server (`server/`)
- [ ] Build / CI / infra
- [ ] Docs only

## Test plan

<!-- Tick what was actually run; CI will rerun on push -->

- [ ] `xcodebuild test` — iOS unit tests pass
- [ ] `cd webapp && npm test && npm run build` — webapp green
- [ ] `cd server && npm test && npm run build` — server green
- [ ] Manual smoke (host iPhone + viewer iPhone, host iPhone + web viewer, …)

## Risk / rollback

<!-- What could break in prod, how to revert (revert PR / re-deploy previous Cloud Run revision / etc.) -->
