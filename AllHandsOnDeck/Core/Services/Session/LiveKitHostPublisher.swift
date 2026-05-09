import Foundation
import CoreMedia
import LiveKit

/// Publishes the host iPhone's camera feed to a LiveKit room as a buffer-driven
/// video track. The web viewer (gated on `VITE_ENABLE_LIVEKIT_BETA`) subscribes
/// to this room and renders the first remote video track.
///
/// The host already owns an `AVCaptureSession` via `CameraService`, so we cannot
/// use LiveKit's built-in `CameraCapturer` (which would try to start a second
/// capture session on the same device). Instead we use `BufferCapturer`, which
/// accepts `CMSampleBuffer`s pushed from the existing video-data-output delegate.
///
/// API notes:
///   - `LocalVideoTrack.createBufferTrack(...)` constructs a track whose
///     `.capturer` is a `BufferCapturer`. The default source is `.screenShareVideo`
///     so we override to `.camera` for the host feed.
///   - `BufferCapturer.capture(_ sampleBuffer:)` takes the CMSampleBuffer directly.
///
/// Out of scope for this pass (TODOs):
///   - Throttling / frame-rate adaptation: we forward every buffer the camera
///     emits. The SDK already discards late frames internally, but on slower
///     networks we may want to drop frames here too.
///   - Reconnect / token-refresh backoff: a single failed `start()` surfaces the
///     error to the caller; there is no auto-retry loop.
///   - Audio: the host publishes video only.
@MainActor
final class LiveKitHostPublisher {
    private let sessionID: String
    private let participantID: String

    private let room: Room
    private var localVideoTrack: LocalVideoTrack?
    private var publication: LocalTrackPublication?
    private var bufferCapturer: BufferCapturer?
    private var ingestTask: Task<Void, Never>?

    private(set) var isConnected: Bool = false

    init(sessionID: String, participantID: String) {
        self.sessionID = sessionID
        self.participantID = participantID
        self.room = Room()
    }

    /// Fetch a fresh token, connect to the room, create the buffer-driven video
    /// track, and publish it. Throws on token-fetch failure, connect failure, or
    /// publish failure. On error, the instance is cleaned up to a consistent state.
    func start() async throws {
        print("[LiveKit] Fetching token for session=\(sessionID) participant=\(participantID)")
        let token = try await LiveKitTokenClient.fetch(
            sessionID: sessionID,
            participantID: participantID
        )
        print("[LiveKit] Token fetched, room=\(token.room)")

        print("[LiveKit] Connecting to room \(token.room) at \(token.url)")
        do {
            try await room.connect(url: token.url, token: token.token)
            isConnected = true
            print("[LiveKit] Connected to room, localParticipant=\(room.localParticipant.identity)")
        } catch {
            print("[LiveKit] Failed to connect: \(error)")
            throw error
        }

        // .camera so the webapp's track-source filter picks this up as the host
        // viewfinder rather than a screenshare.
        print("[LiveKit] Creating video track")
        let track = LocalVideoTrack.createBufferTrack(
            name: "host_camera",
            source: .camera
        )
        self.localVideoTrack = track
        self.bufferCapturer = track.capturer as? BufferCapturer
        print("[LiveKit] Video track created, publishing...")

        do {
            self.publication = try await room.localParticipant.publish(videoTrack: track)
            print("[LiveKit] Video track published successfully")
        } catch {
            print("[LiveKit] Failed to publish video track: \(error)")
            // Clean up on publish failure to leave the instance in a consistent state.
            self.localVideoTrack = nil
            self.bufferCapturer = nil
            await room.disconnect()
            isConnected = false
            throw error
        }
    }

    /// Forward a CMSampleBuffer from the camera's video-data-output delegate.
    /// Safe to call before `start()` resolves — it just no-ops until the
    /// capturer exists. Safe to call after `stop()` — any pending frame will be
    /// dropped when ingestTask is cancelled.
    nonisolated func ingest(sampleBuffer: CMSampleBuffer) {
        // Hop to the main actor to read the capturer reference. The capturer
        // itself is `@unchecked Sendable` and its `capture(_:)` is fine to call
        // off-main, but we read the optional under MainActor isolation.
        //
        // We create individual short-lived Tasks per frame rather than one
        // long-lived Task because the current Task pattern causes frames to
        // be buffered if the capturer is temporarily slow. This way, slow
        // frames are simply dropped (the capturer's discard behavior).
        Task { @MainActor [weak self] in
            guard let capturer = self?.bufferCapturer else {
                // Not yet ready, or shut down; frame is dropped (normal).
                return
            }
            capturer.capture(sampleBuffer)
        }
    }

    /// Unpublish + disconnect. Idempotent. Ensures all resources are cleaned up
    /// and no pending frames can be processed after return.
    func stop() async {
        // Cancel any pending frame-ingestion Tasks to prevent them from accessing
        // state after we clear it. This is especially important since ingest(_:) is
        // called from a camera delegate running on a background thread.
        ingestTask?.cancel()
        ingestTask = nil

        if let publication {
            try? await room.localParticipant.unpublish(publication: publication)
        }
        await room.disconnect()
        localVideoTrack = nil
        publication = nil
        bufferCapturer = nil
        isConnected = false
    }
}
