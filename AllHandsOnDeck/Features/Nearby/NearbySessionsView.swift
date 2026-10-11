import SwiftUI

struct NearbySessionsView: View {
    let displayName: String
    @StateObject private var vm: NearbySessionsViewModel
    @State private var selected: NearbySessionSummary?

    init(displayName: String) {
        self.displayName = displayName
        _vm = StateObject(wrappedValue: NearbySessionsViewModel(displayName: displayName))
    }

    var body: some View {
        ZStack {
            LeopardWallpaperView()

            VStack(spacing: 18) {
                header

                if vm.sessions.isEmpty {
                    emptyState
                } else {
                    list
                }

                Spacer()

                bottomHint
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("Nearby")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.abyss, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .navigationDestination(item: $selected) { summary in
            ViewerSessionView(
                session: summary.makePhotoSession(),
                displayName: displayName
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nearby Sessions")
                .font(Theme.display(34))
                .foregroundStyle(Theme.bone)
            Text("Sessions in deinem WLAN / Bluetooth-Bereich.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.mist)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(vm.sessions) { s in
                    Button {
                        Haptics.tap()
                        selected = s
                    } label: {
                        sessionRow(s)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sessionRow(_ s: NearbySessionSummary) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.goldShine)
                    .frame(width: 44, height: 44)
                Image(systemName: "crown.fill")
                    .foregroundStyle(.black)
                    .font(.system(size: 18, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: String(localized: "nearby.hostStartingSession"), s.hostName))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.bone)
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    Text("\(s.timerDuration)s")
                    Text("·")
                    Text(s.triggerPermission.title)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.mist)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.mist)
        }
        .padding(14)
        .liquidGlass(cornerRadius: 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Theme.gold)
            Text("Suche Sessions in der Nähe…")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.mist)
            Text("Beim ersten Mal fragt iOS nach einer\nLocal-Network-Berechtigung.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.mist.opacity(0.7))
        }
        .padding(.top, 40)
    }

    private var bottomHint: some View {
        Text("Beide Geräte müssen App geöffnet, im selben WLAN sein und Local-Network-Zugriff erlaubt haben.")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.mist)
            .multilineTextAlignment(.center)
    }
}
