// Tests for the D3 renderer (assets/viz), run in headless Chromium.
//   cd app/viz_test && npm install && npm test
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { fixtures, launch, openViz, render, messages } from './harness.mjs';

let browser;
before(async () => { browser = await launch(); });
after(async () => { await browser.close(); });

const all = fixtures();

/** Annotation texts, with wrapped lines joined by spaces. */
const notes = (page) => page.evaluate(() => [...document.querySelectorAll('.annotation-note-label')]
  .map((t) => [...t.querySelectorAll('tspan')].map((s) => s.textContent).join(' ') || t.textContent).join(' | '));
const byName = (n) => all.find((f) => f.name === n).payload;

async function rendered(payload, opts = {}) {
  const { page, errors } = await openViz(browser, { reducedMotion: opts.reduce ? 'reduce' : 'no-preference' });
  await render(page, payload, { reduceMotion: !!opts.reduce });
  return { page, errors };
}

test('every fixture renders without errors, animated and reduced', async () => {
  for (const f of all) {
    for (const reduce of [false, true]) {
      const { page, errors } = await rendered(f.payload, { reduce });
      await page.waitForTimeout(reduce ? 150 : 1200);
      const msgs = await messages(page);
      assert.deepEqual(errors, [], `${f.name}: page errors`);
      assert.ok(msgs.some((m) => m.type === 'rendered'), `${f.name}: rendered`);
      assert.ok(!msgs.some((m) => m.type === 'error'), `${f.name}: ${JSON.stringify(msgs)}`);
      await page.close();
    }
  }
});

test('reports unknown templates instead of throwing', async () => {
  const { page } = await rendered({ template: 'pie', annotations: [] });
  const msgs = await messages(page);
  assert.ok(msgs.find((m) => m.type === 'error'));
  assert.match(await page.textContent('.error'), /couldn't be drawn/);
  await page.close();
});

test('number formatting matches the app', async () => {
  const { page } = await rendered(byName('query_process_water_cycle'), { reduce: true });
  const out = await page.evaluate(() => [42, 384400, 4.5e9, 1.2e6, 4.398e15, 1e-6, 0.1, 3.14159, 0].map((v) => FactvizViz.fmtNumber(v)));
  assert.deepEqual(out, ['42', '384,400', '4.5 billion', '1.2 million', '4.4 × 10¹⁵', '1 × 10⁻⁶', '0.1', '3.14', '0']);
  const si = await page.evaluate(() => FactvizViz.fmtSi(3.844e8, { ladder: [{ symbol: 'm', toSi: 1 }, { symbol: 'km', toSi: 1000 }] }));
  assert.equal(si, '384,400 km');
  await page.close();
});

test('scale_zoom: zooms to the largest item, labels it, and annotates', async () => {
  const p = byName('query_scale_zoom_planets');
  const { page } = await rendered(p, { reduce: true });
  assert.equal(await page.textContent('.status'), `8 of 8 · Jupiter`);
  assert.equal(await page.locator('g.item').count(), 8);
  assert.equal(await page.locator('g.item image').count(), 8, 'NASA photos for every planet');
  const labels = await page.locator('g.lbl[opacity="1"] .label-value').allTextContents();
  assert.ok(labels.includes('142,984 km'));
  assert.match(await notes(page), /Jupiter is 29× as wide as Mercury/);
  // Stepping back moves the camera and hides the annotation.
  await page.click('button[aria-label="Previous item"]');
  await page.waitForTimeout(100);
  assert.equal(await page.textContent('.status'), '7 of 8 · Saturn');
  assert.equal(await page.locator('.annotation-group .annotation').count(), 0);
  await page.close();
});

test('scale_zoom: silhouettes for animals and vehicles', async () => {
  const p = byName('mock_00_scale_zoom');
  const { page } = await rendered(p, { reduce: true });
  assert.ok(await page.locator('g.item .sil-inner').count() >= 3);
  await page.close();
});

test('scale_zoom: animated camera reaches the end', async () => {
  const { page } = await rendered(byName('mock_00_scale_zoom'));
  await page.waitForFunction(() => document.querySelector('.status').textContent.startsWith('3 of 3'), null, { timeout: 8000 });
  await page.close();
});

test('timeline: plots every event and shows details on tap', async () => {
  const p = byName('query_timeline_spaceflight');
  const { page } = await rendered(p, { reduce: true });
  assert.equal(await page.locator('g.event').count(), p.events.length);
  await page.locator('g.event').first().dispatchEvent('click');
  assert.equal(await page.textContent('.detail .title'), 'Sputnik 1 launched');
  assert.match(await page.textContent('.detail .desc'), /First artificial satellite/);
  assert.match(await notes(page), /63 years from first to last/);
  await page.close();
});

test('timeline: log axis for deep time', async () => {
  const { page } = await rendered(byName('mock_03_timeline'), { reduce: true });
  const ticks = await page.locator('.axis .tick text').allTextContents();
  assert.ok(ticks.some((t) => /yrs ago/.test(t)), ticks.join('|'));
  await page.close();
});

test('exponential_growth: readout, annotations and the log toggle', async () => {
  const p = byName('query_exponential_paper_fold');
  const { page } = await rendered(p, { reduce: true });
  assert.equal(await page.textContent('.readout .step'), 'Fold 42 of 42');
  assert.equal(await page.textContent('.readout .value'), '439,805 km');
  const text = await notes(page);
  assert.match(text, /Fold 36: still only 6,872 km/);
  assert.match(text, /Fold 42: Average Earth–Moon distance reached/);
  assert.equal(await page.getAttribute('.seg button:nth-child(2)', 'aria-pressed'), 'true', 'starts on log per plan');
  await page.click('.seg button:nth-child(1)');
  await page.waitForTimeout(50);
  assert.equal(await page.getAttribute('.seg button:nth-child(1)', 'aria-pressed'), 'true');
  const ticks = await page.locator('.axis text').allTextContents();
  assert.ok(ticks.some((t) => /km$/.test(t)), ticks.join('|'));
  // Step back one fold.
  await page.click('button[aria-label="Previous fold"]');
  assert.equal(await page.textContent('.readout .step'), 'Fold 41 of 42');
  await page.close();
});

test('exponential_growth: plays and sends a haptic when the target is reached', async () => {
  const { page } = await rendered(byName('query_exponential_paper_fold'));
  await page.waitForFunction(() => document.querySelector('.readout .step').textContent === 'Fold 42 of 42', null, { timeout: 12000 });
  const msgs = await messages(page);
  assert.equal(msgs.filter((m) => m.type === 'haptic').length, 1);
  await page.close();
});

test('comparison_bars: every bar with its display value and annotation', async () => {
  const p = byName('query_comparison_whale_bus');
  const { page } = await rendered(p, { reduce: true });
  assert.equal(await page.locator('g.row rect').count(), 3);
  const values = await page.locator('g.row .label-value').allTextContents();
  assert.deepEqual(values, ['~150 t', '~11 t', '~6 t']);
  assert.match(await notes(page), /Blue whale weighs 25× as much as African elephant/);
  const ticks = await page.locator('.axis text').allTextContents();
  assert.ok(ticks.every((t) => t.endsWith(' t')), `one unit across the axis: ${ticks}`);
  await page.close();
});

test('comparison_bars: vertical columns', async () => {
  const { page } = await rendered(byName('mock_08_comparison_bars'), { reduce: true });
  assert.equal(await page.locator('g.col rect').count(), 4);
  assert.match(await notes(page), /as tall as/);
  await page.close();
});

test('process_steps: autoplays, and stepping works', async () => {
  const p = byName('query_process_water_cycle');
  const { page } = await rendered(p);
  assert.equal(await page.textContent('.status'), 'Step 1 of 4');
  await page.waitForFunction(() => document.querySelector('.status').textContent === 'Step 2 of 4', null, { timeout: p.autoplayMs + 2000 });
  await page.click('button[aria-label="Pause"]');
  await page.click('button[aria-label="Next step"]');
  assert.equal(await page.textContent('.status'), 'Step 3 of 4');
  assert.equal(await page.textContent('.step-panel h3'), 'Precipitation');
  await page.close();
});

test('process_steps: no autoplay with reduced motion; linear list', async () => {
  const { page } = await rendered(byName('mock_10_process_steps'), { reduce: true });
  await page.waitForTimeout(500);
  assert.equal(await page.textContent('.status'), 'Step 1 of 5');
  assert.ok(await page.locator('button[aria-label="Play"]').count());
  assert.equal(await page.locator('.step-list li').count(), 5);
  await page.close();
});
