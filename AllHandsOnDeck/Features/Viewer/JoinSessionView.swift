import SwiftUI

struct JoinSessionView: View {
    let displayName: String
    @State private var sessionID: String = ""
    @State private var connect: Bool = false
    @State private var showingScanner: Bool = false
    @State private var scanError: String?

    var body: some View {
        ZStack {
            LeopardWallpaperView()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(DesignLabels.join)
                            .font(Theme.display(36))
                            .foregroundStyle(Theme.bone)
                        Text("Enter the Captain's session code or scan a QR code.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.mist)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    TextField("ABCDEF1234", text: $sessionID)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.bone)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Theme.gold.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        PrimaryButton(title: DesignLabels.connect, systemImage: "arrow.right", style: .primary) {
                            if !sessionID.isEmpty { connect = true }
                        }
                        .disabled(sessionID.isEmpty)
                        .opacity(sessionID.isEmpty ? 0.5 : 1)

                        PrimaryButton(title: "Scan QR Code", systemImage: "qrcode.viewfinder", style: .secondary) {
                            showingScanner = true
                        }
                    }
                    .padding(.horizontal, 24)

                    if let err = scanError {
                        Text(err)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.crimson)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(DesignLabels.join)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.abyss, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $connect) {
            ViewerSessionView(
                session: PhotoSession(id: sessionID.uppercased(), hostName: "Host"),
                displayName: displayName
            )
        }
        .fullScreenCover(isPresented: $showingScanner) {
            QRScannerView(
                onResult: { raw in
                    showingScanner = false
                    if let id = SessionURLParser.sessionID(from: raw) {
                        sessionID = id
                        scanError = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            connect = true
                        }
                    } else {
                        scanError = "QR code doesn't contain a session ID."
                    }
                },
                onCancel: { showingScanner = false }
            )
            .ignoresSafeArea()
        }
    }
}
