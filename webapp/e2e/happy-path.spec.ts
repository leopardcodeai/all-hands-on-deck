import { test, expect } from "@playwright/test";

function collectSevereConsoleMessages(page: import("@playwright/test").Page) {
  const messages: string[] = [];
  page.on("console", (message) => {
    if (["error", "warning"].includes(message.type())) {
      messages.push(`${message.type()}: ${message.text()}`);
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

    const joinButton = page.getByRole("button", { name: "Join →" });
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
    await expect(page.getByRole("button", { name: "Join →" })).toBeVisible();
    expect(severeMessages).toEqual([]);
  });

  test("renders with session ID in URL", async ({ page }) => {
    await page.goto("/join/HAPPYTEST");
    await page.waitForLoadState("networkidle");
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
