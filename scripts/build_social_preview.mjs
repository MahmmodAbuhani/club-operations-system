#!/usr/bin/env node

import { readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourcePath = path.join(repositoryRoot, 'docs/screenshots/03-equipment-fulfillment.png');
const outputPath = path.join(repositoryRoot, 'docs/social-preview.png');
const sourceImage = (await readFile(sourcePath)).toString('base64');

const browser = await chromium.launch({ headless: true });

try {
  const page = await browser.newPage({
    viewport: { width: 1280, height: 640 },
    deviceScaleFactor: 1
  });

  await page.setContent(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <style>
      * { box-sizing: border-box; }
      html, body { margin: 0; width: 1280px; height: 640px; overflow: hidden; }
      body {
        background: #0a2532;
        color: #f8fafc;
        font-family: Arial, Helvetica, sans-serif;
      }
      .card {
        position: relative;
        display: grid;
        grid-template-columns: 1fr 1.04fr;
        gap: 48px;
        width: 1280px;
        height: 640px;
        padding: 54px 58px;
        background:
          radial-gradient(circle at 10% 10%, rgba(29, 122, 143, 0.24), transparent 34%),
          linear-gradient(135deg, #0a2532 0%, #103747 58%, #0b2936 100%);
      }
      .card::after {
        content: '';
        position: absolute;
        inset: 0;
        border: 1px solid rgba(255, 255, 255, 0.12);
        pointer-events: none;
      }
      .copy { display: flex; flex-direction: column; min-width: 0; }
      .eyebrow {
        color: #8fe3d0;
        font-size: 18px;
        font-weight: 700;
        letter-spacing: 0.14em;
        margin-bottom: 18px;
      }
      h1 { font-size: 60px; line-height: 0.96; letter-spacing: -0.04em; margin: 0 0 22px; }
      .lede { color: #d8e7ec; font-size: 25px; line-height: 1.35; margin: 0; max-width: 525px; }
      .proof { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 30px; }
      .proof div {
        border: 1px solid rgba(143, 227, 208, 0.3);
        border-radius: 10px;
        background: rgba(255, 255, 255, 0.06);
        padding: 13px 15px;
      }
      .proof strong { display: block; font-size: 20px; margin-bottom: 3px; }
      .proof span { color: #a9c2ca; font-size: 14px; }
      .stack { color: #a9c2ca; font-size: 16px; margin-top: auto; }
      .visual {
        position: relative;
        align-self: center;
        height: 530px;
        border: 1px solid rgba(255, 255, 255, 0.18);
        border-radius: 18px;
        background: #f6f7f9;
        box-shadow: 0 24px 64px rgba(0, 0, 0, 0.35);
        overflow: hidden;
      }
      .visual img { width: 100%; height: 100%; object-fit: cover; object-position: 50% 0; display: block; }
      .label {
        position: absolute;
        top: 18px;
        right: 18px;
        border-radius: 999px;
        background: rgba(10, 37, 50, 0.93);
        color: #e7f8f3;
        font-size: 13px;
        font-weight: 700;
        letter-spacing: 0.08em;
        padding: 9px 12px;
      }
    </style>
  </head>
  <body>
    <main class="card" aria-label="Club Operations System social preview">
      <section class="copy">
        <div class="eyebrow">LOCAL DATA SYSTEM · FICTIONAL FIXTURE</div>
        <h1>Club Operations System</h1>
        <p class="lede">I built a PHP and MySQL system that makes registration, roster, staffing, and equipment rules executable.</p>
        <div class="proof">
          <div><strong>14 tables + 2 views</strong><span>Reconciled relational model</span></div>
          <div><strong>Synchronized races</strong><span>One valid winner under contention</span></div>
          <div><strong>Role-based HTTP flows</strong><span>Denied writes preserve state</span></div>
          <div><strong>Reproducible evidence</strong><span>Docker, SQL, and Playwright</span></div>
        </div>
        <div class="stack">PHP 8.3 / MySQL 8.0 / Docker Compose / Playwright</div>
      </section>
      <section class="visual" aria-label="Fictional equipment fulfillment interface capture">
        <img alt="" src="data:image/png;base64,${sourceImage}">
        <div class="label">AUTHENTIC FIXTURE CAPTURE</div>
      </section>
    </main>
  </body>
</html>`, { waitUntil: 'load' });

  await page.waitForFunction(() => document.querySelector('img')?.complete === true);
  await page.screenshot({ path: outputPath, type: 'png' });
} finally {
  await browser.close();
}

process.stdout.write(`Wrote ${path.relative(repositoryRoot, outputPath)} from ${path.relative(repositoryRoot, sourcePath)}.\n`);
