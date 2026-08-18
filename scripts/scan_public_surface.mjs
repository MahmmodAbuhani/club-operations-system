#!/usr/bin/env node

import { access, readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const SKIPPED_DIRECTORIES = new Set([
  '.git',
  '.worktrees',
  'coverage',
  'node_modules',
  'test-results',
  'vendor'
]);

const PROSE_EXTENSIONS = new Set(['.html', '.md', '.txt']);
const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const VISUAL_ARTIFACTS = [
  'docs/erd.svg',
  'docs/screenshots/01-login.png',
  'docs/screenshots/02-riley-dashboard.png',
  'docs/screenshots/03-equipment-fulfillment.png',
  'docs/screenshots/04-admin-analytics.png',
  'docs/social-preview.png'
];
const APPROVED_PUBLIC_DASH_PHRASES = [
  'Interactive Python demo — fixture-backed; not the PHP/MySQL runtime.'
];

const COPY_POLICIES = [
  {
    code: 'internal-wording',
    message: 'publication-process wording is not part of the public project narrative',
    pattern: /\b(?:agents?|agentic(?: workers?)?|owner[- ]approval|(?:publisher|publication|publishing|release) gate|gate status|recruiter(?:-facing)?|reviewers?(?:['’]s)?)\b/i
  },
  {
    code: 'hype',
    message: 'unsupported promotional wording must be replaced with a scoped claim',
    pattern: /\b(?:cutting-edge|industry-leading|production-ready|robust|seamless|state-of-the-art|transformative|unlock(?:s|ed|ing)?|proven|leveraged|utilized)\b/i
  },
  {
    code: 'filler',
    message: 'generic filler must be replaced with direct project language',
    pattern: /\b(?:delve|game-changer|this project demonstrates)\b|\bin today['’]s\b|\bi['’]m excited\b/i
  },
  {
    code: 'plain-language',
    message: 'use descriptive links, precise quantities, and portfolio-standard punctuation',
    pattern: /—|\b(?:click here|read more|several|various)\b/i
  }
];

function normalizeRelative(root, filePath) {
  return path.relative(root, filePath).split(path.sep).join('/');
}

function addFinding(findings, seen, code, file, message) {
  const key = `${code}\0${file}`;
  if (seen.has(key)) return;
  seen.add(key);
  findings.push({ code, file, message });
}

async function discoverFiles(root) {
  const files = [];

  async function walk(directory) {
    const entries = await readdir(directory, { withFileTypes: true });
    entries.sort((left, right) => left.name.localeCompare(right.name));

    for (const entry of entries) {
      if (SKIPPED_DIRECTORIES.has(entry.name)) continue;
      const filePath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        await walk(filePath);
      } else if (entry.isFile()) {
        files.push(filePath);
      }
    }
  }

  await walk(root);
  return files;
}

function looksLikeText(buffer) {
  if (buffer.length === 0) return true;
  const sample = buffer.subarray(0, Math.min(buffer.length, 8192));
  let suspiciousBytes = 0;

  for (const byte of sample) {
    if (byte === 0) return false;
    if (byte < 7 || (byte > 13 && byte < 32)) suspiciousBytes += 1;
  }

  return suspiciousBytes / sample.length < 0.02;
}

export function readPngDimensions(buffer) {
  if (buffer.length < 24 || !buffer.subarray(0, 8).equals(PNG_SIGNATURE)) {
    throw new Error('not a PNG file');
  }
  if (buffer.toString('ascii', 12, 16) !== 'IHDR') {
    throw new Error('PNG is missing its IHDR chunk');
  }

  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20)
  };
}

function markdownReferences(markdown) {
  const references = [];
  const pattern = /(!?)\[([^\]]*)\]\(([^)]+)\)/g;

  for (const match of markdown.matchAll(pattern)) {
    const rawDestination = match[3].trim();
    const destination = rawDestination.startsWith('<') && rawDestination.endsWith('>')
      ? rawDestination.slice(1, -1)
      : rawDestination.split(/\s+["']/u, 1)[0];
    references.push({ image: match[1] === '!', label: match[2], destination });
  }

  return references;
}

function githubHeadingSlug(heading) {
  return heading
    .normalize('NFC')
    .trim()
    .toLowerCase()
    .replace(/<[^>]+>/g, '')
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');
}

async function markdownHasAnchor(filePath, anchor) {
  const markdown = await readFile(filePath, 'utf8');
  const expected = githubHeadingSlug(decodeURIComponent(anchor));
  return markdown
    .split(/\r?\n/u)
    .filter((line) => /^#{1,6}\s+/u.test(line))
    .map((line) => githubHeadingSlug(line.replace(/^#{1,6}\s+/u, '')))
    .includes(expected);
}

async function exists(filePath) {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function inspectMarkdown(root, filePath, markdown, findings, seen) {
  const relativePath = normalizeRelative(root, filePath);

  for (const reference of markdownReferences(markdown)) {
    const destination = reference.destination;
    if (/^(?:https?:|mailto:|tel:)/iu.test(destination)) continue;

    const [rawTarget, rawAnchor = ''] = destination.split('#', 2);
    let decodedTarget;
    try {
      decodedTarget = decodeURIComponent(rawTarget);
    } catch {
      addFinding(findings, seen, 'broken-link', relativePath, `invalid URL encoding in ${destination}`);
      continue;
    }

    const targetPath = decodedTarget
      ? path.resolve(path.dirname(filePath), decodedTarget)
      : filePath;

    if (!targetPath.startsWith(`${root}${path.sep}`) && targetPath !== root) {
      addFinding(findings, seen, 'broken-link', relativePath, `local reference escapes the repository: ${destination}`);
      continue;
    }

    if (!(await exists(targetPath))) {
      addFinding(
        findings,
        seen,
        reference.image ? 'missing-image' : 'broken-link',
        relativePath,
        `local target does not exist: ${destination}`
      );
      continue;
    }

    if (rawAnchor && path.extname(targetPath).toLowerCase() === '.md') {
      try {
        if (!(await markdownHasAnchor(targetPath, rawAnchor))) {
          addFinding(findings, seen, 'broken-link', relativePath, `Markdown heading does not exist: ${destination}`);
        }
      } catch (error) {
        addFinding(findings, seen, 'broken-link', relativePath, `invalid URL encoding in ${destination}: ${error.message}`);
      }
    }

    if (!reference.image) continue;

    const extension = path.extname(targetPath).toLowerCase();
    try {
      if (extension === '.png') {
        readPngDimensions(await readFile(targetPath));
      } else if (extension === '.svg') {
        const svg = await readFile(targetPath, 'utf8');
        if (!/<svg(?:\s|>)/iu.test(svg)) throw new Error('missing SVG root');
      } else {
        addFinding(findings, seen, 'invalid-image', relativePath, `unsupported image type: ${destination}`);
      }
    } catch (error) {
      addFinding(findings, seen, 'invalid-image', relativePath, `${destination}: ${error.message}`);
    }
  }
}

function regexEscape(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

async function inspectVisualHashLedger(root, findings, seen) {
  let ledger;
  try {
    ledger = await readFile(path.join(root, 'docs/VISUAL_HASHES.md'), 'utf8');
  } catch (error) {
    addFinding(findings, seen, 'visual-hash', 'docs/VISUAL_HASHES.md', `visual hash ledger is missing: ${error.message}`);
    return;
  }

  const rows = [...ledger.matchAll(/^\| `([^`]+)` \| `([a-f0-9]{64})` \|$/gmu)];
  const entries = new Map(rows.map(([, relativePath, expectedHash]) => [relativePath, expectedHash]));
  if (rows.length !== VISUAL_ARTIFACTS.length || entries.size !== rows.length) {
    addFinding(findings, seen, 'visual-hash', 'docs/VISUAL_HASHES.md', 'visual hash ledger must contain one row for each required artifact');
  }

  for (const relativePath of VISUAL_ARTIFACTS) {
    const expectedHash = entries.get(relativePath);
    if (!expectedHash) {
      addFinding(findings, seen, 'visual-hash', 'docs/VISUAL_HASHES.md', `visual hash is missing for ${relativePath}`);
      continue;
    }
    try {
      const actualHash = sha256(await readFile(path.join(root, relativePath)));
      if (actualHash !== expectedHash) {
        addFinding(findings, seen, 'visual-hash', 'docs/VISUAL_HASHES.md', `${relativePath} hash does not match the checked-in artifact`);
      }
    } catch (error) {
      addFinding(findings, seen, 'visual-hash', 'docs/VISUAL_HASHES.md', `${relativePath} cannot be hashed: ${error.message}`);
    }
  }
}

async function runProjectChecks(root, findings, seen) {
  const readProjectFile = async (relativePath) => readFile(path.join(root, relativePath), 'utf8');

  await inspectVisualHashLedger(root, findings, seen);

  let schema;
  let erdSource;
  let erdSvg;
  try {
    [schema, erdSource, erdSvg] = await Promise.all([
      readProjectFile('sql/01_schema.sql'),
      readProjectFile('docs/erd.mmd'),
      readProjectFile('docs/erd.svg')
    ]);
  } catch (error) {
    addFinding(findings, seen, 'project-contract', '.', `schema or ERD artifact is missing: ${error.message}`);
    return;
  }

  if (/<foreignObject(?:\s|>)/iu.test(erdSvg)) {
    addFinding(findings, seen, 'erd-accessibility', 'docs/erd.svg', 'ERD must not use foreignObject labels');
  }
  for (const [pattern, label] of [
    [/<text(?:\s|>)/iu, 'native text nodes'],
    [/<title(?:\s|>)/iu, 'an accessible title'],
    [/<desc(?:\s|>)/iu, 'an accessible description']
  ]) {
    if (!pattern.test(erdSvg)) {
      addFinding(findings, seen, 'erd-accessibility', 'docs/erd.svg', `ERD must contain ${label}`);
    }
  }

  const tableNames = [...schema.matchAll(/^CREATE TABLE ([A-Za-z0-9_]+)/gmu)].map((match) => match[1]);
  const viewNames = [...schema.matchAll(/^CREATE VIEW ([A-Za-z0-9_]+)/gmu)].map((match) => match[1]);
  if (tableNames.length !== 14) {
    addFinding(findings, seen, 'schema-contract', 'sql/01_schema.sql', `expected 14 base tables, found ${tableNames.length}`);
  }
  if (viewNames.length !== 2) {
    addFinding(findings, seen, 'schema-contract', 'sql/01_schema.sql', `expected 2 views, found ${viewNames.length}`);
  }

  for (const objectName of [...tableNames, ...viewNames]) {
    const sourcePattern = new RegExp(`^\\s+${regexEscape(objectName)}\\s+\\{`, 'mu');
    const svgPattern = new RegExp(`>${regexEscape(objectName)}<`, 'u');
    if (!sourcePattern.test(erdSource) || !svgPattern.test(erdSvg)) {
      addFinding(findings, seen, 'erd-contract', 'docs/erd.mmd', `ERD is missing schema object ${objectName}`);
    }
  }

  try {
    const packageJson = JSON.parse(await readProjectFile('package.json'));
    const expected = {
      name: 'club-operations-system',
      version: '0.1.0',
      description: 'Local PHP/MySQL reference system for database integrity, role-aware workflows, concurrency tests, and reproducible fictional evidence.',
      license: 'MIT'
    };
    for (const [key, value] of Object.entries(expected)) {
      if (packageJson[key] !== value) {
        addFinding(findings, seen, 'package-contract', 'package.json', `${key} must equal ${JSON.stringify(value)}`);
      }
    }
    if (packageJson.private !== true) {
      addFinding(findings, seen, 'package-contract', 'package.json', 'private must be true to prevent accidental npm publication');
    }
    if (packageJson.repository?.url !== 'git+https://github.com/MahmmodAbuhani/club-operations-system.git') {
      addFinding(findings, seen, 'package-contract', 'package.json', 'repository URL is missing or inaccurate');
    }
    if (packageJson.engines?.node !== '>=22') {
      addFinding(findings, seen, 'package-contract', 'package.json', 'Node engine must be >=22');
    }
  } catch (error) {
    addFinding(findings, seen, 'package-contract', 'package.json', `package metadata is unreadable: ${error.message}`);
  }

  try {
    const verificationScript = await readProjectFile('scripts/verify.sh');
    if (/XAMPP/iu.test(verificationScript)) {
      addFinding(findings, seen, 'stale-tooling', 'scripts/verify.sh', 'verification contains the stale XAMPP fallback');
    }
  } catch (error) {
    addFinding(findings, seen, 'project-contract', 'scripts/verify.sh', `verification script is missing: ${error.message}`);
  }

  if (await exists(path.join(root, 'scripts/verify_database.sh'))) {
    addFinding(findings, seen, 'stale-tooling', 'scripts/verify_database.sh', 'dead database wrapper must not ship');
  }

  for (const relativePath of ['tests/e2e/accessibility.spec.js', 'tests/e2e/evidence.spec.js']) {
    try {
      const contents = await readProjectFile(relativePath);
      if (/test\([^)]*['"][^'"]*recruiter/iu.test(contents)) {
        addFinding(findings, seen, 'internal-wording', relativePath, 'test names must describe behavior, not an audience');
      }
    } catch (error) {
      addFinding(findings, seen, 'project-contract', relativePath, `required browser test is missing: ${error.message}`);
    }
  }
}

export async function scanRepository(repositoryRoot, options = {}) {
  const root = path.resolve(repositoryRoot);
  const findings = [];
  const seen = new Set();
  const files = await discoverFiles(root);

  for (const filePath of files) {
    const relativePath = normalizeRelative(root, filePath);
    const buffer = await readFile(filePath);
    if (!looksLikeText(buffer)) continue;

    const text = buffer.toString('utf8');
    if (/\/(?:Users|home)\/[A-Za-z0-9._-]+\//u.test(text) || /[A-Za-z]:\\Users\\[^\\\s]+\\/iu.test(text)) {
      addFinding(findings, seen, 'private-path', relativePath, 'absolute user-home path is not public-safe');
    }
    if (/\b[A-Z0-9._%+-]+@(?:[A-Z0-9-]+\.)+edu\b/iu.test(text)) {
      addFinding(findings, seen, 'institutional-email', relativePath, 'institutional email address is not approved for public contact');
    }

    if (PROSE_EXTENSIONS.has(path.extname(filePath).toLowerCase())) {
      for (const policy of COPY_POLICIES) {
        const policyText = policy.code === 'plain-language'
          ? APPROVED_PUBLIC_DASH_PHRASES.reduce((value, phrase) => value.replaceAll(phrase, ''), text)
          : text;
        if (policy.pattern.test(policyText)) {
          addFinding(findings, seen, policy.code, relativePath, policy.message);
        }
      }
    }

    if (path.extname(filePath).toLowerCase() === '.md') {
      await inspectMarkdown(root, filePath, text, findings, seen);
    }
  }

  if (options.projectChecks !== false) {
    await runProjectChecks(root, findings, seen);
  }

  return findings.sort((left, right) =>
    left.file.localeCompare(right.file) || left.code.localeCompare(right.code)
  );
}

async function main() {
  const root = path.resolve(process.argv[2] || process.cwd());
  const findings = await scanRepository(root);

  if (findings.length > 0) {
    for (const finding of findings) {
      console.error(`FAIL [${finding.code}] ${finding.file}: ${finding.message}`);
    }
    console.error(`Club Operations System public-surface checks failed: ${findings.length} finding(s).`);
    process.exitCode = 1;
    return;
  }

  console.log('Club Operations System public-surface checks passed.');
}

const entryPoint = process.argv[1] ? path.resolve(process.argv[1]) : '';
if (entryPoint === fileURLToPath(import.meta.url)) {
  await main();
}
