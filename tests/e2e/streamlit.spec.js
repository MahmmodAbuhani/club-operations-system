const { test, expect } = require('@playwright/test');

test('companion demo explains its boundary and supports a sport filter', async ({ page }) => {
  test.setTimeout(30_000);
  const runtimeWarnings = [];
  page.on('console', (message) => {
    if (message.type() === 'warning') {
      runtimeWarnings.push(message.text());
    }
  });

  await page.goto('/');

  await expect(page.getByText('Interactive Python demo: fixture-backed, not the PHP/MySQL runtime.')).toBeVisible({ timeout: 20_000 });
  await expect(page.getByText('People in fixture')).toBeVisible();
  await expect(page.getByText('Equipment orders')).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Explore the fixture' })).toBeVisible();
  await expect(page.getByText('Choose a sport to focus the roster, equipment, staffing, and fee views.')).toBeVisible();

  const sportFilter = page.getByRole('combobox', { name: 'Sport filter' });
  await expect(sportFilter).toBeVisible();
  await sportFilter.click();
  await page.getByRole('option', { name: 'Soccer' }).click();

  await expect(page.getByText('Current view: Soccer.')).toBeVisible();
  await expect(page.locator('[data-testid="stDataFrame"]').first()).toBeVisible();
  await expect(page.locator('body')).toContainText('Lions FC');
  await expect(page.locator('body')).toContainText('Southside Strikers');
  await expect(page.getByText('Roster capacity')).toBeVisible();
  expect(runtimeWarnings.filter((message) => /Scale bindings|Infinite extent|use_container_width/u.test(message))).toEqual([]);
});

test('companion demo keeps the filter visible at a narrow viewport', async ({ page }) => {
  test.setTimeout(30_000);
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto('/');

  await expect(page.getByRole('heading', { name: 'Explore the fixture' })).toBeVisible({ timeout: 20_000 });
  await expect(page.getByRole('combobox', { name: 'Sport filter' })).toBeVisible();

  const overflow = await page.evaluate(() => ({
    documentWidth: document.documentElement.scrollWidth,
    viewportWidth: document.documentElement.clientWidth,
  }));
  expect(overflow.documentWidth).toBe(overflow.viewportWidth);
});
