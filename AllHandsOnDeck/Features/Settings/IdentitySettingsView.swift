import SwiftUI

struct IdentitySettingsView: View {
    @ObservedObject private var identity = IdentityService.shared
    @ObservedObject private var gc = GameCenterService.shared
    @FocusState private var nameFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LeopardWallpaperView()
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        rankCard
                        customNameSection
                        gameCenterSection
                        progressSection
                    }
                    .padding(Spacing.xl)
                }
            }
            .navigationTitle(DesignLabels.identitySettingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(DesignLabels.done) { dismiss() }
                        .foregroundStyle(Theme.gold)
                        .accessibilityIdentifier("identity_done")
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
                .padding(.horizontal, Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var customNameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            label(DesignLabels.identityCustomNameLabel, image: "person.fill")

            TextField(DesignLabels.identityCustomNamePlaceholder, text: $identity.customName)
                .accessibilityIdentifier("identity_custom_name")
                .accessibilityLabel(DesignLabels.identityCustomNameLabel)
                .submitLabel(.done)
                .onSubmit { nameFieldFocused = false }
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.bone)
                .tint(Theme.gold)
                .focused($nameFieldFocused)
                .padding(.horizontal, Spacing.lg)
                .frame(height: Spacing.buttonHeight)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerMd, style: .continuous))

            if !identity.customName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(DesignLabels.identityCustomNameHint)
                    .font(.caption)
                    .foregroundStyle(Theme.mist)
            }
        }
    }

    private var gameCenterSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            label(DesignLabels.identityGameCenterLabel, image: "gamecontroller.fill")

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    if gc.isAuthenticated, let alias = gc.alias {
                        Text(alias)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.bone)
                        Text(DesignLabels.identityGameCenterConnected)
                            .font(.caption)
                            .foregroundStyle(Theme.signal)
                    } else {
                        Text(DesignLabels.identityGameCenterDisconnected)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.mist)
                    }
                }
                Spacer()
                Toggle(DesignLabels.identityGameCenterLabel, isOn: Binding(
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
                .accessibilityIdentifier("identity_game_center")
                .tint(Theme.gold)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerMd, style: .continuous))

            if identity.useGameCenter && !gc.isAuthenticated {
                Text(DesignLabels.identityGameCenterNotSignedIn)
                    .font(.caption)
                    .foregroundStyle(Theme.amber)
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            label(DesignLabels.identityProgressLabel, image: "chart.bar.fill")

            let points = identity.actionPoints
            let nextRank = PirateRank(rawValue: identity.earnedRank.rawValue + 1)
            let nextThreshold = nextRank?.threshold ?? Int.max
            let current = identity.earnedRank

            VStack(spacing: 14) {
                HStack {
                    Text("\(points)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.gold)
                    Text(DesignLabels.identityProgressPoints)
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
                    Text(DesignLabels.identityProgressMaxRank)
                        .font(.caption)
                        .foregroundStyle(Theme.signal)
                }
            }
            .padding(Spacing.lg)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerMd, style: .continuous))

            Text(DesignLabels.identityProgressHint)
                .font(.caption)
                .foregroundStyle(Theme.mist)
        }
    }

    private func label(_ title: String, image: String) -> some View {
        Label(title, systemImage: image)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.mist)
    }
}

#Preview { IdentitySettingsView() }
