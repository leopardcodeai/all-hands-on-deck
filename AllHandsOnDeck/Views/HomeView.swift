import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var linkHandler: UniversalLinkHandler
    @StateObject private var vm = HomeViewModel()
    @ObservedObject private var identity = IdentityService.shared
    @State private var showingHost = false
    @State private var showingJoin = false
    @State private var showingNearby = false
    @State private var showingIdentity = false
    @State private var deepLinkSession: PhotoSession?
    @State private var allowWebJoin: Bool = UserDefaults.standard.bool(forKey: "allowWebJoinDefault")
    #if DEBUG
    @State private var useMock: Bool = SessionManager.isMockPreferred
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.oceanFog.ignoresSafeArea()
                leopardSpots.opacity(0.06)

                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 24)
                    actions
                    Spacer()
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .navigationDestination(isPresented: $showingHost) {
                HostSessionView(hostName: vm.hostName, allowWebJoin: allowWebJoin) { sessionID in
                    vm.remember(sessionID: sessionID)
                }
            }
            .navigationDestination(isPresented: $showingJoin) {
                JoinSessionView(displayName: vm.hostName)
            }
            .navigationDestination(isPresented: $showingNearby) {
                NearbySessionsView(displayName: vm.hostName)
            }
            .sheet(isPresented: $showingIdentity) {
                IdentitySettingsView()
            }
            .navigationDestination(item: $deepLinkSession) { session in
                ViewerSessionView(session: session, displayName: vm.hostName)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                // Cold-launch case: the link may have arrived before this
                // view mounted, in which case `onChange` would never fire.
                if let id = linkHandler.consume() {
                    deepLinkSession = PhotoSession(id: id, hostName: "Host")
                }
            }
            .onChange(of: linkHandler.pendingSessionID) { _, newValue in
                guard let id = newValue else { return }
                // Pop any active host/nearby/join screens so the deep-link
                // routes from a clean root, then push the viewer.
                showingHost = false
                showingJoin = false
                showingNearby = false
                deepLinkSession = PhotoSession(id: id, hostName: "Host")
                _ = linkHandler.consume()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusPill(label: "by Captain Leopard", systemImage: "flag.fill", tint: Theme.gold)
                Spacer()
                #if DEBUG
                mockToggle
                #endif
            }
            Text("All Hands\non Deck")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(Theme.bone)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("The Captain's Live Group Photo Preview")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        VStack(spacing: 14) {
            identityChip

            PrimaryButton(title: "Gruppenfoto starten", systemImage: "camera.fill", style: .primary) {
                showingHost = true
            }
            PrimaryButton(title: "Session beitreten", systemImage: "qrcode.viewfinder", style: .secondary) {
                showingJoin = true
            }
            PrimaryButton(title: "Nearby Sessions", systemImage: "antenna.radiowaves.left.and.right", style: .ghost) {
                showingNearby = true
            }

            // Web-Join toggle. Persisted; off by default — most sessions
            // happen in person and don't need a backend.
            let webAvailable = SessionManager.isWebJoinAvailable
            let effectivelyOn = allowWebJoin && webAvailable
            HStack(spacing: 12) {
                Image(systemName: webAvailable ? "globe" : "globe.badge.chevron.backward")
                    .foregroundStyle(effectivelyOn ? Theme.signal : (allowWebJoin && !webAvailable ? Theme.crimson : Theme.mist))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Web-Viewer erlauben")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.bone)
                    Text(webStatusLine(allowed: allowWebJoin, available: webAvailable))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(allowWebJoin && !webAvailable ? Theme.crimson : Theme.mist)
                }
                Spacer()
                Toggle("", isOn: $allowWebJoin)
                    .labelsHidden()
                    .tint(Theme.gold)
                    .onChange(of: allowWebJoin) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "allowWebJoinDefault")
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(allowWebJoin && !webAvailable ? Theme.crimson.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var identityChip: some View {
        Button { showingIdentity = true } label: {
            HStack(spacing: 12) {
                Text(identity.earnedRank.emoji)
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.hostName)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Text(identity.rankBadge)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Theme.bone)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func webStatusLine(allowed: Bool, available: Bool) -> String {
        if !allowed { return "Aus für reine Nearby-Nutzung." }
        if available { return "Backend bereit – Web-Viewer können beitreten." }
        return "Backend-URL fehlt. Setze webSocketServerURL in den Launch-Args."
    }

    #if DEBUG
    private var mockToggle: some View {
        HStack(spacing: 6) {
            Image(systemName: useMock ? "ladybug.fill" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 11, weight: .heavy))
            Text(useMock ? "MOCK" : "MULTIPEER")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.0)
        }
        .foregroundStyle(useMock ? Theme.amber : Theme.signal)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((useMock ? Theme.amber : Theme.signal).opacity(0.15))
        .overlay(
            Capsule().stroke((useMock ? Theme.amber : Theme.signal).opacity(0.4), lineWidth: 1)
        )
        .clipShape(Capsule())
        .onTapGesture {
            useMock.toggle()
            SessionManager.setMockPreferred(useMock)
            Haptics.tap()
        }
    }
    #endif

    private var footer: some View {
        VStack(spacing: 4) {
            Text("\"Alle sehen das Gruppenfoto, bevor es aufgenommen wird.\"")
                .font(.system(size: 13, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
        }
    }

    private var leopardSpots: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 42)
            for _ in 0..<60 {
                let x = CGFloat(rng.next()) * size.width
                let y = CGFloat(rng.next()) * size.height
                let r = 4 + CGFloat(rng.next()) * 18
                let path = Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r * 0.85))
                ctx.fill(path, with: .color(Theme.amber))
            }
        }
        .blur(radius: 1)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { self.state = seed | 1 }
    mutating func next() -> Double {
        state &*= 6364136223846793005
        state &+= 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}
