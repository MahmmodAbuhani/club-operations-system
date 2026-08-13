import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const readPublicFile = (relativePath) => readFile(path.join(projectRoot, relativePath), 'utf8');

function markdownSection(markdown, heading) {
  const lines = markdown.split(/\r?\n/u);
  const start = lines.indexOf(`## ${heading}`);
  if (start === -1) {
    return '';
  }

  const nextHeading = lines.findIndex((line, index) => index > start && line.startsWith('## '));
  const end = nextHeading === -1 ? lines.length : nextHeading;
  return lines.slice(start + 1, end).join('\n').trim();
}

function dependabotDirectories(config, ecosystem) {
  return config
    .split(/\n(?=\s{2}- package-ecosystem: )/u)
    .filter((block) => block.includes(`package-ecosystem: ${ecosystem}`))
    .map((block) => {
      const directory = block.match(/^\s+directory:\s*(\S+)\s*$/mu);
      assert.ok(directory, `${ecosystem} updater is missing a directory`);
      return directory[1];
    });
}

test('public package metadata uses the intended repository identity', async () => {
  const packageJson = JSON.parse(await readPublicFile('package.json'));

  assert.equal(packageJson.name, 'club-operations-system');
  assert.equal(
    packageJson.description,
    'Local PHP/MySQL reference system for database integrity, role-aware workflows, concurrency tests, and reproducible fictional evidence.'
  );
  assert.equal(
    packageJson.repository.url,
    'git+https://github.com/MahmmodAbuhani/club-operations-system.git'
  );
});

test('every Docker updater targets a directory with a real Dockerfile', async () => {
  const dependabot = await readPublicFile('.github/dependabot.yml');
  const dockerDirectories = dependabotDirectories(dependabot, 'docker');

  assert.deepEqual(dockerDirectories, ['/web']);
  await Promise.all(
    dockerDirectories.map((directory) =>
      access(path.join(projectRoot, directory.replace(/^\//u, ''), 'Dockerfile'))
    )
  );
});

test('README provides an authored abstract, proof route, evidence labels, and closing boundary', async () => {
  const readme = await readPublicFile('README.md');
  const abstract = markdownSection(readme, 'Abstract');
  const abstractParagraph = abstract.split(/\n\s*\n/u)[0];
  const wordCount = abstractParagraph.split(/\s+/u).filter(Boolean).length;

  assert.match(readme, /^# Club Operations System\n+Welcome to Club Operations System\./u);
  assert.ok(wordCount >= 60 && wordCount <= 120, `abstract has ${wordCount} words`);
  assert.ok(markdownSection(readme, '90-second guide'));
  assert.ok(markdownSection(readme, 'Core methods'));
  assert.ok(markdownSection(readme, 'Working familiarity'));
  assert.ok(markdownSection(readme, 'Limits, data, rights, and security'));
  assert.ok(markdownSection(readme, 'Intended use'));
  assert.doesNotMatch(readme, /^## Additional experience$/mu);
});

test('public evidence describes repository CI without implying deployment', async () => {
  const readme = await readPublicFile('README.md');
  const validation = await readPublicFile('docs/VALIDATION.md');

  assert.match(readme, /\.github\/workflows\/ci\.yml/u);
  assert.match(readme, /No hosted run is claimed for this snapshot/u);
  assert.match(validation, /No hosted run is claimed for this snapshot/u);
  assert.doesNotMatch(readme, /sportlfc-data-systems-portfolio/u);
  assert.doesNotMatch(validation, /11 portable release regression tests/u);
  assert.match(readme, /No hosted environment/u);
  assert.match(readme, /No production users/u);
});

test('security policy routes private reports without promising production support', async () => {
  const policy = await readPublicFile('SECURITY.md');
  const plainPolicy = policy.replace(/[*_`]/gu, '');

  assert.match(plainPolicy, /Security tab/u);
  assert.match(plainPolicy, /Report a vulnerability/u);
  assert.match(plainPolicy, /do not open a public issue/iu);
  assert.match(plainPolicy, /does not provide a production service-level agreement/u);
  assert.doesNotMatch(plainPolicy, /@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/u);
});
