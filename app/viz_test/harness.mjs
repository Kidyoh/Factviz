// Loads the D3 renderer in headless Chromium, as the app's WebView does.
import { chromium } from 'playwright-core';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const pageUrl = pathToFileURL(join(here, '..', 'assets', 'viz', 'index.html')).href;
export const fixturesDir = join(here, 'fixtures');

export function fixtures() {
  return readdirSync(fixturesDir).filter((f) => f.endsWith('.json')).sort()
    .map((f) => ({ name: f.replace('.json', ''), payload: JSON.parse(readFileSync(join(fixturesDir, f), 'utf8')) }));
}

export async function launch() {
  return chromium.launch({ executablePath: process.env.CHROMIUM || '/opt/pw-browsers/chromium' });
}

/** Opens the renderer at a phone chart size and records bridge messages and errors. */
export async function openViz(browser, { width = 358, height = 460, reducedMotion = 'no-preference' } = {}) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 2, reducedMotion });
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.addInitScript(() => {
    window.__messages = [];
    window.FactvizBridge = { postMessage: (m) => window.__messages.push(JSON.parse(m)) };
  });
  await page.goto(pageUrl);
  await page.waitForFunction(() => window.FactvizViz && document.fonts.status === 'loaded');
  return { page, errors };
}

export async function render(page, payload, options = {}) {
  await page.evaluate(([p, o]) => window.FactvizViz.render(p, o), [payload, options]);
}

export const messages = (page) => page.evaluate(() => window.__messages);
