# Changelog — All Hands on Deck

All notable changes to this project will be documented in this file.

## [Unreleased]

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
