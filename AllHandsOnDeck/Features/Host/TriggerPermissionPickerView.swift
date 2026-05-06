import SwiftUI

struct TriggerPermissionPickerView: View {
    @Binding var selection: TriggerPermission

    var body: some View {
        VStack(spacing: 8) {
            ForEach(TriggerPermission.allCases) { p in
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = p
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: p.symbol)
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                            Text(p.subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.mist)
                        }
                        Spacer()
                        if selection == p {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.gold)
                        }
                    }
                    .foregroundStyle(Theme.bone)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selection == p ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selection == p ? Theme.gold.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
