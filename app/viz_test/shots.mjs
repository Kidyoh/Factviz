// Renders every fixture and saves screenshots to viz_test/out.
//   node viz_test/shots.mjs [filter] [--at=ms] [--reduced]
import { mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { fixtures, launch, openViz, render, messages } from './harness.mjs';

const args = process.argv.slice(2);
const filter = args.find((a) => !a.startsWith('--')) || '';
const at = +(args.find((a) => a.startsWith('--at=')) || '--at=9000').slice(5);
const reduced = args.includes('--reduced');
const out = join(dirname(fileURLToPath(import.meta.url)), 'out');
mkdirSync(out, { recursive: true });

const browser = await launch();
for (const f of fixtures().filter((f) => f.name.includes(filter))) {
  const { page, errors } = await openViz(browser, { reducedMotion: reduced ? 'reduce' : 'no-preference' });
  await render(page, f.payload, { reduceMotion: reduced });
  await page.waitForTimeout(at);
  const file = join(out, `${f.name}${reduced ? '-reduced' : ''}-${at}.png`);
  await page.screenshot({ path: file });
  const bad = (await messages(page)).filter((m) => m.type === 'error');
  console.log(file, errors.length || bad.length ? 'ERRORS ' + JSON.stringify([...errors, ...bad]) : 'ok');
  await page.close();
}
await browser.close();
