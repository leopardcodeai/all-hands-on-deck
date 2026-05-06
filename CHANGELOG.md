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
- PR template: erweitert mit Screenshots + Preview-States
- CI workflows: iOS (inkl. UITests), Webapp (inkl. Playwright)
- project.yml: XCUITest target, Duplikat-Exclusions
- .gitignore: Secrets.xcconfig added

### Fixed
- HostView: Button-Abstand für Notch/Dynamic Island (top: 50)
- HostView: Bottom-Buttons kompakter, Viewer-Style (HStack spacing: 10)
- Hardcoded "Abbrechen"/"Jetzt" → DesignLabels.cancel/now
- Duplikate: CameraPreviewView, QRScannerView, StatusPillView ausgeschlossen
