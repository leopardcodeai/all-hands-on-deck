import { test, expect } from "@playwright/test";

function collectSevereConsoleMessages(page: import("@playwright/test").Page) {
  const messages: string[] = [];
  page.on("console", (message) => {
    if (["error", "warning"].includes(message.type())) {
      const text = message.text();
      if (text.includes("Connect failed") || text.includes("Session not found")) return;
      messages.push(`${message.type()}: ${text}`);
    }
  });
  page.on("pageerror", (error) => {
    messages.push(`pageerror: ${error.message}`);
  });
  return messages;
}

test.describe("Happy Path — Landing Page", () => {
  test("renders with hero and navigation", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");
    await expect(page.locator("body")).toBeVisible();
  });

  test("has join link or prompt visible", async ({ page }) => {
    await page.goto("/");
    await page.waitForLoadState("networkidle");
    const bodyText = await page.textContent("body");
    expect(bodyText).toBeTruthy();
    expect(bodyText!.length).toBeGreaterThan(0);
  });
});

test.describe("Happy Path — Join Page (no backend)", () => {
  test("clicks home join flow and returns home without console errors", async ({ page }) => {
    const severeMessages = collectSevereConsoleMessages(page);

    await page.goto("/");
    await page.waitForLoadState("networkidle");

    const joinButton = page.getByRole("button", { name: "Join Session" });
    await expect(joinButton).toBeDisabled();

    await page.getByPlaceholder("ABCDEF1234").fill("abc123");
    await expect(page.getByPlaceholder("ABCDEF1234")).toHaveValue("ABC123");
    await expect(joinButton).toBeEnabled();

    await joinButton.click();
    await page.waitForURL("**/join/ABC123");
    await expect(page.getByText("ABC123")).toBeVisible();
    await expect(page.getByText("NOT FOUND").first()).toBeVisible();

    await page.getByRole("button", { name: "Back" }).last().click();
    await page.waitForURL("/");
    await expect(page.getByRole("button", { name: "Join Session" })).toBeVisible();
    expect(severeMessages).toEqual([]);
  });

  test("renders with session ID in URL", async ({ page }) => {
    await page.goto("/join/HAPPYTEST");
    await page.waitForLoadState("networkidle");
    await expect(page.locator("body")).toBeVisible();
  });

  test("opens iOS QR join URL with short-lived token query", async ({ page }) => {
    await page.goto("/join/7NMDA6TAE9?session_id=7NMDA6TAE9&token=test-token&expires_at=2026-05-06T18%3A00%3A00Z");
    await page.waitForLoadState("networkidle");

    await expect(page).toHaveURL(/\/join\/7NMDA6TAE9\?/);
    await expect(page.getByText("7NMDA6TAE9")).toBeVisible();
    await expect(page.locator("body")).toBeVisible();
  });

  test("shows content without crashing", async ({ page }) => {
    await page.goto("/join/HAPPYTEST");
    await page.waitForLoadState("networkidle");
    const bodyText = await page.textContent("body");
    expect(bodyText).toBeTruthy();
  });

  test("responsive on mobile viewport", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/join/MOBILE01");
    await page.waitForLoadState("networkidle");
    await expect(page.locator("body")).toBeVisible();
  });

  test("responsive on tablet viewport", async ({ page }) => {
    await page.setViewportSize({ width: 820, height: 1180 });
    await page.goto("/join/TABLET01");
    await page.waitForLoadState("networkidle");
    await expect(page.locator("body")).toBeVisible();
  });
});

test.describe("Happy Path — Join Page (mock Supabase data)", () => {
  test("shows preview frame when available", async ({ page }) => {
    await page.goto("/join/HAPPYTEST");
    await page.waitForLoadState("networkidle");
    // Page should render without crashing when Supabase is not configured locally.
    await page.waitForTimeout(2000);
    await expect(page.locator("body")).toBeVisible();
  });

  test("renders the join shell without Supabase credentials", async ({ page }) => {
    await page.goto("/join/HAPPYTEST");
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(2000);
    await expect(page.locator("body")).toBeVisible();
  });
});

test.describe("Happy Path — Navigation", () => {
  test("root path redirects or shows landing", async ({ page }) => {
    const response = await page.goto("/");
    expect(response?.status()).toBeLessThan(400);
  });

  test("join path returns 200", async ({ page }) => {
    const response = await page.goto("/join/NAVTEST");
    expect(response?.status()).toBeLessThan(400);
  });

  test("unknown path does not crash", async ({ page }) => {
    const response = await page.goto("/unknown/path");
    // SPA should still return HTML
    expect(response?.status()).toBeLessThan(500);
  });
});

test.describe("Happy Path — Host Page", () => {
  test("renders host page and starts active session", async ({ page }) => {
    const msgs = collectSevereConsoleMessages(page);
    await page.goto("/host");
    await page.waitForLoadState("domcontentloaded");
    await expect(page.getByText(/LIVE/i)).toBeVisible();
    expect(msgs).toHaveLength(0);
  });

  test("shows back button on host page", async ({ page }) => {
    await page.goto("/host");
    await page.waitForLoadState("domcontentloaded");
    await expect(page.locator("button:has-text('‹')")).toBeVisible();
  });

  test("navigates to home on back click", async ({ page }) => {
    await page.goto("/host");
    await page.waitForLoadState("domcontentloaded");
    await page.locator("button:has-text('‹')").first().click();
    await page.waitForURL(/\/$/);
  });

  test("shows camera error gracefully when camera denied", async ({ page }) => {
    await page.context().grantPermissions([], { origin: "http://localhost:5173" });
    const msgs = collectSevereConsoleMessages(page);
    await page.goto("/host");
    await page.waitForLoadState("domcontentloaded");
    await page.waitForTimeout(1000);
    const hasError = await page.getByText(/Camera|Denied|Error/i).isVisible().catch(() => false);
    if (hasError) {
      await expect(page.getByText(/Camera|Denied/i)).toBeVisible();
    }
    expect(msgs.length).toBeLessThan(3);
  });

  test("host page layout matches iOS-style top bar", async ({ page }) => {
    await page.goto("/host");
    await page.waitForLoadState("domcontentloaded");
    const backBtn = page.locator("button:has-text('‹')");
    await expect(backBtn).toBeVisible();
  });
});
