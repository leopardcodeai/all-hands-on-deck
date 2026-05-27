/**
 * Centralized design constants — change a label once, it updates everywhere.
 * Mirrors AllHandsOnDeck/Utilities/DesignLabels.swift on iOS.
 * English default, no localization fallback.
 */

export const DesignLabels = {
  // Buttons
  cancel: 'Cancel',
  close: 'Close',
  back: 'Back',
  save: 'Save',
  share: 'Share',
  shareTitle: 'Crew Photo',
  done: 'Done',
  now: 'Now',
  retake: 'Retake',
  discard: 'Discard',
  copyLink: 'Copy Link',
  copied: 'Copied',
  allowAccess: 'Allow Access',
  join: 'Join',
  connect: 'Connect',

  timer: (s: number) => `Start ${s}s`,

  // Status
  statusConnected: 'CONNECTED',
  statusConnecting: 'CONNECTING',
  statusLive: 'LIVE',
  statusReady: 'READY',
  statusOffline: 'OFFLINE',
  statusError: 'ERROR',
  statusEnded: 'ENDED',
  statusNotFound: 'NOT FOUND',

  // Common
  crew: 'Crew',
  ready: 'Ready',
  requestPhoto: 'Request Photo',
  holdStill: 'Hold still — smile!',
  backToPreview: 'Back to preview',
  connectionLost: 'Connection lost',
  connectionLostHint: "Captain is out of range. Try again from the Nearby list.",
  sessionNotFound: 'Session not found',
  sessionNotFoundHint: 'Make sure both devices are connected and the app is open.',
  sessionEnded: 'Session ended',
  noCrewYet: "No crew yet — waiting for the captain's manifest…",
  waitingForFraming: "Waiting for Captain's framing…",
  onBoard: 'on board',

  // Home
  startCrewPhoto: 'Start Crew Photo',
  startAsHost: 'Start as Host',
  hostCamera: 'Your Camera',
  hostSessionCode: 'Session Code',
  hostViewers: 'Viewers',
  hostEndSession: 'End Session',
  hostNoViewers: 'No viewers yet — share the code above',
  hostCountdown: (s: number) => `${s}`,
  hostPhotoReady: 'Photo ready!',
  hostSendToViewers: 'Send to Viewers',
  settings: 'Settings',
  settingsHint: 'Open timer, permissions, grid and HD options',
  hideQRCode: 'Hide QR code',
  showQRCode: 'Show QR code',
  qrToggleHint: 'Lets crew members scan to join the session',
  backHint: 'Returns to the home screen',

  // Home
  joinSession: 'Join Session',
  nearbySessions: 'Nearby Sessions',
  betaBadge: 'BETA',
  allowWebViewers: 'Allow Web Viewers',

  // Reactions
  reactionReady: 'Ready',
  reactionWait: 'Wait',
  reactionAgain: 'Again',
  reactionCantSeeMe: "Can't see me",
  reactionRaiseCamera: 'Higher',
  reactionMoveLeft: 'Left',
  reactionMoveRight: 'Right',

  // Countdown
  countdownHoldStill: 'HOLD STILL',

  // Nearby
  nearbyTitle: 'Nearby Sessions',
  nearbySubtitle: 'Sessions in your Wi-Fi / Bluetooth range.',
  nearbySearching: 'Searching for nearby sessions…',
  nearbyPermissionNote: 'iOS will ask for local network permission the first time.',
  nearbyHint: 'Both devices need the app open, same Wi-Fi, and local network access allowed.',
  nearbyHostStarting: (name: string) => `${name} is starting a crew photo`,

  // Home
  byCaptainLeopard: 'vibecoded with ❤️ by LeopardCode.AI',
  appName: 'All Hands On Deck',
  homeSubtitle: "Web viewer for Captain's live crew photo session.\nEnter the code below or scan the Captain's QR code.",
  sessionCodePlaceholder: 'ABCDEF1234',
  noInstall: 'No install. No sign-in.',
  privacy: 'Privacy',
  imprint: 'Imprint',
  joinArrow: 'Join →',
  iconCrew: '👥',

  // Connection lost
  overboard: 'OVERBOARD.',
  connectionLostBody: "Lost the connection to Captain's ship. Could be the WiFi, could be the Captain bailed early. Try rejoining or scanning a new code.",
  rejoin: '↻ REJOIN',
  home: 'HOME',
} as const;
