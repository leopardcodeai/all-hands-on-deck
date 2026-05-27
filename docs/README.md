# All Hands on Deck

[![iOS CI](https://github.com/alexanderbrunker-star/all-hands-on-deck/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/alexanderbrunker-star/all-hands-on-deck/actions/workflows/ios-ci.yml)
[![Webapp CI](https://github.com/alexanderbrunker-star/all-hands-on-deck/actions/workflows/webapp-ci.yml/badge.svg)](https://github.com/alexanderbrunker-star/all-hands-on-deck/actions/workflows/webapp-ci.yml)
[![Server CI](https://github.com/alexanderbrunker-star/all-hands-on-deck/actions/workflows/server-ci.yml/badge.svg)](https://github.com/alexanderbrunker-star/all-hands-on-deck/actions/workflows/server-ci.yml)
[![CodeQL](https://github.com/alexanderbrunker-star/all-hands-on-deck/actions/workflows/codeql.yml/badge.svg)](https://github.com/alexanderbrunker-star/all-hands-on-deck/actions/workflows/codeql.yml)

> by Captain Leopard 🏴‍☠️🐆
> *"Alle sehen das Gruppenfoto, bevor es aufgenommen wird."*

iOS-first MVP für ein Live-Viewfinder-Gruppenfoto. Eine Person stellt ihr iPhone als
Kamera auf, alle anderen sehen den Bildausschnitt live auf ihren Geräten — nativ
oder im Browser, ohne Installation.

Runtime backend: Supabase replaces the old relay backend for database,
Storage, and Realtime fallback. Setup details live in [`SETUP.md`](SETUP.md).
Web Viewers are currently marked and treated as a **Beta** feature: Supabase is
the session backend, while live video remains WebRTC/P2P-first and is never
stored in Supabase.

---

## Status

- ✅ **Step 1**: SwiftUI-Skelett, Mock-Transport, Host- und Viewer-Flow.
- ✅ **Step 2**: Multipeer Connectivity, QR-Scanner, echtes Frame-Streaming, Nearby-Discovery.
- ✅ **Step 3**: Node/TS Signaling-Server, Vite-Web-App-Viewer, iOS WebSocket-Transport, Composite-Transport (Multipeer + Web parallel).
- ✅ **Step 4**: Vision-basierte "Bin ich im Bild?" Hinweise (Face-Detection, Schief-/Abgeschnitten-Erkennung).
- ✅ **Step 5**: Best-Shot Burst-Capture mit KI-Ranking (Gesichter, offene Augen, Schärfe).
- ✅ **Step 6**: Apple Watch Companion (WCSession-Bridge, Live-Countdown auf der Wrist, Trigger/Cancel/Now).
- ✅ **Step 7**: Universal Links + Custom-URL-Scheme (`allhands://`), Server liefert AASA.
- ✅ **Step 8**: Reactions ("Bereit", "Kamera höher", "Weiter links" etc.) — auf iOS-Viewer und Web-Viewer, Host bekommt Toast + Watch-Snapshot.
- ✅ **Step 9**: XCTest-Suite für die deterministischen Bausteine (CountdownCoordinator, URL-Parser, Wire-Format, ID-Generator, Mock-Broker, Image-Compression).
- ✅ **Step 10**: PrivacyInfo.xcprivacy Manifest, Session-TTL-Expiry-Enforcement (host-side timer triggert `.sessionEnded` automatisch).
- ✅ **Step 11**: XcodeGen `project.yml` → `AllHandsOnDeck.xcodeproj` (iOS + Watch + Tests), Entitlements, AppIcon-Scaffold.
- ✅ **Step 12**: Lokalisierung (de + en) — `Localizable.strings` für iOS und Watch; alle UI-Strings und Modell-Properties lokalisiert.
- ✅ **Step 13**: Fly.io Deployment — `Dockerfile` (multi-stage) + `fly.toml`; Webapp-Build-Bug (`vite/client` types) gefixt.
- ✅ **Step 14**: App Store Draft (`STORE.md`) — Beschreibung, Keywords, Privacy Nutrition Label.
- ✅ **Step 15**: Automatisierte Happy-Path-Tests (121 Tests: XCTest 76 + XCUITest 15 + Webapp 18 + Playwright 11 + Python E2E)
- ✅ **Step 16**: UI Fixes — Notch-Abstand Host View, Bottom-Buttons kompakter (Viewer-Style), DesignLabels-Zentralisierung
- ✅ **Step 17**: Supabase session backend + Web Viewers **Beta** policy controls (10 min sessions, 3 P2P viewers, short-lived QR token, TURN hard limit, no Supabase video storage).
- ⏭ **Deferred (post-MVP)**: persistente Galerie / Event-Modus, Smile-Detection, SFU for larger viewer groups.

**Alles fertig — App-Store-ready.**

### Noch offen (braucht deine Daten)

| Was | Wo ersetzen |
|---|---|
| Apple Team ID | `project.yml` → `TEAMID`, `server/public/.well-known/apple-app-site-association` |
| Vercel Webapp URL | `WEB_JOIN_BASE_URL` / iOS `joinBaseURL` |
| Echte Domain | `project.yml` Entitlements, AASA, Vercel Domain |
| App-Icon (1024×1024 PNG) | `AllHandsOnDeck/Resources/Assets.xcassets/AppIcon.appiconset/` |

```bash
# Projekt bauen
xcodegen generate   # nach jeder Änderung an project.yml

# Webapp deployen
# GitHub -> Vercel baut webapp/ per vercel.json.
# Manuell: vercel --prod
```

---

## Repository-Layout

```
AllHandsOnDeck/        iOS App (SwiftUI)
AllHandsOnDeckWatch/   Apple Watch Companion App (Step 6)
AllHandsOnDeckTests/   XCTest unit tests (Step 9)
server/                Optionaler Node/TS WebSocket-Signaling/Relay + AASA
webapp/                Vite + React Web-Viewer (PWA-fähig)
```

---

## Lokal alles zusammen starten

Du brauchst dafür:
- Node 20+
- Xcode 16+
- 2 echte iPhones (für Multipeer-Test) **oder** 1 iPhone + Browser (für Web-Viewer-Test)
- Alle Geräte im selben WLAN

### 1. Backend starten

```bash
cd server
npm install
npm run dev
```

→ läuft auf `:8787`. Health-Check: `curl http://localhost:8787/health`.

### 2. Web-App starten

```bash
cd webapp
npm install
npm run dev
```

→ läuft auf `http://localhost:5173`. Vite ist auf `0.0.0.0` gebunden, du
erreichst sie also vom iPhone aus auch über `http://<dein-mac-im-LAN>:5173`.

Server-URL überschreiben: `VITE_SERVER_URL=ws://192.168.1.10:8787 npm run dev`.

### 3. iOS App-Konfiguration (UserDefaults)

Über das Xcode-Scheme oder eine `Settings.bundle` setzen:

| Key | Wert | Wofür |
| --- | --- | --- |
| `webSocketServerURL` | `ws://192.168.1.10:8787` | Wo der iOS-Host hin verbindet wenn "Web-Viewer erlauben" an ist |
| `joinBaseURL` | `http://192.168.1.10:5173` | Was der QR-Code im Host-Panel verlinkt |

Schnellster Weg: In Xcode → Edit Scheme → Run → Arguments → Environment
Variables ist nicht kompatibel mit `UserDefaults`. Einfacher:
**Launch Arguments**:

```
-webSocketServerURL ws://192.168.1.10:8787
-joinBaseURL http://192.168.1.10:5173
```

(Xcode mappt diese als `UserDefaults` Standard-Werte für die Session.)

### 4. Host-Session mit Web-Viewer (Beta)

Web Viewers are a **Beta** feature in the app UI and policy. Use them for MVP
testing; native nearby viewers remain the default path.

1. iPhone A → "Web-Viewer erlauben" mit **BETA** Badge einschalten → "Gruppenfoto starten".
2. QR-Panel zeigt einen Code, der auf `http://<mac>:5173/join/<sessionId>` zeigt.
3. iPhone B Safari oder Mac-Browser → QR scannen / URL öffnen.
4. Web-App verbindet sich zur Backend-WebSocket → bekommt `sessionMetadata`,
   anschließend Live-Frames.
5. Host startet 10s-Timer → beide Clients (Multipeer-Native + Web) sehen
   synchronen Countdown.
6. Foto-Aufnahme → Web-Viewer zeigt finales Foto + "Speichern"-Button.

### Happy Path Flow

```mermaid
flowchart TD
    HostUser["User: Host"] --> HostApp["iOS App: Host mode"]
    JoinUser["User: iOS join"] --> JoinApp["iOS App: Viewer mode"]
    WebUser["User: Web join"] --> WebApp["Vercel Webapp: /join/:session_id"]

    HostApp --> CreateSession["Create session"]
    CreateSession --> SupabaseSessions["Supabase: sessions + session_participants"]
    CreateSession --> SessionID["Session ID + short-lived token"]
    SessionID --> QRCode["QR code / join link"]

    QRCode --> JoinApp
    QRCode --> WebApp
    JoinApp --> JoinSession["Join by session_id + token"]
    WebApp --> JoinSession
    JoinSession --> SupabaseSessions

    HostApp --> Camera["CameraService: preview frames"]
    Camera --> P2PVideo["WebRTC P2P video stream"]
    P2PVideo --> JoinApp
    P2PVideo --> WebApp

    HostApp --> Realtime["Supabase Realtime fallback"]
    JoinApp --> Realtime
    WebApp --> Realtime
    Realtime --> SessionEvents["session_events: sync, fallback, signaling"]

    HostUser --> Capture["Start timer / capture now"]
    Capture --> HostApp
    HostApp --> Photo["Photo capture"]
    Photo --> PhotoBroadcast["finalPhotoAvailable event"]
    PhotoBroadcast --> JoinApp
    PhotoBroadcast --> WebApp

    WebApp -. optional beta .-> LiveKit["LiveKit Beta token endpoint"]
    LiveKit --> LiveRoom["LiveKit room by session_id"]
    HostApp -. beta publish .-> LiveRoom
    LiveRoom -. beta subscribe .-> WebApp
```

---

## Step 4 — "Bin ich im Bild?" Vision-Hints

- Läuft auf der gleichen 3 fps Preview-Pipeline, kein Extra-Tap auf
  AVCaptureSession.
- `VNDetectFaceRectanglesRequest` → Bounding Boxes → Verdict:
  - `noFaces` / `allInside` / `someClipped`
  - Schwerpunkt-Skew: `skewedLeft`, `skewedRight`, `tooHigh`, `tooLow`
- Zeigt sich als Chip oberhalb des Capture-Buttons. Bei "Alle drin" wird er
  grün (Theme.signal), sonst gold.
- Throttle 0.5s, läuft auf eigener `DispatchQueue` damit Main bei 60 fps bleibt.

Architektur-Slot für später: `InFrameDetector` ist als `ObservableObject`
designed, du kannst Verdicts auch über das Transport-Protokoll an Viewer
broadcasten ("Du bist links abgeschnitten").

## Step 5 — Best-Shot Burst

- Settings-Sheet → "Best-Shot Burst" Toggle.
- Bei aktiver Burst-Aufnahme nimmt `CameraService.captureBurst` 5 Bilder mit
  ~0.35s Abstand.
- `PhotoQualityScorer` verteilt asynchron Tasks pro Bild:
  - Face Count via `VNDetectFaceLandmarksRequest`
  - Eyes-Open Score via Augenlandmark-Bounding-Box-Aspect-Ratio
  - Sharpness via Variance-of-Laplacian (CIConvolution3x3 + CIAreaAverage)
  - Composite mit gewichtetem Sum
- `BurstPickerView` zeigt alle Kandidaten, das KI-Top-1 mit ⭐-Badge.
- Captain pickt → `acceptBurstPick` rebroadcastet als `finalPhotoAvailable`.

---

## Build- und Fehlerfix-Checkliste (kombiniert)

| Symptom | Ursache → Fix |
| --- | --- |
| App crasht beim "Gruppenfoto starten" | `NSCameraUsageDescription` fehlt → Info.plist |
| Local-Network-Prompt erscheint nicht | `NSLocalNetworkUsageDescription` + `NSBonjourServices` fehlen → Info.plist + **App vom Gerät löschen und neu installieren** |
| Nearby findet nichts | Service-Type-Mismatch zwischen `MultipeerSessionTransport.serviceType` und Bonjour-Eintrag |
| Web-Viewer zeigt "connecting" und passiert nichts | Backend nicht erreichbar / falsche `webSocketServerURL` → `curl http://<mac>:8787/health` aus iOS-Browser checken |
| Web-Viewer connected aber kein Frame | Host hat Web-Join Beta nicht aktiviert → Toggle auf Home → neu in Host-Session gehen |
| QR-Code öffnet `https://allhands.captainleopard.app/...` und 404 | `joinBaseURL` UserDefaults nicht überschrieben |
| Vision-Hints flackern bei dunklen Räumen | Throttle erhöhen in `InFrameDetector.minInterval` (default 0.5s) |
| Burst-Picker leer trotz Auslösung | `captureBurst` schlug ab Photo 1 fehl → AVCapturePhotoOutput erlaubt keine Captures während `isAvailable == false`. Schau in Xcode-Console auf Camera-Errors |
| Multipeer findet Peer langsam | Geräte nicht im selben WLAN (Gast-WLAN, Captive-Portal) |
| Mehr als 3 Web-Viewer wollen beitreten | MVP-Policy limitiert WebRTC/P2P auf 3 Viewer pro Host; größere Gruppen brauchen später SFU |

---

## Architektur — Transport-Layer

```
SessionTransport (protocol)
├── MockSessionTransport            in-process broker
├── MultipeerSessionTransport       MCSession + Bonjour
├── WebSocketSessionTransport       URLSessionWebSocketTask → Node relay
└── CompositeSessionTransport       fan-out across multiple children
                                     (Host benutzt es für Multipeer + Web)
```

`SessionWireMessage` ist das Codable-Envelope und identisch über alle
Transports. Der Web-Client benutzt eine TS-Spiegelung (`webapp/src/wire.ts`).

```
Frame Pipeline:
  AVCaptureVideoDataOutput
    → CameraService.captureOutput (off-main)
      → CIContext (single instance, hoisted)
        → JPEG q=0.5, 640px wide, ~3 fps
          → previewFrameConsumer (@Sendable closure)
            → HostSessionViewModel.broadcastPreviewFrame
              ├── InFrameDetector.ingest (vision)
              └── transport.send(.previewFrame)
                  ├── Multipeer (.unreliable)
                  └── WebSocket (JSON, base64)
```

```
Capture Pipeline:
  CountdownCoordinator (target Date)
    → CameraService.capturePhoto / captureBurst
      ├── single → ImageCompression (1280px, q=0.7) → broadcast
      └── burst (5×, 0.35s gap) → PhotoQualityScorer.rank
                                    → BurstPickerView (UI)
                                      → acceptBurstPick → broadcast
```

---

## Step 6 — Apple Watch Companion

Die Watch-App ist ein separates Xcode-Target — Apple lässt das nicht via
File-Drop allein erledigen. Anleitung siehe
[`AllHandsOnDeckWatch/README.md`](../AllHandsOnDeckWatch/README.md).

Kurzfassung:
1. Xcode → File → New → Target → watchOS → App.
2. Stub-Dateien löschen, alle Files aus `AllHandsOnDeckWatch/` reindragen.
3. **Wichtig**: `AllHandsOnDeck/Services/Watch/WatchProtocol.swift` an
   beide Targets hängen (Target Membership in den File Inspector).
4. Watch-Scheme bauen.

Was sie kann:
- Auto-Connect via WCSession beim App-Start.
- Live-Snapshot vom iPhone: Captain-Name, Crew-Anzahl, Timer-Dauer.
- Trigger-Buttons: "Timer 10s", "Jetzt", "Abbrechen während Countdown".
- Synchroner Countdown-Zähler via `TimelineView` gegen `photoAtEpochMs`.
- Letzte Reaction-Anzeige ("Bereit", "Kamera höher" etc.).

## Step 7 — Universal Links

iOS-Setup:
1. Xcode → Target → Signing & Capabilities → **+ Associated Domains**.
2. Domain hinzufügen: `applinks:allhands.captainleopard.app`
   (deine Domain ersetzen).
3. App-URL-Scheme `allhands://` ist bereits in der Info.plist konfiguriert.

Server-Setup:
1. `server/public/.well-known/apple-app-site-association` anpassen:
   - `TEAMID` durch dein Apple-Team-ID ersetzen
   - Bundle-ID durch deine ersetzen
2. Webapp auf Vercel deployen; optionalen Token-/Relay-Server auf Supabase
   Edge Functions, Cloud Run, Fly.io, Railway oder DigitalOcean betreiben.
3. HTTPS-Pflicht für Apple — meiste Plattformen liefern das automatisch.
4. Validierung: `curl https://your-domain/.well-known/apple-app-site-association`
   muss `application/json` ausliefern.

Code-Pfad:
```
Universal Link → onContinueUserActivity (NSUserActivityTypeBrowsingWeb)
                  → UniversalLinkHandler.handle(url:)
                    → SessionURLParser.sessionID(from:)
                      → HomeView pendingSessionID → ViewerSessionView push
```

Custom-Scheme `allhands://join?session=ABC` greift identisch über
`onOpenURL` und ist Fallback für Geräte ohne installierte App-Umleitung.

## Step 8 — Reactions

- Viewer (iOS und Web): tippt Chip aus 7-Reaktion-Strip.
- Wire: `SessionEvent.reactionSent(by, reaction)` mit `Reaction.rawValue`.
- Host: Toast oben in der Capture-View für 2.5s, Watch-Snapshot updated.
- Framing-Hints (Kamera höher, links, rechts, "sehe mich nicht") triggern
  `Haptics.warning()`, normale Reaktionen nur `Haptics.tick()`.

## Step 9 — Tests

Setup-Anleitung in [`AllHandsOnDeckTests/README.md`](../AllHandsOnDeckTests/README.md).
Quick: Xcode → File → New → Target → Unit Testing Bundle → alle Files
reindragen → ⌘U.

Coverage:
- `CountdownCoordinatorTests` — State-Maschine + Target-Date-Math
- `SessionURLParserTests` — alle drei URL-Formate + Garbage-Input
- `SessionWireMessageTests` — Codable-Round-Trip inkl. großer Frame-Blob
- `PhotoSessionTests` — ID-Alphabet, Uniqueness, JoinURL-Override
- `NearbySessionSummaryTests` — Discovery-Info-Decoding
- `MockSessionTransportTests` — Broker-Isolation, kein Self-Echo
- `ImageCompressionTests` — Downscale + Garbage-Passthrough

Webapp + Server-seitig:
- `webapp/` — Vitest. `applyEvent` Reducer (alle Wire-Events), `pirateRank`
  Persistenz, Wire-Format-Golden-Tests gegen iOS-konforme Envelopes.
- `server/` — `node:test` via `tsx`. `RoomRegistry` Routing-Regeln (host →
  alle Viewer, viewer → host only), Closed-Socket-Skip, GC, Join-Param-Validation.

Was nicht gecovert ist (AVFoundation, Multipeer, WebSocket, Vision) sind
Integration-Pfade die Hardware oder Live-Server brauchen — manuell via die
Test-Pläne oben durchziehen.

### CI / GitHub / Vercel

GitHub-Actions-Workflows in `.github/workflows/`:
- `ios-ci.yml` — `xcodegen generate` + `xcodebuild test` auf macOS-14.
- `webapp-ci.yml` — `npm ci` → `tsc -b` → `vitest run` → `vite build`.
- `server-ci.yml` — `npm ci` → `tsc --noEmit` → `node:test` → `tsc` →
  `docker buildx` Smoke-Build des produktiven Images.
- `vercel-webapp.yml` — Preview-Deploys für Pull Requests und Production-
  Deploys bei Push auf `main`, wenn `ENABLE_VERCEL_DEPLOY=true` gesetzt ist.

Jeder Workflow läuft nur, wenn der dazugehörige Pfad sich geändert hat
(siehe `paths:` Filter), damit ein Web-PR keine 15-Minuten-iOS-Build-Queue
auslöst. CodeQL läuft zusätzlich auf jeden Push und wöchentlich.

Vercel ist der Webapp-Host. Die Root-Konfiguration `vercel.json` baut die
Vite-App aus `webapp/` und liefert `webapp/dist` mit SPA-Rewrites aus.

GitHub-Secrets für Vercel:

```text
VERCEL_TOKEN
VERCEL_ORG_ID
VERCEL_PROJECT_ID
VITE_SUPABASE_ANON_KEY
```

GitHub-Variablen:

```text
ENABLE_VERCEL_DEPLOY=true
VITE_SUPABASE_URL
VITE_ENABLE_LIVEKIT_BETA
VITE_LIVEKIT_TOKEN_ENDPOINT
```

Hinweis: `ENABLE_VERCEL_DEPLOY` bleibt auf `false`, bis in Vercel die GitHub
Login Connection gesetzt und ein `VERCEL_TOKEN` als GitHub Secret hinterlegt
ist. Manuelle CLI-Deploys funktionieren unabhängig davon.

Lokal alles gleichzeitig laufen lassen:

```bash
( cd webapp && npm ci && npm run typecheck && npm test && npm run build )
( cd server && npm ci && npm run typecheck && npm test && npm run build )
xcodegen generate && xcodebuild test \
  -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

## Step 10 — App-Store-Readiness

**Privacy Manifest** (`AllHandsOnDeck/Resources/PrivacyInfo.xcprivacy`):
- `NSPrivacyTracking` = false
- Keine Tracking-Domains
- Kein Daten-Collection
- Deklariert `NSPrivacyAccessedAPICategoryUserDefaults` mit Reason `CA92.1`
- Drag-and-drop ins Xcode-Projekt, Target Membership iOS-App.

**Session-Expiry-Enforcement**:
- HostSessionViewModel startet einen Task gegen `session.expiresAt`.
- Bei Ablauf: `transport.send(.sessionEnded)` an alle Peers, lokaler Alert,
  Pop nach Home.
- Default-TTL ist 10 Minuten (`PhotoSession.init(ttlMinutes:)` Default).
- Privacy-Garantie aus dem Brief: ephemeral, no accounts, no lingering rooms.

**Privacy-Position für Store-Listing** (zur Hand):
- Daten gesammelt: KEINE.
- Daten geteilt: KEINE.
- Tracking: Nein.
- Account-Erstellung: Nein.
- Foto-Speicherung: nur lokal in der Mediathek nach explizitem
  "Speichern"-Tap.
- Session-Daten: ephemeral im Multipeer-Mesh oder im Relay-Server-RAM.
  Nach 10 min idle GC, kein Persistenz-Layer.

## Was bewusst ausgelassen ist

- **WebRTC**: WebSocket-Relay reicht für 3 fps Preview problemlos. WebRTC würde
  sich erst bei 30 fps oder Bidirectional-Audio lohnen.
- **Persistente Foto-Galerie / Event-Modus**: kein Backend-State, keine Accounts.
  Sessions sind ephemeral, TTL 30 Min, dann GC.
- **Smile-Detection**: Vision hat keinen direkten Smile-Score auf iOS (CoreImage
  hat einen schwachen `CIDetectorSmile`, lohnt sich nicht). Erweiterbar via
  CoreML später.

---

## Verzeichnisbaum

```
AllHandsOnDeck/
  App/
  Models/
  Services/
    Camera/
    Countdown/
    Nearby/
    QR/
    Session/
      MockSessionTransport.swift
      MultipeerSessionTransport.swift
      WebSocketSessionTransport.swift
      CompositeSessionTransport.swift
      SessionWireMessage.swift
      SessionManager.swift
      SessionTransport.swift
    Vision/
      InFrameDetector.swift
      PhotoQualityScorer.swift
  ViewModels/
  Views/
    Components/
    Host/
      HostSessionView.swift
      BurstPickerView.swift
      ...
    Nearby/
    Viewer/
  Utilities/
  Resources/

server/
  src/index.ts        WebSocket relay
  package.json

webapp/
  src/
    main.tsx
    HomePage.tsx
    JoinPage.tsx
    SessionClient.ts
    wire.ts
    styles.css
  index.html
```
