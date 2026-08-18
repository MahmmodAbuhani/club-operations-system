const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

function watchExternalRequests(page) {
  const external = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.origin !== 'http://127.0.0.1:4173') {
      external.push(request.url());
    }
  });
  return external;
}

test('walkthrough states its boundary and loads only local runtime resources', async ({ page }) => {
  const externalRequests = watchExternalRequests(page);
  await page.goto('/');

  await expect(page).toHaveTitle('Evidence walkthrough | Club Operations System');
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Trace four system rules');
  await expect(page.getByText('Static page, no live backend')).toBeVisible();
  await expect(page.getByText('does not connect to the PHP/MySQL application')).toBeVisible();
  await expect(page.locator('form, input, iframe')).toHaveCount(0);
  expect(externalRequests).toEqual([]);
});

test('desktop opening exposes all four scenarios and a working evidence path', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/');

  const hero = page.locator('.hero');
  for (const name of [
    'Role authorization',
    'Roster concurrency',
    'Equipment fulfillment',
    'Invariant handling'
  ]) {
    const label = hero.getByText(name, { exact: true });
    await expect(label).toBeVisible();
    const box = await label.boundingBox();
    expect(box).not.toBeNull();
    expect(box.y + box.height).toBeLessThanOrEqual(900);
  }

  const evidencePath = hero.getByRole('link', { name: 'Open the scenario evidence' });
  await expect(evidencePath).toBeVisible();
  const pathBox = await evidencePath.boundingBox();
  expect(pathBox).not.toBeNull();
  expect(pathBox.y + pathBox.height).toBeLessThanOrEqual(900);

  await evidencePath.click();
  await expect(page).toHaveURL(/#scenarios$/u);
  await expect(page.getByRole('tab', { name: 'Role authorization' })).toBeVisible();
});

test('walkthrough has no automated WCAG A or AA violations', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
    .analyze();
  expect(results.violations).toEqual([]);
});

test('scenario tabs support keyboard selection and preserve evidence provenance', async ({ page }) => {
  await page.goto('/');
  const tabs = page.getByRole('tab');

  await tabs.first().focus();
  await page.keyboard.press('ArrowRight');
  await expect(tabs.nth(1)).toBeFocused();
  await expect(tabs.nth(1)).toHaveAttribute('aria-selected', 'true');
  await expect(page.locator('#scenario-title')).toHaveText(
    'Two final-slot writes serialize to one valid winner'
  );
  await expect(page.locator('#scenario-image')).toHaveAttribute('src', './erd.svg');
  await expect(page.locator('#scenario-image')).toHaveAttribute('alt', /Entity relationship diagram/u);
  await expect(page.locator('#scenario-image-link')).toHaveAttribute('href', './erd.svg');
  await expect(page.locator('#scenario-image-link')).toContainText('Open full-size image');
  await expect(page.locator('#scenario-hash')).toHaveText(/^[a-f0-9]{64}$/u);
  await expect(page.locator('#scenario-evidence a')).toHaveCount(4);

  await page.keyboard.press('End');
  await expect(tabs.nth(3)).toBeFocused();
  await expect(page.locator('#scenario-title')).toHaveText(
    'Invalid relationships fail without changing valid state'
  );
  await page.keyboard.press('Home');
  await expect(tabs.first()).toBeFocused();
  await expect(page.locator('#scenario-progress')).toHaveText('Scenario 1 of 4');
});

test('walkthrough reflows without horizontal page scrolling at 320 CSS pixels', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 800 });
  await page.goto('/');

  const dimensions = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth
  }));
  expect(dimensions.scrollWidth).toBeLessThanOrEqual(dimensions.clientWidth);
  await expect(page.getByRole('tab')).toHaveCount(4);
  await expect(page.getByRole('img')).toBeVisible();
});
