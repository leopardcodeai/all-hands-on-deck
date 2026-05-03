# All Hands On Deck — Development Workflow

## Projektstruktur

| System | Zweck |
|--------|-------|
| **Linear** (captain-leopard-ai-engineering) | Projektmanagement: Planung, Status, Fortschritt |
| **GitHub** (alexanderbrunker-star/AllHandsOnDeck) | Code: Issues, Branches, PRs, Reviews, Tests |

## Workflow-Stati

```
Backlog → Todo → In Progress → In Review → Testing / QA → Done
```

## Regeln

### 1. Linear als führendes System

- Jede Aufgabe hat ein Linear-Issue im Projekt **"All Hands On Deck"**
- Klarer Titel, Beschreibung, Akzeptanzkriterien
- Status spiegelt tatsächlichen Arbeitsstand

### 2. GitHub Issues parallel

- Jedes technische Linear-Issue bekommt ein GitHub Issue
- Gegenseitige Verlinkung (Linear ↔ GitHub)
- GitHub Issue enthält Linear-Link im Body

### 3. Branch-Konvention

```
feature/AHOD-{id}-kurzbeschreibung
fix/AHOD-{id}-kurzbeschreibung
```

### 4. PR-Konvention

- PR-Titel: `[APP-XX] Beschreibung`
- PR-Body: Linear-Link, GitHub-Issue-Link, Summary, Testplan, Checkliste
- PR erst nach grünen Tests und Review mergen
- Nach Merge: Linear auf **Done**, GitHub Issue schließen

### 5. Test-Driven

- Vor Implementierung: erwartete Tests beschreiben
- Tests müssen grün sein vor Review
- Ticket erst Done wenn: Tests grün + Review bestanden + PR gemerged

### 6. Versionierung

- Bei jedem User-facing Change Version bumpen (alle surfaces)
- Version in: `DebugOverlayView.swift`, `webapp/src/HomePage.tsx`, `webapp/src/JoinPage.tsx`

### 7. DesignLabels

- Alle User-facing Strings über `DesignLabels.swift` (iOS) / `DesignLabels.ts` (webapp)
- Keine Hardcoded Strings in UI-Komponenten
- Englisch ist Source-of-Truth

## Commands

```bash
# iOS
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test

# Webapp
cd webapp && npm run build && npm test

# Deploy webapp
cd webapp && npx firebase deploy --only hosting
```
