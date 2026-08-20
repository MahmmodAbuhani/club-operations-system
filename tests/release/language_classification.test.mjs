import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const attributes = [
  'linguist-language',
  'linguist-detectable',
  'linguist-generated',
  'linguist-vendored'
];
const expectedLanguages = new Map([
  ['sql/01_schema.sql', 'SQL'],
  ['tests/e2e/walkthrough.spec.js', 'JavaScript'],
  ['tests/release/presentation_contract.test.mjs', 'JavaScript'],
  ['tests/sql/concurrency.sh', 'Shell']
]);

test('Git attributes keep authored SQL, JavaScript, and shell sources visible to Linguist', async () => {
  const { stdout } = await execFileAsync(
    'git',
    ['check-attr', ...attributes, '--', ...expectedLanguages.keys()],
    { cwd: repoRoot }
  );
  const resolved = new Map();

  for (const line of stdout.trim().split('\n')) {
    const [file, attribute, value] = line.split(': ');
    resolved.set(`${file}\0${attribute}`, value);
  }

  for (const [file, language] of expectedLanguages) {
    assert.equal(resolved.get(`${file}\0linguist-language`), language, `${file} language`);
    assert.equal(resolved.get(`${file}\0linguist-detectable`), 'true', `${file} visibility`);
    assert.equal(resolved.get(`${file}\0linguist-generated`), 'unspecified', `${file} generated status`);
    assert.equal(resolved.get(`${file}\0linguist-vendored`), 'unspecified', `${file} vendored status`);
  }
});
