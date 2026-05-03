import SwiftUI

/// Centralized design constants — change a label/icon once, it updates everywhere.
/// All 3 surfaces (host, viewer, webapp) reference these for consistency.
/// English is the default language; no localization fallback.
enum DesignLabels {
    // MARK: - Buttons
    static let cancel = "Cancel"
    static let close = "Close"
    static let back = "Back"
    static let save = "Save"
    static let share = "Share"
    static let done = "Done"
    static let now = "Now"
    static let retake = "Retake"
    static let discard = "Discard"
    static let copyLink = "Copy Link"
    static let copied = "Copied"
    static let allowAccess = "Allow Access"
    static let join = "Join"
    static let connect = "Connect"

    static func timer(_ s: Int) -> String {
        "Start \(s)s"
    }

    // MARK: - Status
    static let statusConnected = "CONNECTED"
    static let statusConnecting = "CONNECTING"
    static let statusLive = "LIVE"
    static let statusReady = "READY"
    static let statusOffline = "OFFLINE"
    static let statusError = "ERROR"
    static let statusEnded = "ENDED"
    static let statusNotFound = "NOT FOUND"

    // MARK: - Common
    static let crew = "Crew"
    static let ready = "Ready"
    static let requestPhoto = "Request Photo"
    static let holdStill = "Hold still — smile!"
    static let countdownHoldStill = "HOLD STILL"
    static let backToPreview = "Back to preview"
    static let connectionLost = "Connection lost"
    static let connectionLostHint = "Captain is out of range. Try again from the Nearby list."
    static let sessionNotFound = "Session not found"
    static let sessionNotFoundHint = "Make sure both devices are connected and the app is open."
    static let sessionEnded = "Session ended"
    static let noCrewYet = "No crew yet — waiting for the captain's manifest…"
    static let waitingForFraming = "Waiting for Captain's framing…"
    static let requestFromCrew = "Request from crew — confirm in settings."
    static let onBoard = "on board"

    // MARK: - Home
    static let startCrewPhoto = "Start Crew Photo"
    static let joinSession = "Join Session"
    static let nearbySessions = "Nearby Sessions"
    static let allowWebViewers = "Allow Web Viewers"

    // MARK: - Host
    static let bestShot = "BEST SHOT"
    static let aiRankingActive = "AI RANKING ACTIVE"
    static let aiPick = "AI PICK"
    static let allShots = "ALL SHOTS"
    static let sendToCrew = "Send to Crew"
    static let sharp = "SHARP"
    static let faces = "FACES"
    static let openEyes = "OPEN"
    static let whoCanTrigger = "Who can trigger?"
    static let bestShotBurst = "Best-Shot Burst"
    static let burstDescription = "5 shots, AI picks the best."
    static let resolution = "Resolution"
    static let grid = "Grid"
    static let gridSubtitle = "Rule-of-thirds + safe-area frame."
    static let level = "Level"
    static let levelSubtitle = "Horizon indicator turns yellow when level."
    static let sessionExpiredMessage = "Sessions end automatically after TTL — no saving, no accounts, no traces."

    // MARK: - Viewer
    static let connectingToSession = "Connecting to session…"
    static let captain = "CAPTAIN"

    // MARK: - In-Frame Hints
    static let inFrameNoFaces = "Nobody in frame"
    static let inFrameAllInside = "Everyone's in"
    static let inFrameSomeClipped = "Someone's getting cut off"
    static let inFrameSkewedLeft = "Group is too far left"
    static let inFrameSkewedRight = "Group is too far right"
    static let inFrameTooHigh = "Camera position too low"
    static let inFrameTooLow = "Camera position too high"
    static let inFrameNoFacesHint = "Step back so everyone fits."
    static let inFrameSomeClippedHint = "Someone is at the edge — scoot in."
    static let inFrameSkewedLeftHint = "Move the group a bit right."
    static let inFrameSkewedRightHint = "Move the group a bit left."
    static let inFrameTooHighHint = "Lower the camera or step back."
    static let inFrameTooLowHint = "Raise the camera or step back."

    // MARK: - Trigger Permission
    static let triggerHostOnly = "Captain Only"
    static let triggerHostOnlySubtitle = "You alone give the command."
    static let triggerEveryone = "Crew can trigger"
    static let triggerEveryoneSubtitle = "Anyone on board can start the timer."
    static let triggerRequest = "Crew asks — Captain decides"
    static let triggerRequestSubtitle = "Request to you, you confirm."

    // MARK: - Nearby
    static let nearbyTitle = "Nearby Sessions"
    static let nearbySubtitle = "Sessions in your Wi-Fi / Bluetooth range."
    static let nearbySearching = "Searching for nearby sessions…"
    static let nearbyPermissionNote = "iOS will ask for local network permission the first time."
    static let nearbyHint = "Both devices need the app open, same Wi-Fi, and local network access allowed."
    static func nearbyHostStarting(_ name: String) -> String {
        "\(name) is starting a crew photo"
    }

    // MARK: - Reactions
    static let reactionReady = "Ready"
    static let reactionWait = "Wait"
    static let reactionAgain = "Again"
    static let reactionCantSeeMe = "Can't see me"
    static let reactionRaiseCamera = "Higher"
    static let reactionMoveLeft = "Left"
    static let reactionMoveRight = "Right"

    // MARK: - Icons (SF Symbols)
    static let iconBack = "chevron.backward"
    static let iconSettings = "slider.horizontal.3"
    static let iconCrew = "person.2.fill"
    static let iconQR = "qrcode"
    static let iconQRScan = "qrcode.viewfinder"
    static let iconCamera = "camera.fill"
    static let iconTimer = "timer"
    static let iconCancel = "xmark"
    static let iconSave = "square.and.arrow.down"
    static let iconShare = "square.and.arrow.up"
    static let iconCopy = "doc.on.doc"
    static let iconCopied = "checkmark"
    static let iconRetake = "arrow.counterclockwise"
    static let iconNow = "bolt.fill"
    static let iconStatus = "antenna.radiowaves.left.and.right"
    static let iconDiscard = "xmark"
    static let iconClose = "xmark"

    // MARK: - Reaction Icons (matching across platforms)
    static let reactionIcons: [String: String] = [
        "ready": "hand.thumbsup.fill",
        "wait": "hand.raised.fill",
        "again": "arrow.counterclockwise",
        "up": "arrow.up",
        "down": "arrow.down",
        "left": "arrow.left",
        "right": "arrow.right"
    ]
}
