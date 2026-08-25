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

function markdownLinks(markdown) {
  return [...markdown.matchAll(/\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)/gu)].map(
    ([, label, href]) => ({ label, href })
  );
}

function streamlitWakeInstructions(markdown) {
  return markdown
    .split(/\n\s*\n/u)
    .filter(
      (paragraph) =>
        /may be asleep after inactivity/u.test(paragraph) && /wake it back up/u.test(paragraph)
    );
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

test('README consolidates runtime boundaries in one concise Project scope section', async () => {
  const readme = await readPublicFile('README.md');
  const abstract = markdownSection(readme, 'Abstract');
  const scope = markdownSection(readme, 'Project scope');
  const affiliationStatements = readme.match(/not affiliated with Liverpool FC/gu) ?? [];

  assert.ok(scope, 'README must include a Project scope section');
  assert.match(scope, /GitHub Pages[\s\S]*static/iu);
  assert.match(scope, /Streamlit[\s\S]*fixture-backed[\s\S]*read-only/iu);
  assert.match(scope, /PHP\/MySQL[\s\S]*local/iu);
  assert.match(scope, /not operated as a production service/iu);
  assert.equal(affiliationStatements.length, 1, 'README must contain one non-affiliation statement');
  assert.doesNotMatch(abstract, /Liverpool FC/iu);
  assert.equal(markdownSection(readme, 'Public demo boundary'), '');
});

test('README puts the first-minute route before the social preview and synchronizes demo labels', async () => {
  const readme = await readPublicFile('README.md');
  const walkthrough = await readPublicFile('docs/index.html');
  const streamlitGuide = await readPublicFile('docs/STREAMLIT_DEMO.md');
  const guideIndex = readme.indexOf('## 90-second guide');
  const previewIndex = readme.indexOf('![Club Operations System social preview');

  assert.ok(guideIndex >= 0, 'README must include the 90-second guide');
  assert.ok(previewIndex >= 0, 'README must include the social preview');
  assert.ok(guideIndex < previewIndex, 'the first-minute route must precede the social preview');
  assert.match(readme, /interactive Python demo/iu);
  assert.doesNotMatch(readme, /live interactive Python demo/iu);
  assert.match(walkthrough, /Interactive Python demo/u);
  assert.match(streamlitGuide, /Open the \[Interactive Python demo\]/u);
});

test('public demo links use the working canonical Streamlit route', async () => {
  const canonicalUrl = 'https://club-operations-system-demo.streamlit.app/';
  const retiredUrl = 'https://club-operations-demo.streamlit.app/';
  const markdownPaths = ['README.md', 'docs/STREAMLIT_DEMO.md', 'docs/VALIDATION.md'];
  const markdownSurfaces = await Promise.all(
    markdownPaths.map(async (relativePath) => [relativePath, await readPublicFile(relativePath)])
  );

  for (const [relativePath, markdown] of markdownSurfaces) {
    const hrefs = new Set(markdownLinks(markdown).map(({ href }) => href));
    assert.equal(hrefs.has(canonicalUrl), true, `${relativePath} must link to the canonical demo`);
    assert.equal(hrefs.has(retiredUrl), false, `${relativePath} must not link to the retired demo`);
  }

  const walkthrough = await readPublicFile('docs/index.html');
  const walkthroughHrefs = new Set(
    [...walkthrough.matchAll(/href=["']([^"']+)["']/gu)].map(([, href]) => href)
  );

  assert.equal(walkthroughHrefs.has(canonicalUrl), true, 'walkthrough must link to the canonical demo');
  assert.equal(
    walkthroughHrefs.has(retiredUrl),
    false,
    'walkthrough must not link to the retired demo'
  );
});

test('Streamlit availability wording accounts for inactivity sleep state', async () => {
  const readme = await readPublicFile('README.md');
  const guide = await readPublicFile('docs/STREAMLIT_DEMO.md');
  const readmeInstructions = streamlitWakeInstructions(readme);
  const detailedGuideInstructions = streamlitWakeInstructions(guide);

  assert.equal(
    readmeInstructions.length,
    1,
    'README must give exactly one public Streamlit sleep and wake instruction'
  );
  assert.match(markdownSection(readme, '90-second guide'), /wake it back up/u);
  assert.ok(
    detailedGuideInstructions.length >= 1,
    'Streamlit guide must retain detailed sleep and wake instructions'
  );
});

test('README routes visitors to the hosted walkthrough instead of repository source', async () => {
  const readme = await readPublicFile('README.md');
  const guide = markdownSection(readme, '90-second guide');
  const links = markdownLinks(guide);
  const guideOpening = guide.split(/\n\s*\n/u)[0];
  const guideOpeningWords = guideOpening.split(/\s+/u).filter(Boolean).length;

  assert.equal(
    links.some(({ href }) => href === 'docs/index.html'),
    false,
    'the recruiter route must not open the walkthrough source file in GitHub'
  );
  assert.equal(
    links.some(
      ({ href }) => href === 'https://mahmmodabuhani.github.io/club-operations-system/#scenarios'
    ),
    true,
    'the recruiter route must open the hosted walkthrough at its scenarios'
  );
  assert.ok(guideOpeningWords <= 90, `guide opening has ${guideOpeningWords} words`);
  assert.match(guide, /Static evidence walkthrough/u);
  assert.match(guide, /GitHub Pages/u);
  assert.match(guide, /select a sport/u);
  assert.doesNotMatch(guide, /GitHub Pages is not enabled/u);
  assert.doesNotMatch(guide, /artifact is not hosted/u);
  assert.match(guide, /Role authorization/u);
  assert.match(guide, /Roster concurrency/u);
  assert.match(guide, /Equipment fulfillment/u);
  assert.match(guide, /Invariant handling/u);
});

test('public evidence distinguishes hosted static proof from the local PHP and MySQL system', async () => {
  const readme = await readPublicFile('README.md');
  const validation = await readPublicFile('docs/VALIDATION.md');
  const walkthrough = await readPublicFile('docs/index.html');

  assert.match(readme, /\.github\/workflows\/ci\.yml/u);
  assert.match(readme, /https:\/\/github\.com\/MahmmodAbuhani\/club-operations-system\/actions\/workflows\/ci\.yml/u);
  assert.match(readme, /https:\/\/mahmmodabuhani\.github\.io\/club-operations-system\//u);
  assert.match(readme, /PHP\/MySQL application remains local/u);
  assert.match(validation, /static evidence walkthrough is hosted on GitHub Pages/u);
  assert.match(validation, /PHP\/MySQL system remains local/u);
  assert.match(walkthrough, /hosted page is a static evidence layer/u);
  assert.match(walkthrough, /PHP\/MySQL system remains local/u);
  assert.doesNotMatch(readme, /No hosted run is claimed for this snapshot/u);
  assert.doesNotMatch(validation, /No hosted run is claimed for this snapshot/u);
  assert.doesNotMatch(walkthrough, /It is not deployed/u);
  assert.doesNotMatch(readme, /sportlfc-data-systems-portfolio/u);
  assert.doesNotMatch(validation, /11 portable release regression tests/u);
  assert.doesNotMatch(readme, /No hosted environment/u);
  assert.match(readme, /No production users/u);
});

test('validation record describes the complete eight-stage verification path', async () => {
  const validation = await readPublicFile('docs/VALIDATION.md');

  assert.match(validation, /performs eight dependency-ordered stages/u);
  assert.match(validation, /static walkthrough release contracts/u);
  assert.match(validation, /five walkthrough browser checks/iu);
  assert.match(validation, /320 CSS-pixel walkthrough reflow/u);
});

test('validation record separates automated and manual evidence without a completeness claim', async () => {
  const validation = await readPublicFile('docs/VALIDATION.md');

  assert.match(validation, /^## Automated verification$/mu);
  assert.match(validation, /^## Manual browser and visual checks$/mu);
  assert.doesNotMatch(validation, /accessibility (?:is )?complete/iu);
  assert.match(validation, /actual 400 percent browser zoom/iu);
  assert.match(validation, /keyboard-only sign-out/iu);
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
