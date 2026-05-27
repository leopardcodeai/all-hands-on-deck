import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var linkHandler: UniversalLinkHandler
    @StateObject private var vm = HomeViewModel()
    @ObservedObject private var identity = IdentityService.shared
    @ObservedObject private var retention = HostSessionRetention.shared
    @State private var showingHost = false
    @State private var showingJoin = false
    @State private var showingNearby = false
    @State private var showingIdentity = false
    @State private var deepLinkSession: PhotoSession?
    @State private var allowWebJoin: Bool = UserDefaults.standard.bool(forKey: "allowWebJoinDefault")
    @State private var jokeIndex: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                LeopardWallpaperView()

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
                } onClose: {
                    showingHost = false
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
                StatusPill(label: "vibecoded with ❤️ by LeopardCode.AI", systemImage: "flag.fill", tint: Theme.gold)
                Spacer()
                Button { showingIdentity = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.mist)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Identity settings")
                .accessibilityHint("Change your display name or view your pirate rank")
            }
            Text("All Hands\nOn Deck")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(Theme.bone)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("The Captain's Live Crew Photo Preview")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actions: some View {
        VStack(spacing: 14) {
            identityChip

            PrimaryButton(
                title: retention.remainingSeconds.map {
                    String(format: String(localized: "home.resumeIn"), $0)
                } ?? "Start Crew Photo",
                systemImage: "camera.fill",
                style: .primary
            ) {
                showingHost = true
            }
            .accessibilityIdentifier("host_start_crew_photo")
            PrimaryButton(title: "Join Session", systemImage: "qrcode.viewfinder", style: .secondary) {
                showingJoin = true
            }
            .accessibilityIdentifier("host_join_session")
            PrimaryButton(title: "Nearby Sessions", systemImage: "antenna.radiowaves.left.and.right", style: .ghost) {
                showingNearby = true
            }
            .accessibilityIdentifier("host_nearby_sessions")

            // Web-Join toggle. Persisted; off by default — most sessions
            // happen in person and don't need a backend.
            let webAvailable = SessionManager.isWebJoinAvailable
            let effectivelyOn = allowWebJoin && webAvailable
            HStack(spacing: 12) {
                Image(systemName: webAvailable ? "globe" : "globe.badge.chevron.backward")
                    .foregroundStyle(effectivelyOn ? Theme.signal : (allowWebJoin && !webAvailable ? Theme.crimson : Theme.mist))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(DesignLabels.allowWebViewers)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.bone)
                        Text(DesignLabels.betaBadge)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.goldShine, in: Capsule())
                            .accessibilityLabel(DesignLabels.betaBadge)
                    }
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
        if !allowed { return DesignLabels.webViewersOff }
        if available { return DesignLabels.webViewersReady }
        return DesignLabels.webViewersMissingConfig
    }

    private let pirateJokes: [String] = [
        "Why is pirating so addictive? Lose one hand and ye get hooked!",
        "What's a pirate's fav letter? Ye think it's R — but it's the C!",
        "How much did peg leg and hook cost? An arm and a leg!",
        "What d'ye call a pirate who skips class? Captain Hooky!",
        "Why couldn't the pirate play cards? He was standing on the deck!",
        "What's a pirate's fav country? ARRRgentina!",
        "What did the ocean say to the pirate? Nothing — it just waved!",
        "What d'ye call a pirate with two eyes and two hands? A rookie!",
        "Why did the pirate fail his exams? He couldn't get an ARRRR!",
        "Why do pirates make great singers? They always hit the high C's!",
        "What did the pirate say on his 80th birthday? Aye matey!",
        "What's a pirate's fav fast food? Arrrby's!",
        "How do pirates prefer their steaks? ARRR-rare!",
        "What's a pirate's fav doll? Barrrrbie!",
        "How do pirates communicate? Aye to aye, Captain!",
        "Why do pirates read so slowly? They spend years at C!",
        "What's a pirate's fav element? ARRRgon!",
        "What d'ye call a pirate with no ship? Stranded!",
        "Why did the pirate go to acting school? He wanted more ARRRs!",
        "What's a pirate's least fav vegetable? Leeks — he hates a leaky ship!"
    ]

    private var footer: some View {
        VStack(spacing: 10) {
            Text(pirateJokes[jokeIndex])
                .font(.system(size: 13, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
                .task {
                    jokeIndex = Int.random(in: 0..<pirateJokes.count)
                }
            HStack(spacing: 14) {
                Link("Privacy", destination: URL(string: "https://all-hands-on-deck-ae29e.web.app/privacy")!)
                Text("·")
                Link("Imprint", destination: URL(string: "https://all-hands-on-deck-ae29e.web.app/imprint")!)
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.mist.opacity(0.7))
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

// MARK: - Previews

#Preview("Default") {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(UniversalLinkHandler())
}

#Preview("Dark") {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(UniversalLinkHandler())
        .preferredColorScheme(.dark)
}
