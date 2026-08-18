const { test, expect } = require('@playwright/test');

test('companion demo explains its boundary and supports a sport filter', async ({ page }) => {
  await page.goto('/');

  await expect(page.getByText('Interactive Python demo — fixture-backed; not the PHP/MySQL runtime.')).toBeVisible();
  await expect(page.getByText('People in fixture')).toBeVisible();
  await expect(page.getByText('Equipment orders')).toBeVisible();

  const sportFilter = page.getByRole('combobox', { name: 'Sport filter' });
  await expect(sportFilter).toBeVisible();
  await sportFilter.click();
  await page.getByRole('option', { name: 'Soccer' }).click();

  await expect(page.getByText('Current view: Soccer.')).toBeVisible();
  await expect(page.locator('[data-testid="stDataFrame"]').first()).toBeVisible();
  await expect(page.locator('body')).toContainText('Lions FC');
  await expect(page.locator('body')).toContainText('Southside Strikers');
  await expect(page.getByText('Roster capacity')).toBeVisible();
});
