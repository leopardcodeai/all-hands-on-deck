import { test, expect } from '@playwright/test';

test('pasted invite preserves its session code and case-sensitive token', async ({ page }) => {
  await page.goto('/');
  await page.getByPlaceholder('ABCDEF1234').fill('https://remotecameraapp.vercel.app/join/abc123?token=MixedCase-token&expires_at=2026-10-01');
  await page.getByRole('button', { name: 'Join Session' }).click();
  await expect(page).toHaveURL(/\/join\/ABC123\?token=MixedCase-token&expires_at=2026-10-01$/);
});

test('invalid session inputs stay disabled instead of being truncated', async ({ page }) => {
  await page.goto('/');
  for (const invalid of ['ABCDE', 'ABCDEFGHIJK', 'ABC123!extra', 'https://example.com/other/ABC123']) {
    await page.getByPlaceholder('ABCDEF1234').fill(invalid);
    await expect(page.getByRole('button', { name: 'Join Session' })).toBeDisabled();
  }
});

test('hosting explains web access without offering an ineffective nearby-only switch', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Captain', exact: true }).click();
  await expect(page.getByText('Crew members can join in a browser using your session code or QR code.')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Start Crew Photo' })).toBeEnabled();
});

for (const width of [320, 390, 1440]) {
  test(`home fits ${width}px and honors reduced motion`, async ({ page }, testInfo) => {
    await page.setViewportSize({ width, height: 900 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/');
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(width);
    await expect(page.locator('.bg-glow-1')).toHaveCSS('animation-name', 'none');
    await page.screenshot({ path: testInfo.outputPath(`home-${width}.png`), fullPage: true });
    await page.getByRole('button', { name: 'Captain', exact: true }).click();
    await page.screenshot({ path: testInfo.outputPath(`host-options-${width}.png`), fullPage: true });
  });
}

test('privacy and imprint links open their documents', async ({ page }) => {
  for (const label of ['Privacy', 'Imprint']) {
    await page.goto('/');
    await page.getByRole('link', { name: label, exact: true }).click();
    await expect(page).toHaveURL(new RegExp(`/${label.toLowerCase()}\\.html$`));
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  }
});
