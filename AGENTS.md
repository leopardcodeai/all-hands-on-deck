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

---
## Agents-Konfiguration (Dual-Model)

Dieses Projekt verwendet einen **Advisor-Strategy-Ansatz** mit zwei Modellen:

| Agent | Modell | Zweck |
|-------|--------|-------|
| **Flash** | deepseek-v4-flash | Schnelle, kleine Aufgaben, Analyse, Planung |
| **Pro** | deepseek-v4-pro | Komplexe Code-Änderungen, Refactoring, kritische Tools |

### Wechsel-Trigger (Flash → Pro)

| Trigger | Beschreibung |
|---------|-------------|
| Code-Änderungen >100 Zeilen oder mehrere Dateien | → Pro |
| Refactoring mit Abhängigkeitsanalyse | → Pro |
| Produktions-Tools (Git-Push, Firebase-Deploy, PR-Merge) | → Pro |
| Fehlerbehebung >3 Iterationen | → Pro |
| Flash erkennt selbst: mehr logische Tiefe nötig | → Pro |

Flash bleibt für: Fragen beantworten, Status abfragen, Pläne erstellen, einfache Edits.

---
## Vorne — Versionsänderungen & Redesigns

*Hier werden grundlegende Änderungen, Redesigns und Versionssprünge dokumentiert.*

| Datum | Version | Grund | Agent |
|-------|---------|-------|-------|
| 2026-05-03 | 2.3.4 → 2.3.9 | DesignLabels-Zentralisierung, Viewer-Crew-Popup, Retake-Fix, Countdown-Sync, QR-Piratenflagge, Adaptive Grid | Pro |

---
## Mittig — Große Jobs & Komplexität (Pro)

*Hier werden komplexe Aufgaben, Tool-Nutzungen und Pro-Einsätze dokumentiert.*

| Datum | Issue | Beschreibung | Status |
|-------|-------|-------------|--------|
| 2026-05-03 | APP-69 | Host View: crew icon round + popup above QR | ✅ Gemerged PR #31 |
| 2026-05-03 | APP-70 | Popup restructure: crew top, QR bottom, liquid glass, landscape+portrait | PR #33 In Review |
| 2026-05-03 | APP-46–56 | 11 Issues: DesignLabels, Viewer/Host Crew Popups, QR, Countdown, Webapp | ✅ Gemerged PR #18 |
| 2026-05-03 | — | Linear + GitHub Workflow-Initialisierung (23 Issues) | ✅ Done |

---
## Hinten — Kleine Aufgaben & Änderungen (Flash)

*Hier werden schnelle, unkomplizierte Aufgaben und Flash-Einsätze dokumentiert.*

| Datum | Aufgabe | Agent |
|-------|---------|-------|
| 2026-05-03 | AGENTS.md Dual-Modell-Konfiguration + Restrukturierung | Flash |
| 2026-05-03 | Cleanup .DS_Store + .gitignore | Flash |
| 2026-05-03 | PR #18 mergen (11 Issues finalisiert) | Pro |
| 2026-05-03 | 23 Linear-Issues → Done gesetzt | Pro |
