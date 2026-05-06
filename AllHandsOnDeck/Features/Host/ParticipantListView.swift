import SwiftUI

struct ParticipantListView: View {
    let participants: [Participant]
    let pendingRequestIDs: [String]
    var onApprove: (String) -> Void
    var onDeny: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(DesignLabels.crew)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(Theme.mist)
                Spacer()
                Text("\(participants.count)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.gold)
            }

            ForEach(participants) { p in
                HStack(spacing: 10) {
                    Image(systemName: p.role == .host ? "crown.fill" : "person.fill")
                        .foregroundStyle(p.role == .host ? Theme.gold : Theme.bone)
                        .frame(width: 22)
                    Text(p.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.bone)
                    Spacer()
                    if pendingRequestIDs.contains(p.id) {
                        HStack(spacing: 4) {
                            Button {
                                onDeny(p.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.bone)
                                    .frame(width: 28, height: 28)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            Button {
                                onApprove(p.id)
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.goldShine)
                                    .clipShape(Circle())
                            }
                        }
                        .buttonStyle(.plain)
                    } else if p.isReady {
                        Text("Bereit")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.signal)
                    }
                }
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 18)
    }
}
