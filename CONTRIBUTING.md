# AI Coding Rules — All Hands on Deck

## Architecture

- Views render state and send user intents. No business logic.
- ViewModels coordinate logic. No networking.
- Services speak to external systems (Supabase, Camera, Multipeer).
- Dependency Injection over protocols.
- Use `@Observable` for modern state management where possible.

## SwiftUI Conventions

- Keep SwiftUI Views under 200 lines.
- Extract reusable subviews into computed properties or separate files.
- Use `DesignLabels` for all user-facing strings.
- Use `Theme` for colors, fonts, spacing.
- Every view needs loading ✅, empty ✅, error ✅ states with `#Preview`.

## Testing

- Always add or update tests for behavior changes.
- XCUITest: add `.accessibilityIdentifier` to tappable elements.
- Unit tests: pure logic, no networking.
- E2E: screen_mapper + navigator for simulator automation.

## Code Style

- No force-unwraps (except in tests where explicit).
- No hardcoded strings in views — use DesignLabels.
- No unused imports.
- No print() — use Logger.
- Networking through Core/Networking.
- Persistence through Core/Persistence.
- No secrets in source code.

## PR Rules

- Small PRs preferred (under 200 lines where possible).
- Every PR needs a test plan.
- Tests must be green before merge.
- Linear issue must be linked.
- UI changes need screenshot evidence.

## Project Structure

- Feature-first: `App/Features/Onboarding/`, `App/Features/Settings/`
- Core: `App/Core/Networking/`, `App/Core/Persistence/`, `App/Core/DesignSystem/`
- Shared: `App/Shared/Components/`, `App/Shared/Extensions/`, `App/Shared/Utilities/`
