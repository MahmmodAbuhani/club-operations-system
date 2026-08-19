import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const readPublicFile = (relativePath) => readFile(path.join(projectRoot, relativePath), 'utf8');

test('Streamlit companion has compatible runtime inputs and a browser contract', async () => {
  const requirements = await readPublicFile('demo/requirements.txt');
  const app = await readPublicFile('demo/streamlit_app.py');
  const browserConfig = await readPublicFile('playwright.streamlit.config.js');

  assert.equal(requirements.trim(), 'pandas>=2.3,<3\nstreamlit>=1.54,<2');
  assert.match(app, /Interactive Python demo: fixture-backed, not the PHP\/MySQL runtime\./u);
  assert.doesNotMatch(app, /Interactive Python demo — fixture-backed/u);
  assert.match(app, /fixture_snapshot\.json/u);
  assert.match(app, /sql\/02_seed\.sql/u);
  assert.match(app, /st\.cache_data/u);
  assert.match(browserConfig, /streamlit run demo\/streamlit_app\.py/u);
  assert.match(browserConfig, /testMatch: 'streamlit\.spec\.js'/u);
  await access(path.join(projectRoot, '.streamlit/config.toml'));
  await access(path.join(projectRoot, 'demo/fixture_snapshot.json'));
});

test('Streamlit companion keeps controls visible and progress tables explicit', async () => {
  const app = await readPublicFile('demo/streamlit_app.py');

  assert.match(app, /st\.subheader\("Explore the fixture"\)/u);
  assert.match(app, /st\.selectbox\(\s*"Sport filter"/su);
  assert.doesNotMatch(app, /with st\.sidebar:/u);
  assert.match(app, /FulfillmentPercent/u);
  assert.match(app, /ProgressColumn/u);
  assert.doesNotMatch(app, /import altair/u);
  assert.doesNotMatch(app, /st\.(altair_chart|bar_chart)\(/u);
  assert.doesNotMatch(app, /use_container_width/u);
});

test('Streamlit source links point to files present in the public tree', async () => {
  const app = await readPublicFile('demo/streamlit_app.py');
  const sourcePaths = [...app.matchAll(/blob\/main\/([^`\)]+)/gu)].map((match) => match[1]);

  assert.deepEqual(sourcePaths, [
    'demo/fixture_snapshot.json',
    'demo/streamlit_data.py',
    'sql/02_seed.sql',
  ]);
  for (const sourcePath of sourcePaths) {
    await access(path.join(projectRoot, sourcePath));
  }
});

test('package and Make targets expose the Streamlit verification path', async () => {
  const packageJson = JSON.parse(await readPublicFile('package.json'));
  const makefile = await readPublicFile('Makefile');
  const workflow = await readPublicFile('.github/workflows/ci.yml');

  assert.equal(packageJson.scripts['test:streamlit'], 'playwright test --config=playwright.streamlit.config.js tests/e2e/streamlit.spec.js');
  assert.match(makefile, /^fixture-snapshot:/mu);
  assert.match(makefile, /^verify-streamlit:/mu);
  assert.match(workflow, /^  streamlit:/mu);
  assert.match(workflow, /demo\/requirements\.txt/u);
  assert.match(workflow, /make verify-streamlit/u);
});
