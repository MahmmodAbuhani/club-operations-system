const path = require('path');
const { test, expect } = require('@playwright/test');

const screenshots = path.resolve(__dirname, '../../docs/screenshots');

async function login(page, email) {
  await page.goto('/?page=login');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password').fill('demo123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
}

test.use({ viewport: { width: 1440, height: 900 } });

test('capture verified interface evidence', async ({ page }) => {
  await page.goto('/?page=login');
  await page.screenshot({ path: path.join(screenshots, '01-login.png'), fullPage: true });

  await login(page, 'riley.bennett@example.test');
  await page.screenshot({ path: path.join(screenshots, '02-riley-dashboard.png'), fullPage: true });

  await page.getByRole('link', { name: 'Order Equipment' }).click();
  await expect(page.getByRole('heading', { name: 'Equipment Fulfillment' })).toBeVisible();
  await expect(page.getByText('Outstanding quantity').first()).toBeVisible();
  await page.screenshot({ path: path.join(screenshots, '03-equipment-fulfillment.png'), fullPage: true });

  await page.getByRole('button', { name: 'Sign out' }).click();
  await login(page, 'priya.nair@example.test');
  await page.getByRole('link', { name: 'Reports' }).click();
  await expect(page.getByRole('heading', { name: 'Admin Analytics Reports' })).toBeVisible();
  await page.screenshot({ path: path.join(screenshots, '04-admin-analytics.png'), fullPage: true });
});
