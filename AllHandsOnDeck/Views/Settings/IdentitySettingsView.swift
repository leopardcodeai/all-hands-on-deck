import SwiftUI

struct IdentitySettingsView: View {
    @ObservedObject private var identity = IdentityService.shared
    @ObservedObject private var gc = GameCenterService.shared
    @FocusState private var nameFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.oceanFog.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        rankCard
                        customNameSection
                        gameCenterSection
                        progressSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle(String(localized: "identity.settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "OK")) { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var rankCard: some View {
        VStack(spacing: 6) {
            Text(identity.earnedRank.emoji)
                .font(.system(size: 52))
            Text(identity.earnedRank.title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Theme.bone)
            Text(identity.displayName)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var customNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("identity.customName.label", image: "person.fill")

            TextField(String(localized: "identity.customName.placeholder"), text: $identity.customName)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.bone)
                .tint(Theme.gold)
                .focused($nameFieldFocused)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if !identity.customName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(String(localized: "identity.customName.hint"))
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
            }
        }
    }

    private var gameCenterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("identity.gamecenter.label", image: "gamecontroller.fill")

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    if gc.isAuthenticated, let alias = gc.alias {
                        Text(alias)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.bone)
                        Text(String(localized: "identity.gamecenter.connected"))
                            .font(.caption)
                            .foregroundStyle(Theme.signal)
                    } else {
                        Text(String(localized: "identity.gamecenter.disconnected"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mist)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { identity.useGameCenter },
                    set: { on in
                        if on {
                            Task { await identity.enableGameCenter() }
                        } else {
                            identity.useGameCenter = false
                        }
                    }
                ))
                .labelsHidden()
                .tint(Theme.gold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if identity.useGameCenter && !gc.isAuthenticated {
                Text(String(localized: "identity.gamecenter.notSignedIn"))
                    .font(.caption)
                    .foregroundStyle(Theme.amber)
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("identity.progress.label", image: "chart.bar.fill")

            let points = UserDefaults.standard.integer(forKey: "identity.actionPoints")
            let nextRank = PirateRank(rawValue: identity.earnedRank.rawValue + 1)
            let nextThreshold = nextRank?.threshold ?? Int.max
            let current = identity.earnedRank

            VStack(spacing: 14) {
                HStack {
                    Text("\(points)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.gold)
                    Text(String(localized: "identity.progress.points"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.mist)
                        .padding(.top, 6)
                    Spacer()
                }

                if let next = nextRank {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(current.emoji + " " + current.title)
                                .font(.caption2)
                                .foregroundStyle(Theme.mist)
                            Spacer()
                            Text(next.emoji + " " + next.title)
                                .font(.caption2)
                                .foregroundStyle(Theme.mist)
                        }
                        ProgressView(value: Double(max(0, points - current.threshold)),
                                     total: Double(nextThreshold - current.threshold))
                            .tint(Theme.gold)
                    }
                } else {
                    Text(String(localized: "identity.progress.maxRank"))
                        .font(.caption)
                        .foregroundStyle(Theme.signal)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(String(localized: "identity.progress.hint"))
                .font(.caption)
                .foregroundStyle(Theme.mist)
        }
    }

    private func label(_ key: String, image: String) -> some View {
        Label(String(localized: String.LocalizationValue(key)),
              systemImage: image)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.mist)
    }
}
