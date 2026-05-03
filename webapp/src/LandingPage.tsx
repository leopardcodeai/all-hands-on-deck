import { useNavigate } from 'react-router-dom';

const PIRATE_NAMES = [
  'Deckhand Mia',
  'Boatswain Kai',
  'Cabin Boy Joe',
  'First Mate Lia',
  'Captain Alex',
];

export function LandingPage() {
  const navigate = useNavigate();

  return (
    <div className="landing-page">
      <nav className="landing-nav">
        <div className="landing-nav-inner">
          <div className="landing-nav-brand">
            <span className="landing-skull">☠</span>
            <div className="landing-nav-text">
              <span className="landing-nav-title">ALL HANDS ON DECK</span>
              <span className="landing-nav-by">BY CAPTAIN LEOPARD</span>
            </div>
          </div>
          <div className="landing-nav-links">
            <a href="#features" className="landing-nav-link">Features</a>
            <a href="#how" className="landing-nav-link">How it works</a>
            <button className="btn-primary btn-sm" onClick={() => navigate('/join')}>
              JOIN A CREW →
            </button>
          </div>
        </div>
      </nav>

      <section className="landing-hero">
        <div className="landing-hero-content">
          <span className="pill pill-signal">● iOS 17+ · No account needed</span>
          <h1 className="landing-headline">
            EVERYONE<br />SEES THE<br />FRAME.
          </h1>
          <p className="landing-description">
            Group photos where every crew member sees the live preview, reacts in real time,
            and gets the final shot instantly. No accounts. No tracking. Just point, smile, done.
          </p>
          <div className="landing-cta">
            <button className="btn-primary" onClick={() => navigate('/join')}>
              APP STORE
            </button>
            <button className="btn-secondary" onClick={() => navigate('/join')}>
              JOIN VIA SESSION CODE
            </button>
          </div>
          <p className="landing-footer">
            NO ACCOUNTS · NO TRACKING · 10MIN TTL
          </p>
        </div>

        <div className="landing-hero-visual">
          <div className="phone-mockup">
            <div className="phone-screen">
              <div className="phone-notch" />
              <div className="phone-camera-preview">
                <div className="phone-crew-pill">
                  <span className="pill pill-signal" style={{ fontSize: 9 }}>● 5 ABOARD</span>
                </div>
                <div className="phone-shutter" />
              </div>
            </div>
          </div>
          <div className="watch-mockup">
            <div className="watch-face">
              <span className="watch-countdown">0:03</span>
              <span className="watch-label">SMILE!</span>
            </div>
          </div>
        </div>
      </section>

      <section id="features" className="landing-features">
        <h2 className="landing-section-title">Why All Hands?</h2>
        <div className="landing-feature-grid">
          <div className="landing-feature-card">
            <span className="landing-feature-icon">👁️</span>
            <h3>Live Preview for All</h3>
            <p>Every crew member sees exactly what the Captain sees — in real time.</p>
          </div>
          <div className="landing-feature-card">
            <span className="landing-feature-icon">⏱️</span>
            <h3>Countdown Sync</h3>
            <p>Shared countdown means everyone knows when to hold still and smile.</p>
          </div>
          <div className="landing-feature-card">
            <span className="landing-feature-icon">📸</span>
            <h3>Instant Photo</h3>
            <p>Final photo delivered to every device the moment it&apos;s taken.</p>
          </div>
          <div className="landing-feature-card">
            <span className="landing-feature-icon">🏴‍☠️</span>
            <h3>No Accounts</h3>
            <p>Join with a six-character code. No sign-up, no email, no nonsense.</p>
          </div>
        </div>
      </section>

      <section id="how" className="landing-how">
        <h2 className="landing-section-title">How it works</h2>
        <div className="landing-steps">
          <div className="landing-step">
            <span className="landing-step-num">1</span>
            <h3>Captain opens the app</h3>
            <p>One device becomes the camera. It shares a session code.</p>
          </div>
          <div className="landing-step">
            <span className="landing-step-num">2</span>
            <h3>Crew joins via code</h3>
            <p>Everyone enters the code or scans the QR. They see the live preview.</p>
          </div>
          <div className="landing-step">
            <span className="landing-step-num">3</span>
            <h3>Timer counts down</h3>
            <p>Captain or crew triggers the countdown. Everyone sees it live.</p>
          </div>
          <div className="landing-step">
            <span className="landing-step-num">4</span>
            <h3>Photo delivered</h3>
            <p>The final shot appears on every screen. Share or save — your call.</p>
          </div>
        </div>
      </section>

      <footer className="landing-footer-bar">
        <div className="landing-footer-inner">
          <span>☠ ALL HANDS ON DECK</span>
          <span>by Captain Leopard</span>
          <div className="landing-footer-links">
            <a href="/privacy">Privacy</a>
            <a href="/imprint">Imprint</a>
          </div>
        </div>
      </footer>
    </div>
  );
}
