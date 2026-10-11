#!/usr/bin/env node
/**
 * Take the two web screenshots for the README, reproducibly.
 *
 * Why this exists. The screenshots in docs/screenshots/ were made by hand, and
 * one of them (the captain view) ended up showing an empty green surface with
 * no explanation. That green is not a bug: Chrome's fake capture device paints
 * a synthetic test pattern, and the run that produced the picture used it. A
 * reader of the README could not know that, and nobody could reproduce the
 * picture to check.
 *
 * What it does. Starts a headed Chromium with the same fake-camera flags the
 * e2e suite uses, opens the captain page, waits until the session is live,
 * reads the session code off the page and opens the viewer on it. Both pages
 * are photographed into docs/screenshots/.
 *
 * Pitfalls, in the order they will bite:
 *   - The captain page only reaches LIVE with Supabase credentials in
 *     webapp/.env.local. Without them the page stays on its no-backend
 *     fallback, and the script says so instead of saving a useless picture.
 *   - The fake device needs a HEADED browser. Headless Chromium renders the
 *     pattern, but the page's own camera permission flow behaves differently.
 *   - The viewer needs a moment after joining before the first frame arrives.
 *     Saving too early is exactly how the empty green picture happened.
 *
 * Usage:
 *   npm run shoot              writes the files
 *   npm run shoot -- --dry-run opens everything, saves nothing
 */
import { chromium } from "@playwright/test";
import { existsSync, readFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HIER = dirname(fileURLToPath(import.meta.url));
const WEBAPP = resolve(HIER, "..");
const ZIEL = resolve(WEBAPP, "..", "docs", "screenshots");
const BASIS = process.env.SHOOT_URL || "http://localhost:5173";
const TROCKEN = process.argv.includes("--dry-run");

function hatBackend() {
  const datei = resolve(WEBAPP, ".env.local");
  if (!existsSync(datei)) return false;
  const text = readFileSync(datei, "utf8");
  return /^VITE_SUPABASE_URL=.+/m.test(text) && /^VITE_SUPABASE_ANON_KEY=.+/m.test(text);
}

async function sitzungscode(seite) {
  // Der Code steht als eigener Textknoten unter dem QR-Bild, sechs bis acht
  // Zeichen aus Grossbuchstaben und Ziffern. Er wird gelesen und nicht
  // geraten: der Viewer laeuft sonst auf eine fremde Sitzung.
  const treffer = await seite.evaluate(() => {
    const kandidaten = [...document.querySelectorAll("div,span,p,h1,h2,h3")]
      .map((el) => (el.textContent || "").trim())
      .filter((t) => /^[A-Z0-9]{6,8}$/.test(t));
    return kandidaten[0] || null;
  });
  return treffer;
}

async function main() {
  if (!hatBackend()) {
    console.error("  webapp/.env.local ohne Supabase-Zugang: die Kapitaensseite");
    console.error("  erreicht damit kein LIVE, und ein Bild davon waere wertlos.");
    process.exit(2);
  }
  mkdirSync(ZIEL, { recursive: true });
  const browser = await chromium.launch({
    headless: false,
    args: ["--use-fake-ui-for-media-stream", "--use-fake-device-for-media-stream"],
  });
  const kontext = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    permissions: ["camera"],
    baseURL: BASIS,
  });

  const kapitaen = await kontext.newPage();
  await kapitaen.goto("/host");
  // ⚠️ NICHT auf networkidle warten. Die Seite haelt eine offene Verbindung zum
  // Realtime-Backend, wird also nie "idle"; der erste Versuch lief hier 30
  // Sekunden in einen Timeout.
  await kapitaen.waitForLoadState("domcontentloaded");
  await kapitaen.waitForTimeout(4000);          // Kamera, Sitzung, erster Frame
  const code = await sitzungscode(kapitaen);
  const live = (await kapitaen.textContent("body"))?.includes("LIVE");
  console.log(`  Kapitaensseite: ${live ? "LIVE" : "NICHT live"}, Code ${code || "nicht gefunden"}`);

  if (!TROCKEN) {
    await kapitaen.screenshot({ path: resolve(ZIEL, "web_host_captain.jpg"), quality: 88, type: "jpeg" });
    console.log(`  geschrieben: ${resolve(ZIEL, "web_host_captain.jpg")}`);
  }

  if (code) {
    const viewer = await kontext.newPage();
    await viewer.goto(`/join/${code}`);
    await viewer.waitForLoadState("domcontentloaded");
    await viewer.waitForTimeout(6000);          // der erste Frame braucht laenger
    if (!TROCKEN) {
      await viewer.screenshot({ path: resolve(ZIEL, "web_join_live_frame.jpg"), quality: 88, type: "jpeg" });
      console.log(`  geschrieben: ${resolve(ZIEL, "web_join_live_frame.jpg")}`);
    }
  } else {
    console.error("  Kein Sitzungscode auf der Seite: der Viewer wurde uebersprungen.");
  }

  if (TROCKEN) console.log("  (Trockenlauf, nichts geschrieben)");
  await browser.close();
}

main().catch((fehler) => {
  console.error("  Fehlgeschlagen:", fehler.message);
  process.exit(1);
});
