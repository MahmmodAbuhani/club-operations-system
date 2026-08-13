const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

async function login(page, email) {
  await page.goto('/?page=login');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password').fill('demo123');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
}

async function expectAccessible(page) {
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
    .analyze();
  expect(results.violations).toEqual([]);
}

test('login has no automated WCAG A or AA violations and visible keyboard focus', async ({ page }) => {
  await page.goto('/?page=login');
  await expect(page).toHaveTitle('Demo Login | Club Operations System');
  await expect(page.getByRole('link', { name: 'Club Operations System' })).toBeVisible();
  await expect(page.getByLabel('Password')).toHaveValue('');
  await expectAccessible(page);
  await page.keyboard.press('Tab');
  const outlineStyle = await page.locator(':focus').evaluate((element) => getComputedStyle(element).outlineStyle);
  expect(outlineStyle).not.toBe('none');
});

for (const rolePage of [
  ['riley.bennett@example.test', 'Equipment Fulfillment'],
  ['mike.torres@example.test', 'My Coach Teams'],
  ['priya.nair@example.test', 'Admin Analytics Reports']
]) {
  test(`${rolePage[1]} has no automated WCAG A or AA violations`, async ({ page }) => {
    await login(page, rolePage[0]);
    await page.getByRole('link', { name: rolePage[1] === 'Equipment Fulfillment' ? 'Order Equipment' : rolePage[1] === 'My Coach Teams' ? 'Coach Teams' : 'Reports' }).click();
    await expect(page.getByRole('heading', { name: rolePage[1] })).toBeVisible();
    await expectAccessible(page);
  });
}

test('fulfillment page reflows without horizontal page scrolling at 320 CSS pixels', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await login(page, 'riley.bennett@example.test');
  await page.getByRole('link', { name: 'Order Equipment' }).click();
  const dimensions = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
});
