// Screenshots every render JSON in a directory.
//   node viz_test/shots_dir.mjs <dir> <outDir> [filter] [--at=ms] [--reduced]
import { mkdirSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { launch, openViz, render, messages } from './harness.mjs';

const [dir, out, ...rest] = process.argv.slice(2);
const filter = rest.find((a) => !a.startsWith('--')) || '';
const at = +(rest.find((a) => a.startsWith('--at=')) || '--at=4000').slice(5);
const reduced = rest.includes('--reduced');
mkdirSync(out, { recursive: true });
const browser = await launch();
for (const f of readdirSync(dir).filter((f) => f.endsWith('.json') && f.includes(filter)).sort()) {
  const payload = JSON.parse(readFileSync(join(dir, f), 'utf8'));
  const { page, errors } = await openViz(browser, { reducedMotion: reduced ? 'reduce' : 'no-preference' });
  await render(page, payload, { reduceMotion: reduced });
  await page.waitForTimeout(at);
  const file = join(out, f.replace('.json', `${reduced ? '-reduced' : ''}.png`));
  await page.screenshot({ path: file });
  const bad = (await messages(page)).filter((m) => m.type === 'error');
  console.log(f, errors.length || bad.length ? 'ERRORS ' + JSON.stringify([...errors, ...bad]) : 'ok');
  await page.close();
}
await browser.close();
