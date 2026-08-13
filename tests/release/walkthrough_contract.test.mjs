import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { access, readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const docsRoot = path.join(projectRoot, 'docs');
const repositoryPrefix = 'https://github.com/MahmmodAbuhani/club-operations-system/blob/main/';
const requiredFiles = [
  'docs/index.html',
  'docs/walkthrough.css',
  'docs/walkthrough-data.js',
  'docs/walkthrough.js',
  'docs/.nojekyll'
];

async function exists(relativePath) {
  try {
    await access(path.join(projectRoot, relativePath));
    return true;
  } catch {
    return false;
  }
}

async function loadWalkthroughData() {
  const source = await readFile(path.join(docsRoot, 'walkthrough-data.js'), 'utf8');
  const moduleUrl = `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
  return import(moduleUrl);
}

test('walkthrough public files exist', async () => {
  const checks = await Promise.all(requiredFiles.map(async (file) => [file, await exists(file)]));
  const missing = checks.filter(([, present]) => !present).map(([file]) => file);
  assert.deepEqual(missing, []);
});

test('walkthrough scenarios are complete and map to real repository evidence', async () => {
  const { scenarios } = await loadWalkthroughData();
  assert.deepEqual(
    scenarios.map(({ id }) => id),
    ['role-authorization', 'roster-concurrency', 'equipment-fulfillment', 'invariant-handling']
  );

  for (const scenario of scenarios) {
    for (const field of ['kicker', 'title', 'rule', 'expected', 'limitation']) {
      assert.ok(scenario[field]?.trim(), `${scenario.id} is missing ${field}`);
    }
    assert.ok(scenario.evidence.length >= 2, `${scenario.id} needs at least two evidence links`);

    for (const item of scenario.evidence) {
      assert.ok(item.label?.trim(), `${scenario.id} has an unlabeled evidence link`);
      assert.ok(item.href.startsWith(repositoryPrefix), `${scenario.id} points outside the repository`);
      const target = decodeURIComponent(item.href.slice(repositoryPrefix.length).split('#')[0]);
      assert.equal(await exists(target), true, `${scenario.id} points to missing ${target}`);
    }
  }
});

test('walkthrough visuals match repository provenance', async () => {
  const { scenarios } = await loadWalkthroughData();

  for (const scenario of scenarios) {
    const { src, alt, caption, sha256 } = scenario.visual;
    assert.match(src, /^(screenshots\/[a-z0-9-]+\.png|erd\.svg)$/u);
    assert.ok(alt?.trim(), `${scenario.id} visual needs alt text`);
    assert.ok(caption?.trim(), `${scenario.id} visual needs a caption`);
    assert.match(sha256, /^[a-f0-9]{64}$/u);

    const bytes = await readFile(path.join(docsRoot, src));
    const actual = createHash('sha256').update(bytes).digest('hex');
    assert.equal(actual, sha256, `${scenario.id} visual hash drifted`);
  }
});

test('walkthrough is explicit about its static boundary and loads no remote runtime assets', async () => {
  const html = await readFile(path.join(docsRoot, 'index.html'), 'utf8');
  const runtimeReferences = [
    ...html.matchAll(/<(?:script|link)\b[^>]+(?:src|href)=["']([^"']+)["']/giu)
  ].map((match) => match[1]);

  assert.match(html, /Interactive evidence walkthrough/u);
  assert.match(html, /Static page, no live backend/u);
  assert.match(html, /does not connect to the PHP\/MySQL application/u);
  assert.doesNotMatch(html, /<form\b|<input\b|<iframe\b/iu);
  assert.doesNotMatch(html, /analytics|tracking pixel|tag manager/iu);
  assert.deepEqual(runtimeReferences.sort(), ['./walkthrough.css', './walkthrough.js']);
});
