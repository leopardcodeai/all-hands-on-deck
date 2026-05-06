# Definition of Done — All Hands on Deck

Every issue must meet these criteria before the PR is merged and the issue is closed.

## Implementation
- [ ] Code compiles without warnings
- [ ] All tests pass
- [ ] No SwiftLint warnings
- [ ] DesignLabels used for user-facing strings
- [ ] Accessibility identifiers added for interactive elements
- [ ] Preview states added (loading, empty, error)

## Testing
- [ ] Unit tests added or updated for behavior changes
- [ ] XCUITest updated for UI changes (if applicable)
- [ ] Works in iOS Simulator (tested with mock mode)
- [ ] Edge cases considered (offline, empty, error states)

## Design
- [ ] UI matches design tokens (Theme.swift + DesignLabels)
- [ ] Dark mode tested (if applicable)
- [ ] Dynamic Type tested (if applicable)
- [ ] iPhone SE + Pro Max layout checked

## Documentation
- [ ] CHANGELOG.md updated if user-facing change
- [ ] PR linked to Linear issue
- [ ] Screenshots attached if UI changed

## Release
- [ ] Version bumped (all surfaces) if user-facing change
- [ ] Linear issue set to **Done**
- [ ] GitHub issue closed
