import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { readPngDimensions, scanRepository } from '../../scripts/scan_public_surface.mjs';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const fixtureRoots = [];

async function fixture(files) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'sportlfc-public-scan-'));
  fixtureRoots.push(root);

  for (const [relativePath, contents] of Object.entries(files)) {
    const absolutePath = path.join(root, relativePath);
    await mkdir(path.dirname(absolutePath), { recursive: true });
    await writeFile(absolutePath, contents);
  }

  return root;
}

async function scanFixture(markdown, extraFiles = {}) {
  const root = await fixture({ 'README.md': markdown, ...extraFiles });
  return scanRepository(root, { projectChecks: false });
}

test.after(async () => {
  await Promise.all(fixtureRoots.map((root) => rm(root, { recursive: true, force: true })));
});

test('public-tree discovery excludes tool caches but scans nested public files', async () => {
  const privateCachePath = ['/Us', 'ers/vendor/cache'].join('');
  const root = await fixture({
    'README.md': '# Clean fixture\n',
    'docs/public.md': 'Gate status: CLOSED\n',
    '.git': `gitdir: ${privateCachePath}\n`,
    'node_modules/dependency/readme.md': `${privateCachePath}\n`
  });

  const findings = await scanRepository(root, { projectChecks: false });

  assert.deepEqual(findings.map(({ code }) => code), ['internal-wording']);
});

test('private user-home paths are rejected', async () => {
  const privatePath = ['/Us', 'ers/alice/private/report.md'].join('');
  const findings = await scanFixture(`Local file: ${privatePath}\n`);

  assert.deepEqual(findings.map(({ code }) => code), ['private-path']);
});

test('institutional email addresses are rejected', async () => {
  const institutionalEmail = ['analyst@college', '.edu'].join('');
  const findings = await scanFixture(`Contact ${institutionalEmail}\n`);

  assert.deepEqual(findings.map(({ code }) => code), ['institutional-email']);
});

test('internal publication wording is rejected', async () => {
  const findings = await scanFixture('Reviewer gate and owner approval are pending.\n');

  assert.deepEqual(findings.map(({ code }) => code), ['internal-wording']);
});

test('internal publication wording variants are rejected', async () => {
  for (const phrase of [
    'Agents prepared this package.',
    'The release gate is pending.',
    'The publication gate is pending.',
    'Reviewers prepared this package.',
    'Owner-approval is pending.'
  ]) {
    const findings = await scanFixture(`${phrase}\n`);
    assert.deepEqual(findings.map(({ code }) => code), ['internal-wording'], phrase);
  }
});

test('hype, filler, vague links, and em dashes are rejected', async () => {
  const findings = await scanFixture(
    "In today's world, this production-ready system unlocks value—[click here](https://example.com).\n"
  );

  assert.deepEqual(
    new Set(findings.map(({ code }) => code)),
    new Set(['hype', 'filler', 'plain-language'])
  );
});

test('the required Streamlit boundary label is allowed while other em dashes remain rejected', async () => {
  const requiredLabel = 'Interactive Python demo — fixture-backed; not the PHP/MySQL runtime.';
  assert.deepEqual(await scanFixture(`${requiredLabel}\n`), []);

  const findings = await scanFixture('A different public sentence — with an em dash.\n');
  assert.deepEqual(findings.map(({ code }) => code), ['plain-language']);
});

test('missing local Markdown links are rejected', async () => {
  const findings = await scanFixture('[Schema](docs/missing.md)\n');

  assert.deepEqual(findings.map(({ code }) => code), ['broken-link']);
});

test('Markdown anchors decode and normalize expected whitespace before matching', async () => {
  const findings = await scanFixture(
    '[Schema](docs/target.md#data%20%20contract)\n',
    { 'docs/target.md': '## Data\tcontract\n' }
  );

  assert.deepEqual(findings, []);
});

test('malformed encoded Markdown anchors fail as broken links', async () => {
  const findings = await scanFixture(
    '[Schema](docs/target.md#data%ZZcontract)\n',
    { 'docs/target.md': '## Data contract\n' }
  );

  assert.deepEqual(findings.map(({ code }) => code), ['broken-link']);
});

test('missing screenshot files are rejected', async () => {
  const findings = await scanFixture('![Evidence](docs/screenshots/evidence.png)\n');

  assert.deepEqual(findings.map(({ code }) => code), ['missing-image']);
});

test('invalid PNG screenshot files are rejected', async () => {
  const findings = await scanFixture('![Evidence](docs/screenshots/evidence.png)\n', {
    'docs/screenshots/evidence.png': 'not a png'
  });

  assert.deepEqual(findings.map(({ code }) => code), ['invalid-image']);
});

test('documentation tooling is exact and resolves from the local lockfile', async () => {
  const packageJson = JSON.parse(await readFile(path.join(projectRoot, 'package.json'), 'utf8'));
  const makefile = await readFile(path.join(projectRoot, 'Makefile'), 'utf8');

  assert.equal(packageJson.devDependencies['@mermaid-js/mermaid-cli'], '11.16.0');
  assert.equal(packageJson.scripts.erd, 'mmdc -i docs/erd.mmd -o docs/erd.svg -b transparent');
  assert.match(makefile, /^\s*npm run erd$/mu);
  assert.doesNotMatch(makefile, /npx\s+-y\s+@mermaid-js\/mermaid-cli/u);
});

test('social preview is a valid 1280 by 640 PNG with public provenance', async () => {
  const preview = await readFile(path.join(projectRoot, 'docs/social-preview.png'));
  const provenance = await readFile(path.join(projectRoot, 'docs/SOCIAL_PREVIEW.md'), 'utf8');

  assert.deepEqual(readPngDimensions(preview), { width: 1280, height: 640 });
  assert.match(provenance, /npm run social-preview/u);
  assert.match(provenance, /03-equipment-fulfillment\.png/u);
});

test('public visual hash ledger matches every checked-in visual artifact', async () => {
  const ledger = await readFile(path.join(projectRoot, 'docs/VISUAL_HASHES.md'), 'utf8');
  const rows = [...ledger.matchAll(/^\| `([^`]+)` \| `([a-f0-9]{64})` \|$/gmu)];

  assert.equal(rows.length, 6);
  for (const [, relativePath, expectedHash] of rows) {
    const actualHash = createHash('sha256')
      .update(await readFile(path.join(projectRoot, relativePath)))
      .digest('hex');
    assert.equal(actualHash, expectedHash, relativePath);
  }
});
