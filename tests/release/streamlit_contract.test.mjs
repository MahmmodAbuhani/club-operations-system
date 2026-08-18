import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const readPublicFile = (relativePath) => readFile(path.join(projectRoot, relativePath), 'utf8');

test('Streamlit companion has pinned runtime inputs and a browser contract', async () => {
  const requirements = await readPublicFile('demo/requirements.txt');
  const app = await readPublicFile('demo/streamlit_app.py');
  const browserConfig = await readPublicFile('playwright.streamlit.config.js');

  assert.equal(requirements.trim(), 'pandas==2.2.2\nstreamlit==1.32.0');
  assert.match(app, /Interactive Python demo — fixture-backed; not the PHP\/MySQL runtime\./u);
  assert.match(app, /fixture_snapshot\.json/u);
  assert.match(app, /sql\/02_seed\.sql/u);
  assert.match(app, /st\.cache_data/u);
  assert.match(browserConfig, /streamlit run demo\/streamlit_app\.py/u);
  assert.match(browserConfig, /testMatch: 'streamlit\.spec\.js'/u);
  await access(path.join(projectRoot, '.streamlit/config.toml'));
  await access(path.join(projectRoot, 'demo/fixture_snapshot.json'));
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
