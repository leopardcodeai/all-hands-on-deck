import SwiftUI

struct TimerPickerView: View {
    @Binding var seconds: Int
    let options: [Int]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { v in
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        seconds = v
                    }
                } label: {
                    Text("\(v)s")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .foregroundStyle(seconds == v ? .black : Theme.bone)
                        .background(
                            ZStack {
                                if seconds == v {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Theme.goldShine)
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
