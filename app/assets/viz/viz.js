/*
 * Explain It Visually: D3 renderer.
 *
 * Receives validated, resolved template JSON from the app (see
 * factviz_core/lib/src/templates/render_json.dart) and draws it. Every
 * figure shown comes precomputed from the app; this file only lays out,
 * scales and animates. It never invents a number.
 *
 * API: window.FactvizViz.render(payload, {reduceMotion}), .replay()
 * Events to the app via the FactvizBridge JavaScript channel.
 */
(function () {
  'use strict';

  // A restrained editorial palette: one warm accent, then quiet companions.
  const PALETTE = ['#C8553D', '#2A6F97', '#D9A441', '#3D7A5C', '#8E5572', '#5B6C8F', '#A97C5B', '#6E6A64'];
  const INK = '#171717', INK2 = '#4E4B47', INK3 = '#8C877F', RULE = '#DAD3C5', PAPER = '#F7F4EE', ACCENT = '#C8553D';

  const state = { payload: null, options: {}, stops: [] };
  const root = d3.select('#viz');

  function post(msg) {
    try {
      if (window.FactvizBridge) window.FactvizBridge.postMessage(JSON.stringify(msg));
    } catch (_) { /* no bridge in previews */ }
  }

  // ---------------------------------------------------------------------
  // Formatting: mirrors factviz_core's format.dart for axis ticks. Values
  // shown as labels always use the app's own display strings.

  const SUP = { '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻' };
  const sup = (n) => String(n).split('').map((c) => SUP[c]).join('');
  const trim = (s) => (s.indexOf('.') < 0 ? s : s.replace(/0+$/, '').replace(/\.$/, ''));
  const group = (n) => Math.round(n).toLocaleString('en-US');

  function sig(v, digits) {
    if (v === 0) return '0';
    const d = Math.floor(Math.log10(v)) + 1;
    return v.toFixed(Math.max(0, Math.min(6, digits - d)));
  }

  function fmtNumber(value, significant = 3) {
    if (!isFinite(value)) return value > 0 ? '∞' : '—';
    if (value === 0) return '0';
    const sign = value < 0 ? '-' : '';
    const v = Math.abs(value);
    if (v >= 1e15 || v < 1e-3) {
      const e = Math.floor(Math.log10(v));
      const m = trim((v / Math.pow(10, e)).toFixed(significant - 1));
      return m === '10' ? `${sign}1 × 10${sup(e + 1)}` : `${sign}${m} × 10${sup(e)}`;
    }
    for (const [scale, word] of [[1e12, 'trillion'], [1e9, 'billion'], [1e6, 'million']]) {
      if (v >= scale) return `${sign}${trim(sig(v / scale, significant))} ${word}`;
    }
    if (v === Math.round(v)) return sign + group(v);
    const s = sig(v, significant).split('.');
    return sign + trim(group(+s[0]) + (s[1] ? '.' + s[1] : ''));
  }

  /** Formats a base-unit value in the most readable unit of the ladder. */
  function fmtSi(si, units) {
    const ladder = units.ladder;
    let best = ladder[0];
    for (const u of ladder) if (Math.abs(si) / u.toSi >= 1) best = u;
    if (si === 0) best = ladder.find((u) => u.toSi === 1) || ladder[0];
    const n = fmtNumber(si / best.toSi);
    if (!best.symbol) return n;
    if (best.symbol === '×') return n + '×';
    return `${n} ${best.symbol}`;
  }

  /** Formatter for an axis: every tick uses the unit that suits `ref`. */
  function axisFormatter(units, ref) {
    const ladder = units.ladder;
    let best = ladder[0];
    for (const u of ladder) if (Math.abs(ref) / u.toSi >= 1) best = u;
    return (v) => {
      const n = fmtNumber(v / best.toSi);
      if (!best.symbol) return n;
      return best.symbol === '×' ? n + '×' : `${n} ${best.symbol}`;
    };
  }

  /**
   * The unit an axis should count in: the facts' own unit when values read
   * well in it (1 to 99,999), otherwise the best rung of the ladder.
   */
  function pickUnit(units, ref) {
    const pref = units.preferred;
    if (pref && ref / pref.toSi >= 1 && ref / pref.toSi < 1e5) return pref;
    let best = units.ladder[0];
    for (const u of units.ladder) if (Math.abs(ref) / u.toSi >= 1) best = u;
    return best;
  }

  const unitFmt = (u) => (v) => {
    const n = fmtNumber(v / u.toSi);
    if (!u.symbol) return n;
    if (u.symbol === '×') return n + '×';
    if (u.symbol === '%') return n + '%';
    return `${n} ${u.symbol}`;
  };

  /**
   * A linear axis whose ticks are round numbers in the display unit. Starts
   * at zero unless `fromZero` is false and the values sit far above it.
   */
  function unitAxis(units, lo, hi, count = 4, fromZero = true) {
    const u = pickUnit(units, hi);
    const a = fromZero || lo < hi * 0.4 ? 0 : lo / u.toSi, b = hi / u.toSi;
    const t = d3.ticks(a, b, count);
    const step = t.length > 1 ? t[1] - t[0] : (b - a) || b || 1;
    const start = Math.floor(a / step + 1e-9) * step;
    const end = Math.ceil(b / step - 1e-9) * step || step;
    const ticks = d3.range(start, end + step / 2, step).map((v) => v * u.toSi);
    return { min: start * u.toSi, max: end * u.toSi, ticks, fmt: unitFmt(u) };
  }

  /**
   * Log-axis ticks. Metric ladders take powers of ten in the base unit, each
   * shown in its best unit (1 cm, 10 km); other units (years, km/h) take
   * powers of ten in one display unit, so ticks read 1, 10, 100 years.
   */
  function logAxis(units, lo, hi, max = 6) {
    const metric = ['length', 'mass', 'area', 'volume'].includes(units.dimension);
    const u = metric ? { symbol: '', toSi: 1 } : pickUnit(units, Math.sqrt(lo * hi));
    const a = Math.floor(Math.log10(lo / u.toSi)), b = Math.ceil(Math.log10(hi / u.toSi));
    const stepE = Math.max(1, Math.ceil((b - a) / max));
    const ticks = [];
    for (let e = a; e <= b; e += stepE) {
      const v = Math.pow(10, e) * u.toSi;
      if (v >= lo * 0.999 && v <= hi * 1.001) ticks.push(v);
    }
    return { ticks, fmt: metric ? (v) => fmtSi(v, units) : unitFmt(u) };
  }

  /** 1, 2 or 5 × 10ⁿ near v. */
  function niceNum(v) {
    if (!(v > 0)) return 0;
    const e = Math.floor(Math.log10(v));
    const b = Math.pow(10, e);
    const f = v / b;
    return (f < 1.5 ? 1 : f < 3.5 ? 2 : f < 7.5 ? 5 : 10) * b;
  }

  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const reduce = () => !!state.options.reduceMotion ||
    (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  const dur = (ms) => (reduce() ? 0 : ms);

  // Things to stop when re-rendering (timers, intervals).
  function track(stoppable) { state.stops.push(stoppable); return stoppable; }
  function teardown() {
    state.stops.forEach((s) => { try { s.stop(); } catch (_) { /* already stopped */ } });
    state.stops = [];
    root.selectAll('*').interrupt();
  }

  const ICONS = {
    play: '<svg viewBox="0 0 16 16"><path d="M4 2.5v11l9-5.5z"/></svg>',
    pause: '<svg viewBox="0 0 16 16"><path d="M4 2.5h3v11H4zM9 2.5h3v11H9z"/></svg>',
    prev: '<svg viewBox="0 0 16 16"><path d="M10.5 2.5 4.5 8l6 5.5z"/></svg>',
    next: '<svg viewBox="0 0 16 16"><path d="M5.5 2.5 11.5 8l-6 5.5z"/></svg>',
  };

  function button(parent, icon, label, onClick, cls) {
    return parent.append('button').attr('class', 'btn' + (cls ? ' ' + cls : ''))
      .attr('aria-label', label).html(ICONS[icon] || icon).on('click', onClick);
  }

  /**
   * Creates the stage, lets `build` add surrounding blocks (controls,
   * readouts), then measures the stage so charts get their real size.
   */
  function layout(build) {
    const stage = root.append('div').attr('class', 'stage');
    const extra = build ? build(stage) : {};
    const svg = stage.append('svg').attr('role', 'img');
    return Object.assign({ stage, svg, w: stage.node().clientWidth, h: stage.node().clientHeight }, extra);
  }

  /** Width of `text` in the given CSS class, measured in the live SVG. */
  function textWidth(svg, text, cls) {
    const t = svg.append('text').attr('class', cls).attr('opacity', 0).text(text);
    const w = t.node().getComputedTextLength();
    t.remove();
    return w;
  }

  /** Draws a silhouette from silhouettes.js into box (x, y, w, h). */
  function silhouette(sel, key, color) {
    const s = window.FactvizSilhouettes[key];
    if (!s) return null;
    const g = sel.append('g').attr('fill', color);
    g.append('g').attr('class', 'sil-inner').html(s.markup);
    return { g, box: s.box };
  }

  function placeSilhouette(node, box, x, y, w, h) {
    d3.select(node).attr('transform',
      `translate(${x},${y}) scale(${w / box[2]},${h / box[3]}) translate(${-box[0]},${-box[1]})`);
  }

  /**
   * Adds d3-svg-annotation callouts. `points[i]` is the anchor {x, y} for
   * annotation i (null hides it). Each note tries several positions and
   * takes the one that overlaps least with `obstacles` (rects {x0,y0,x1,y1})
   * while staying inside `bounds`.
   */
  function annotate(layer, annotations, points, bounds, obstacles = [], opts = {}) {
    layer.selectAll('*').remove();
    const svg = d3.select(layer.node().ownerSVGElement);
    const taken = obstacles.slice();
    const list = [];
    annotations.forEach((a, i) => {
      const p = points[i];
      if (!p) return;
      const wrap = Math.min(opts.wrap || 150, bounds.w * 0.5);
      const lines = Math.max(1, Math.ceil(textWidth(svg, a.text, 'annotation-note-label') / (wrap - 6)));
      const nh = lines * 17 + 4;
      const candidates = [];
      for (const dist of [36, 64, 100]) {
        for (const [sx, sy] of [[1, -1], [-1, -1], [1, 1], [-1, 1], [0, -1.4], [0, 1.4]]) {
          candidates.push([sx * dist * 0.8, sy * dist]);
        }
      }
      let best = null;
      for (const [dx0, dy] of candidates) {
        const right = dx0 >= 0;
        let dx = dx0;
        let x0 = right ? p.x + dx : p.x + dx - wrap;
        // Slide horizontally to stay in bounds.
        if (x0 < bounds.x) { dx += bounds.x - x0; x0 = bounds.x; }
        if (x0 + wrap > bounds.x + bounds.w) { dx -= x0 + wrap - (bounds.x + bounds.w); x0 = bounds.x + bounds.w - wrap; }
        const y0 = dy < 0 ? p.y + dy - nh : p.y + dy;
        const rect = { x0, y0, x1: x0 + wrap, y1: y0 + nh };
        let cost = Math.abs(dy) * 0.4;
        if (rect.y0 < bounds.y) cost += (bounds.y - rect.y0) * 40;
        if (rect.y1 > bounds.y + bounds.h) cost += (rect.y1 - bounds.y - bounds.h) * 40;
        for (const o of taken) {
          const ox = Math.max(0, Math.min(rect.x1, o.x1) - Math.max(rect.x0, o.x0));
          const oy = Math.max(0, Math.min(rect.y1, o.y1) - Math.max(rect.y0, o.y0));
          cost += ox * oy * (o.w || 1);
        }
        if (!best || cost < best.cost) best = { cost, dx, dy, rect, right };
      }
      taken.push(best.rect);
      list.push({
        x: p.x, y: p.y, dx: best.dx, dy: best.dy,
        note: { label: a.text, wrap, align: best.right ? 'left' : 'right', padding: 4, bgPadding: 3 },
        connector: { end: 'dot' },
      });
    });
    if (!list.length) return;
    layer.call(d3.annotation().type(d3.annotationCallout).annotations(list));
  }

  // ---------------------------------------------------------------------
  // scale_zoom: things side by side (or distances from a start) to scale,
  // with a log-space camera that zooms out item by item.

  /** Springy growth: overshoots a little, then settles at full size. */
  const growEase = (t) => (t <= 0 ? 0 : t >= 1 ? 1 : d3.easeBackOut.overshoot(1.4)(t));

  function drawnSize(item) {
    const s = item.linearSi;
    const img = item.image;
    if (img && img.kind === 'photo') {
      const w = s / img.disc;
      return { w, h: w / img.aspect, bodyH: s };
    }
    if (img && img.kind === 'silhouette') {
      return item.shape === 'tower' ? { w: s * img.aspect, h: s, bodyH: s } : { w: s, h: s / img.aspect, bodyH: s / img.aspect };
    }
    if (item.shape === 'bar') return { w: s, h: s * 0.28, bodyH: s * 0.28 };
    if (item.shape === 'tower') return { w: s * 0.28, h: s, bodyH: s };
    return { w: s, h: s, bodyH: s };
  }

  function renderScale(p) {
    const n = p.items.length;
    const distance = p.mode === 'distance';
    const { svg, w: W, h: H, controls } = layout(() => ({ controls: root.append('div').attr('class', 'controls') }));
    const m = { l: 18, r: 18, t: 22, b: 40 };
    const iw = W - m.l - m.r, ih = H - m.t - m.b;
    const baseY = m.t + ih;
    svg.attr('aria-label', `${p.title}. ${p.items.map((d) => `${d.name}: ${d.display}`).join('; ')}`);

    // World layout (base units).
    let cursor = 0;
    const items = p.items.map((it, i) => {
      const size = drawnSize(it);
      const x = distance ? it.linearSi : cursor;
      if (!distance) cursor += size.w + 0.22 * Math.max(size.w, size.h);
      return Object.assign({}, it, size, { i, x, color: PALETTE[i % PALETTE.length] });
    });

    // Camera stops: world width that frames item i and everything before it.
    const aspect = iw / ih;
    const stops = [];
    items.forEach((it, i) => {
      let w;
      if (distance) w = it.x * (i === 0 ? 1.7 : 1.12);
      else if (i === 0) w = Math.max(it.w / 0.34, it.h * aspect / 0.5);
      else w = Math.max((it.x + it.w) * 1.06, it.h * aspect / 0.66);
      stops.push(Math.max(w, stops.length ? stops[stops.length - 1] : 0));
    });
    const ease = d3.easeCubicInOut;
    const worldAt = (pr) => {
      if (n === 1) return stops[0];
      const q = clamp(pr, 0, n - 1);
      const i = Math.min(Math.floor(q), n - 2);
      const t = ease(q - i);
      return Math.exp(Math.log(stops[i]) * (1 - t) + Math.log(stops[i + 1]) * t);
    };

    // The scene: a starfield for planets and moons, a sky and ground for
    // things on Earth, so the comparison reads as a place, not a chart.
    const space = !distance && items.every((d) => d.image && d.image.kind === 'photo');
    const heights = !distance && items.some((d) => d.shape === 'tower');
    const defs = svg.append('defs');
    if (space) {
      svg.classed('dark-scene', true);
      svg.append('rect').attr('width', W).attr('height', H).attr('fill', '#0E1320');
      const rnd = d3.randomLcg(7);
      svg.append('g').selectAll('circle').data(d3.range(Math.round(W * H / 2600))).join('circle')
        .attr('cx', () => rnd() * W).attr('cy', () => rnd() * H).attr('r', () => 0.3 + rnd() * 0.9)
        .attr('fill', '#fff').attr('opacity', () => 0.25 + rnd() * 0.6);
    } else if (!distance) {
      const sky = defs.append('linearGradient').attr('id', 'sky').attr('x1', 0).attr('x2', 0).attr('y1', 0).attr('y2', 1);
      sky.append('stop').attr('offset', 0).attr('stop-color', '#E4EDF1');
      sky.append('stop').attr('offset', 1).attr('stop-color', PAPER);
      svg.append('rect').attr('width', W).attr('height', baseY).attr('fill', 'url(#sky)');
      svg.append('rect').attr('y', baseY).attr('width', W).attr('height', H - baseY).attr('fill', '#ECE5D7');
    }
    const gGrid = svg.append('g').attr('class', 'lineup');
    const gShadows = svg.append('g');
    const gGround = svg.append('g');
    gGround.append('line').attr('class', 'baseline').attr('x1', 0).attr('x2', W).attr('y1', baseY).attr('y2', baseY);
    if (distance) {
      gGround.append('circle').attr('cx', m.l).attr('cy', baseY).attr('r', 3.5).attr('fill', INK);
      gGround.append('text').attr('class', 'label-faint').attr('x', m.l).attr('y', baseY + 16).text('START');
    }
    const gItems = svg.append('g');
    const gLabels = svg.append('g');
    const gScale = svg.append('g').attr('transform', `translate(${m.l},${H - 18})`);
    const gNote = svg.append('g').attr('class', 'annotation-group');

    const shadows = gShadows.selectAll('ellipse').data(distance ? [] : items).join('ellipse')
      .attr('fill', space ? '#000' : INK).attr('opacity', space ? 0 : 0.1);
    // Measuring tape beside the focused figure (heights only).
    const tape = svg.append('g').attr('class', 'tape').attr('opacity', 0);
    tape.append('line').attr('stroke', ACCENT).attr('stroke-width', 1.5);
    tape.append('path').attr('class', 'cap-top').attr('fill', ACCENT).attr('d', 'M-4,5L0,0L4,5Z');
    tape.append('path').attr('class', 'cap-bottom').attr('fill', ACCENT).attr('d', 'M-4,-5L0,0L4,-5Z');

    // Item marks.
    const marks = gItems.selectAll('g.item').data(items).join('g').attr('class', 'item');
    marks.each(function (d) {
      const g = d3.select(this);
      if (distance) {
        g.append('line').attr('class', 'stem').attr('stroke', INK2).attr('stroke-width', 1);
        if (d.image && d.image.kind === 'photo') {
          g.append('image').attr('href', d.image.src).attr('width', 22).attr('height', 22 / d.image.aspect);
        } else {
          g.append('circle').attr('r', 5).attr('fill', d.color);
        }
        return;
      }
      if (d.image && d.image.kind === 'photo') {
        g.append('image').attr('href', d.image.src).attr('preserveAspectRatio', 'none');
      } else if (d.image) {
        d.sil = silhouette(g, d.image.key, d.color);
      } else if (d.shape === 'circle') {
        g.append('circle').attr('fill', d.color);
      } else {
        g.append('rect').attr('fill', d.color);
      }
      // A tick under the baseline so microscopic items are still findable.
      g.append('path').attr('class', 'tick').attr('d', 'M0,0l-4,7h8z').attr('fill', d.color);
    });

    // Labels, measured once.
    const labels = gLabels.selectAll('g.lbl').data(items).join('g').attr('class', 'lbl');
    labels.append('line').attr('class', 'leader').attr('stroke', INK3).attr('stroke-width', 0.75);
    labels.append('text').attr('class', 'label-name halo').attr('text-anchor', 'middle').text((d) => d.name);
    labels.append('text').attr('class', 'label-value halo').attr('text-anchor', 'middle').attr('dy', '1.25em').text((d) => d.display);
    labels.each(function (d) {
      const b = this.getBBox();
      d.lw = b.width; d.lh = b.height;
    });

    let progress = 0;
    function draw(pr) {
      progress = pr;
      const world = worldAt(pr);
      const k = iw / world;
      const focus = Math.round(clamp(pr, 0, n - 1));
      const placed = [];
      items.forEach((d) => {
        // Each item arrives as the camera moves toward it (item 0 during the
        // intro, from progress -1 to 0) and grows up out of the ground.
        d.op = clamp(pr - (d.i - 1), 0, 1);
        d.gr = distance ? 1 : growEase(d.op);
        d.px = m.l + d.x * k;
        d.pw = d.w * k;
        d.ph = d.h * k;
      });

      marks.attr('opacity', (d) => Math.min(1, d.op * 3)).each(function (d) {
        const g = d3.select(this);
        if (distance) {
          g.select('.stem').attr('x1', d.px).attr('x2', d.px).attr('y1', baseY).attr('y2', baseY - 26);
          g.select('circle').attr('cx', d.px).attr('cy', baseY);
          g.select('image').attr('x', d.px - 11).attr('y', baseY - 11 / (d.image ? d.image.aspect : 1));
          return;
        }
        // Skip marks that are off-screen or absurdly large at this zoom: the
        // browser would otherwise rasterise paths millions of pixels wide.
        const off = d.px > W + 20 || d.pw > W * 40 || d.ph > H * 40;
        g.attr('display', off ? 'none' : null);
        if (off) return;
        // Grow from the ground, centred on the item's final footprint.
        const gw = Math.max(d.pw * d.gr, 0.5), gh = Math.max(d.ph * d.gr, 0.5);
        const x = d.px + (d.pw - gw) / 2, y = baseY - gh;
        g.select('image').attr('x', x).attr('y', y).attr('width', gw).attr('height', gh);
        if (d.sil) placeSilhouette(d.sil.g.node(), d.sil.box, x, y, gw, gh);
        g.select('circle').attr('cx', d.px + d.pw / 2).attr('cy', baseY - gw / 2).attr('r', Math.max(gw / 2, 0.4));
        g.select('rect').attr('x', x).attr('y', y).attr('width', gw).attr('height', gh).attr('rx', Math.min(3, gw * 0.08));
        g.select('.tick').attr('transform', `translate(${d.px + d.pw / 2},${baseY + 3})`).attr('opacity', d.pw < 6 ? 1 : 0);
      });

      shadows.attr('display', (d) => (d.px > W + 20 || d.pw > W * 40 ? 'none' : null))
        .attr('cx', (d) => d.px + d.pw / 2).attr('cy', baseY + 1)
        .attr('rx', (d) => Math.max(0, d.pw * 0.48 * d.gr)).attr('ry', (d) => clamp(d.pw * 0.05, 1, 5) * d.gr);

      // Height lineup: round heights in the facts' unit, like a police lineup.
      if (heights) {
        const visible = (ih - 10) / k;
        const u = pickUnit(p.units, visible / 4);
        const step = niceNum(visible / 4 / u.toSi) * u.toSi;
        const levels = d3.range(step, visible, step).slice(0, 8);
        const rows = gGrid.selectAll('g').data(levels).join((e) => {
          const g = e.append('g');
          g.append('line').attr('stroke', '#C9D3D6').attr('stroke-dasharray', '3 4');
          g.append('text').attr('class', 'label-faint halo').attr('dy', '-0.3em');
          return g;
        });
        rows.attr('transform', (v) => `translate(0,${baseY - v * k})`);
        rows.select('line').attr('x1', 0).attr('x2', W);
        rows.select('text').attr('x', 6).text((v) => unitFmt(u)(v));
      }

      // Greedy labelling: focused item first, then largest to smallest.
      const order = [focus].concat(items.map((d) => d.i).filter((i) => i !== focus).reverse());
      const shown = new Set();
      order.forEach((i) => {
        const d = items[i];
        if (d.op <= 0 || d.px > W + 4) return;
        const cx = clamp(distance ? d.px : d.px + d.pw / 2, d.lw / 2 + 4, W - d.lw / 2 - 4);
        const top = distance ? baseY - 32 : baseY - d.ph - 8;
        const tiny = !distance && d.pw < 14;
        // Specks only get a label while in focus; the stepper reaches them.
        if (tiny && i !== focus) return;
        let y = tiny ? baseY - 56 : top;
        y = clamp(y, m.t + d.lh - 4, baseY - 30);
        const box = { x0: cx - d.lw / 2 - 3, x1: cx + d.lw / 2 + 3, y0: y - d.lh, y1: y + 3 };
        const hits = placed.some((b) => !(box.x1 < b.x0 || box.x0 > b.x1 || box.y1 < b.y0 || box.y0 > b.y1));
        if (hits && i !== focus) return;
        placed.push(box);
        shown.add(i);
        d.lx = cx; d.ly = y - d.lh + 11; d.tiny = tiny;
      });
      labels.attr('opacity', (d) => (shown.has(d.i) ? d.op : 0))
        .attr('font-weight', null)
        .each(function (d) {
          if (!shown.has(d.i)) return;
          const g = d3.select(this);
          g.selectAll('text').attr('x', d.lx).attr('y', d.ly);
          // The figure counts up as it grows; the fact's own string at rest.
          g.select('.label-value').text(d.gr >= 0.999 || distance ? d.display : fmtSi(d.valueSi * Math.min(1, d.gr), p.units));
          const anchorX = distance ? d.px : d.px + d.pw / 2;
          const leaderTop = d.ly + d.lh - 8;
          const leaderBottom = distance ? baseY - 26 : baseY - d.ph - 2;
          g.select('.leader')
            .attr('opacity', d.tiny || leaderBottom - leaderTop > 14 ? 1 : 0)
            .attr('x1', anchorX).attr('x2', anchorX).attr('y1', leaderTop).attr('y2', leaderBottom);
        });

      const fd = items[focus];
      if (heights && fd.shape === 'tower' && fd.op > 0 && fd.ph > 24 && fd.px + fd.pw + 14 < W) {
        const tx = fd.px + fd.pw + 7, top = baseY - fd.ph * fd.gr;
        tape.attr('opacity', 1);
        tape.select('line').attr('x1', tx).attr('x2', tx).attr('y1', top).attr('y2', baseY);
        tape.select('.cap-top').attr('transform', `translate(${tx},${top})`);
        tape.select('.cap-bottom').attr('transform', `translate(${tx},${baseY})`);
      } else {
        tape.attr('opacity', 0);
      }

      // Scale bar in the most readable unit.
      const unit = p.units.ladder.reduce((best, u) => (world * 0.25 / u.toSi >= 1 ? u : best), p.units.ladder[0]);
      const nice = niceNum(world * 0.25 / unit.toSi);
      const len = nice * unit.toSi * k;
      gScale.selectAll('*').remove();
      gScale.append('path').attr('d', `M0,-4V0H${len}V-4`).attr('fill', 'none').attr('stroke', INK2);
      gScale.append('text').attr('class', 'label-faint').attr('x', len + 6).attr('y', 3)
        .text(fmtNumber(nice) + (unit.symbol ? ' ' + unit.symbol : ''));

      // Annotation once the camera has arrived (placed once per arrival).
      const end = pr >= n - 1 - 1e-3;
      if (end && !gNote.node().hasChildNodes()) {
        const obstacles = placed.map((b) => Object.assign({ w: 8 }, b)).concat(items.filter((d) => d.op > 0).map((d) => (distance
          ? { x0: d.px - 8, x1: d.px + 8, y0: baseY - 30, y1: baseY + 8 }
          : { x0: d.px, x1: d.px + d.pw, y0: baseY - d.ph, y1: baseY })));
        annotate(gNote, p.annotations, p.annotations.map((a) => {
          if (a.anchor !== 'item') return null;
          const d = items[a.index];
          return distance ? { x: d.px, y: baseY - 8 } : { x: d.px + d.pw / 2, y: baseY - d.ph * (d.shape === 'circle' ? 0.5 : 0.7) };
        }), { x: m.l, y: m.t, w: iw, h: ih - 6 }, obstacles);
        gNote.attr('opacity', 0).transition().duration(dur(400)).attr('opacity', 1);
      } else if (!end) {
        gNote.selectAll('*').remove();
      }

      status.text(`${focus + 1} of ${n} · ${items[focus].name}`);
      range.property('value', Math.max(0, pr));
      prevBtn.property('disabled', focus <= 0);
      nextBtn.property('disabled', focus >= n - 1);
    }

    function goTo(target, ms) {
      svg.interrupt();
      const from = progress;
      svg.transition().duration(dur(ms)).ease(d3.easeLinear)
        .tween('camera', () => (t) => draw(from + (target - from) * t));
    }

    const prevBtn = button(controls, 'prev', 'Previous item', () => goTo(Math.round(progress) - 1, 1100));
    const status = controls.append('div').attr('class', 'status');
    const nextBtn = button(controls, 'next', 'Next item', () => goTo(Math.round(progress) + 1, 1100));
    const range = controls.append('input').attr('type', 'range').attr('aria-label', 'Zoom')
      .attr('min', 0).attr('max', n - 1).attr('step', 0.01)
      .on('input', function () { svg.interrupt(); draw(+this.value); });

    if (reduce()) draw(n - 1);
    else {
      // Intro: the first item grows in, then the camera tours the rest.
      draw(-1);
      const per = Math.min(1300, 6500 / Math.max(1, n - 1));
      svg.transition().delay(250).duration(700 + per * (n - 1)).ease(d3.easeLinear)
        .tween('camera', () => (t) => {
          const ms = t * (700 + per * (n - 1));
          draw(ms < 700 ? ms / 700 - 1 : (ms - 700) / per);
        });
    }
  }

  // ---------------------------------------------------------------------
  // timeline: events on a horizontally scrollable axis.

  function yearLabel(y) {
    const r = Math.round(y);
    if (r < -9999) return fmtNumber(-r) + ' BCE';
    if (r < 0) return -r + ' BCE';
    return String(r);
  }

  function renderTimeline(p) {
    const events = p.events;
    const n = events.length;
    const logAxis = p.axis === 'log_years_ago';
    const stage = root.append('div').attr('class', 'stage');
    const scroller = stage.append('div').attr('class', 'scroller');
    const detail = root.append('div').attr('class', 'detail');
    const W = stage.node().clientWidth, H = stage.node().clientHeight;
    const pad = 36, cardW = 124, gap = 10, levels = 2;

    const pos = (e) => (logAxis ? Math.log(e.yearsAgo) : e.year);
    const lo = d3.min(events, pos), hi = d3.max(events, pos);
    const frac = (e) => (hi === lo ? 0 : logAxis ? (hi - pos(e)) / (hi - lo) : (pos(e) - lo) / (hi - lo));

    // Widen the axis until every card fits in two levels per side.
    let width = Math.max(W, n * cardW * 0.62 + 2 * pad);
    let lanes = [], xs = [], lefts = [];
    for (let attempt = 0; attempt < 10; attempt++) {
      xs = events.map((e) => pad + frac(e) * (width - 2 * pad));
      lefts = xs.map((x) => clamp(x - 8, 0, width - cardW));
      const right = new Array(levels * 2).fill(-Infinity);
      let overflow = false;
      lanes = xs.map((_, i) => {
        for (let l = 0; l < right.length; l++) {
          if (right[l] + gap <= lefts[i]) { right[l] = lefts[i] + cardW; return l; }
        }
        overflow = true;
        const l = right.indexOf(Math.min.apply(null, right));
        right[l] = lefts[i] + cardW;
        return l;
      });
      if (!overflow) break;
      width *= 1.35;
    }

    const svg = scroller.append('svg').attr('width', width).attr('height', H).attr('role', 'img')
      .attr('aria-label', `${p.title}. ${events.map((e) => `${e.date}: ${e.label}`).join('; ')}`);
    const axisY = Math.round(H * 0.5);
    const cardH = 40, levelGap = 18;
    const cardY = (lane) => {
      const level = Math.floor(lane / 2);
      return lane % 2 === 0 ? axisY - 26 - cardH - level * (cardH + levelGap) : axisY + 34 + level * (cardH + levelGap);
    };

    // Axis with ticks.
    const scale = logAxis
      ? d3.scaleLog().domain([Math.exp(hi), Math.exp(lo)]).range([pad, width - pad])
      : d3.scaleLinear().domain([lo, hi]).range([pad, width - pad]);
    let axis = d3.axisBottom(scale).tickSize(5).tickPadding(6);
    if (logAxis) {
      const ticks = [];
      for (let k = Math.ceil(lo / Math.LN10); k <= Math.floor(hi / Math.LN10); k++) ticks.push(Math.pow(10, k));
      const minGap = 92;
      const kept = ticks.filter((t, i, arr) => i === 0 || Math.abs(scale(t) - scale(arr[i - 1])) >= minGap);
      axis = axis.tickValues(kept).tickFormat((t) => fmtNumber(t) + ' yrs ago');
    } else {
      axis = axis.ticks(Math.max(2, Math.floor(width / 90))).tickFormat(yearLabel);
    }
    const gAxis = svg.append('g').attr('class', 'axis').attr('transform', `translate(0,${axisY})`).call(axis);
    const line = svg.append('line').attr('class', 'baseline').attr('x1', pad - 12).attr('x2', width - pad + 12)
      .attr('y1', axisY).attr('y2', axisY);

    const gEvents = svg.append('g');
    const ev = gEvents.selectAll('g.event').data(events).join('g').attr('class', 'event')
      .attr('role', 'button').attr('aria-label', (e) => `${e.date}: ${e.label}`);
    ev.append('line').attr('stroke', INK3).attr('stroke-width', 0.75)
      .attr('x1', (_, i) => xs[i]).attr('x2', (_, i) => xs[i])
      .attr('y1', axisY).attr('y2', (_, i) => (lanes[i] % 2 === 0 ? cardY(lanes[i]) + cardH : cardY(lanes[i]) - 2));
    ev.append('circle').attr('cx', (_, i) => xs[i]).attr('cy', axisY).attr('r', 4.5)
      .attr('fill', PAPER).attr('stroke', INK).attr('stroke-width', 1.5);
    const cards = ev.append('g').attr('transform', (_, i) => `translate(${lefts[i]},${cardY(lanes[i])})`);
    cards.append('rect').attr('width', cardW).attr('height', cardH + 6).attr('y', -4).attr('fill', 'transparent');
    cards.append('text').attr('class', 'card-date').attr('y', 8).attr('fill', ACCENT).text((e) => e.date);
    cards.append('text').attr('class', 'card-title').attr('y', 24).each(function (e) {
      wrapText(d3.select(this), e.label, cardW - 4, 2, 15);
    });

    function select(i) {
      ev.classed('selected', (_, j) => j === i);
      ev.select('circle').attr('fill', (_, j) => (j === i ? INK : PAPER));
      const e = events[i];
      detail.html('');
      detail.append('div').attr('class', 'date').text(e.date);
      detail.append('div').attr('class', 'title').text(e.label);
      if (e.description) detail.append('div').attr('class', 'desc').text(e.description);
    }
    ev.on('click', (_, e) => select(events.indexOf(e)));
    detail.append('div').attr('class', 'hint').text('Tap an event to read more.');

    // Annotations as brackets along the bottom.
    const gNote = svg.append('g');
    p.annotations.forEach((a, k) => {
      const y = H - 18 - k * 26;
      let x0, x1;
      if (a.anchor === 'gap') { x0 = xs[a.index]; x1 = xs[a.index2]; }
      else if (a.anchor === 'event' && a.index === n - 1) { x0 = xs[0]; x1 = xs[n - 1]; }
      else { x0 = x1 = xs[a.index]; }
      const g = gNote.append('g').attr('class', 'annotation').attr('opacity', 0);
      if (x1 > x0) g.append('path').attr('d', `M${x0},${y - 10}V${y - 4}H${x1}V${y - 10}`);
      const t = g.append('text').attr('class', 'annotation-note-label halo')
        .attr('x', (x0 + x1) / 2).attr('y', y + 10).attr('text-anchor', 'middle').text(a.text);
      const tw = t.node().getComputedTextLength();
      t.attr('x', clamp((x0 + x1) / 2, tw / 2 + 6, width - tw / 2 - 6));
      g.transition().delay(dur(400 + n * 200)).duration(dur(500)).attr('opacity', 1);
    });

    // Entrance: the axis draws, events appear as it passes them.
    const total = dur(Math.min(5000, 900 + n * 260));
    const len = width;
    line.attr('stroke-dasharray', `${len} ${len}`).attr('stroke-dashoffset', len)
      .transition().duration(total).ease(d3.easeCubicOut).attr('stroke-dashoffset', 0);
    gAxis.attr('opacity', 0).transition().duration(dur(600)).attr('opacity', 1);
    ev.attr('opacity', 0).transition().delay((_, i) => total * frac(events[i]) * 0.9).duration(dur(400)).attr('opacity', 1);
    if (!reduce() && width > W) {
      const node = scroller.node();
      d3.select(node).transition().delay(300).duration(total).ease(d3.easeCubicOut)
        .tween('scroll', () => { const i = d3.interpolateNumber(0, width - W); return (t) => { node.scrollLeft = i(t); }; });
    } else if (width > W) {
      scroller.node().scrollLeft = width - W;
    }
  }

  /** Wraps text into tspans, at most maxLines, ellipsising the last. */
  function wrapText(text, str, width, maxLines, lineHeight) {
    const words = str.split(/\s+/);
    let line = [], lines = 0;
    let tspan = text.text(null).append('tspan').attr('x', 0);
    for (let i = 0; i < words.length; i++) {
      line.push(words[i]);
      tspan.text(line.join(' '));
      if (tspan.node().getComputedTextLength() > width && line.length > 1) {
        line.pop();
        tspan.text(line.join(' '));
        lines++;
        if (lines >= maxLines) {
          tspan.text(line.join(' ').replace(/[,.;:]?$/, '…'));
          return;
        }
        line = [words[i]];
        tspan = text.append('tspan').attr('x', 0).attr('dy', lineHeight).text(words[i]);
      }
    }
  }

  // ---------------------------------------------------------------------
  // exponential_growth: a line that crawls, then explodes. Linear/log
  // toggle morphs the y scale; annotations appear as the line reaches them.

  function renderGrowth(p) {
    const series = p.series;
    const steps = p.steps;
    const target = p.target;
    const cap = p.stepLabel.charAt(0).toUpperCase() + p.stepLabel.slice(1);
    let mix = p.defaultScale === 'log' ? 1 : 0; // 0 linear, 1 log

    const { svg, w: W, h: H, controls, readout } = layout(() => {
      const readout = root.insert('div', '.stage').attr('class', 'readout');
      return { readout, controls: root.append('div').attr('class', 'controls') };
    });
    const head0 = readout.append('div').style('display', 'flex').style('align-items', 'flex-start');
    const text = head0.append('div').style('flex', '1').style('min-width', '0');
    const rStep = text.append('div').attr('class', 'step');
    const rValue = text.append('div').attr('class', 'value');
    const rNote = readout.append('div').attr('class', 'note').text(`×${fmtNumber(p.factor)} every ${p.stepLabel}`);
    const seg = head0.append('div').attr('class', 'seg').style('margin-top', '4px');
    svg.attr('aria-label', `${p.title}. Starts at ${p.initial.display}, ×${fmtNumber(p.factor)} per ${p.stepLabel}, ` +
      `${steps} ${p.stepLabel}s, ends at ${series[steps].display}.`);

    const top = Math.max(series[steps].valueSi, target ? target.valueSi : 0);
    const bottom = Math.min(series[0].valueSi, target ? target.valueSi : Infinity);
    const yLin = d3.scaleLinear().domain([0, top * 1.06]);
    const yLog = d3.scaleLog().domain([bottom, top]).nice();
    const linFmt = axisFormatter(p.units, top);
    const logTicks = (() => {
      const [a, b] = yLog.domain();
      const t = [];
      for (let k = Math.ceil(Math.log10(a)); k <= Math.floor(Math.log10(b)); k++) t.push(Math.pow(10, k));
      const stride = Math.max(1, Math.ceil(t.length / 5));
      return t.filter((_, i) => i % stride === 0);
    })();
    const labelW = Math.max(
      ...yLin.ticks(4).map((v) => textWidth(svg, linFmt(v), 'axis-probe')),
      ...logTicks.map((v) => textWidth(svg, fmtSi(v, p.units), 'axis-probe')),
    );
    const m = { l: Math.ceil(labelW) + 14, r: 14, t: 18, b: 26 };
    const iw = W - m.l - m.r, ih = H - m.t - m.b;
    const x = d3.scaleLinear().domain([0, steps]).range([m.l, m.l + iw]);
    yLin.range([m.t + ih, m.t]);
    yLog.range([m.t + ih, m.t]);
    const y = (v) => (1 - mix) * yLin(v) + mix * yLog(Math.max(v, yLog.domain()[0]));
    const valueAt = (s) => {
      const i = Math.min(Math.floor(s), steps);
      return series[i].valueSi * Math.pow(p.factor, s - i);
    };

    const gGrid = svg.append('g').attr('class', 'grid');
    const gY = svg.append('g').attr('class', 'axis').attr('transform', `translate(${m.l},0)`);
    svg.append('g').attr('class', 'axis with-domain').attr('transform', `translate(0,${m.t + ih})`)
      .call(d3.axisBottom(x).ticks(Math.min(steps, 6)).tickSize(4).tickFormat(d3.format('d')));
    const area = svg.append('path').attr('fill', ACCENT).attr('fill-opacity', 0.08);
    const path = svg.append('path').attr('fill', 'none').attr('stroke', ACCENT).attr('stroke-width', 2.2)
      .attr('stroke-linejoin', 'round');
    const gTarget = svg.append('g');
    const head = svg.append('circle').attr('r', 4.5).attr('fill', ACCENT).attr('stroke', PAPER).attr('stroke-width', 2);
    const gNote = svg.append('g').attr('class', 'annotation-group');

    function drawAxes(ms) {
      const log = mix > 0.5;
      const scale = log ? yLog : yLin;
      const ticks = log ? logTicks : yLin.ticks(4);
      const ax = d3.axisLeft(scale).tickSize(0).tickPadding(8).tickValues(ticks)
        .tickFormat(log ? (v) => fmtSi(v, p.units) : linFmt);
      gY.transition().duration(dur(ms)).call(ax);
      gGrid.selectAll('line').data(ticks).join('line').attr('x1', m.l).attr('x2', m.l + iw)
        .transition().duration(dur(ms)).attr('y1', (v) => scale(v)).attr('y2', (v) => scale(v));
    }

    let progress = 0, playing = false, celebrated = false, notesKey = '';
    function draw(s) {
      progress = clamp(s, 0, steps);
      const n = Math.max(2, Math.ceil(progress * 6));
      const pts = d3.range(n + 1).map((i) => {
        const st = (progress * i) / n;
        return [x(st), clamp(y(valueAt(st)), m.t - 4, m.t + ih)];
      });
      path.attr('d', d3.line()(pts));
      area.attr('d', d3.area().y0(m.t + ih)(pts));
      const last = pts[pts.length - 1];
      head.attr('cx', last[0]).attr('cy', last[1]);

      gTarget.selectAll('*').remove();
      let targetBox = null;
      if (target) {
        const ty = y(target.valueSi);
        if (ty >= m.t - 1 && ty <= m.t + ih + 1) {
          gTarget.append('line').attr('x1', m.l).attr('x2', m.l + iw).attr('y1', ty).attr('y2', ty)
            .attr('stroke', INK).attr('stroke-dasharray', '3 3');
          const t = gTarget.append('text').attr('class', 'label-name halo').attr('x', m.l + 6).attr('y', ty - 6)
            .text(`${target.label} · ${target.display}`);
          const tw = t.node().getComputedTextLength();
          targetBox = { w: 8, x0: m.l, x1: m.l + tw + 12, y0: ty - 20, y1: ty + 4 };
        }
      }

      const whole = Math.floor(progress + 1e-9);
      rStep.text(`${cap} ${whole} of ${steps}`);
      rValue.text(series[whole].display);
      const reached = p.targetStep != null && whole >= p.targetStep;
      if (reached && playing && !celebrated) { celebrated = true; post({ type: 'haptic' }); }

      // Annotations appear as the line reaches them; re-placed only when the set changes.
      const visible = p.annotations.map((a) => a.anchor === 'step' && progress + 1e-6 >= a.index);
      const key = visible.join() + mix;
      if (key !== notesKey) {
        notesKey = key;
        const curve = d3.range(0, steps + 1, Math.max(1, Math.floor(steps / 24))).map((st) => {
          const cx = x(st), cy = y(valueAt(st));
          return { x0: cx - 6, x1: cx + 6, y0: cy - 6, y1: cy + 6 };
        });
        annotate(gNote, p.annotations, p.annotations.map((a, i) => (visible[i]
          ? { x: x(a.index), y: clamp(y(series[a.index].valueSi), m.t, m.t + ih) } : null)),
        { x: m.l + 4, y: m.t, w: iw - 4, h: ih }, curve.concat(targetBox ? [targetBox] : []), { wrap: 140 });
      }

      range.property('value', progress);
      playBtn.html(ICONS[playing ? 'pause' : 'play']).attr('aria-label', playing ? 'Pause' : 'Play');
      prevBtn.property('disabled', progress <= 0);
      nextBtn.property('disabled', progress >= steps);
    }

    let timer = null;
    function play(from) {
      stop();
      playing = true;
      const start = from != null ? from : (progress >= steps ? 0 : progress);
      if (start === 0) celebrated = false;
      const msPerStep = clamp(7000 / steps, 90, 400);
      timer = track(d3.timer((elapsed) => {
        const s = start + elapsed / msPerStep;
        if (s >= steps) { timer.stop(); draw(steps); playing = false; draw(steps); return; }
        draw(s);
      }));
    }
    function stop() { if (timer) timer.stop(); playing = false; }
    function jump(s) { stop(); draw(Math.round(s)); }

    const prevBtn = button(controls, 'prev', `Previous ${p.stepLabel}`, () => jump(Math.ceil(progress) - 1));
    const playBtn = button(controls, 'play', 'Play', () => { if (playing) { stop(); draw(progress); } else play(); }, 'primary');
    const nextBtn = button(controls, 'next', `Next ${p.stepLabel}`, () => jump(Math.floor(progress) + 1));
    const range = controls.append('input').attr('type', 'range').attr('aria-label', cap)
      .attr('min', 0).attr('max', steps).attr('step', 1)
      .on('input', function () { jump(+this.value); });
    const segBtns = seg.selectAll('button').data(['Linear', 'Log']).join('button').text((d) => d)
      .attr('aria-pressed', (d) => String((d === 'Log') === (mix === 1)))
      .on('click', (_, d) => {
        const to = d === 'Log' ? 1 : 0;
        if (to === mix) return;
        segBtns.attr('aria-pressed', (b) => String(b === d));
        const from = mix;
        mix = to;
        drawAxes(700);
        mix = from;
        svg.transition('morph').duration(dur(700)).ease(d3.easeCubicInOut)
          .tween('mix', () => (t) => { mix = from + (to - from) * t; draw(progress); });
      });

    drawAxes(0);
    draw(0);
    if (reduce()) draw(steps); else setTimeout(() => play(0), 450);
  }

  // ---------------------------------------------------------------------
  // comparison_bars: direct-labelled bars that grow in turn.

  function renderBars(p) {
    const bars = p.bars;
    const n = bars.length;
    const { svg, w: W, h: H } = layout();
    svg.attr('aria-label', `${p.title}. ${bars.map((b) => `${b.name}: ${b.display}`).join('; ')}`);
    const max = d3.max(bars, (b) => b.valueSi);
    const axis = unitAxis(p.units, 0, max, 3);
    const fmt = axis.fmt;
    // Upright columns only when every label word fits under its column.
    const longestWord = Math.max(...bars.flatMap((b) => b.name.split(/\s+/)).map((w) => textWidth(svg, w, 'label-name')));
    const horizontal = p.orientation === 'horizontal' || longestWord > ((W - 32) / n) * 0.92;
    const hasIcons = bars.some((b) => b.image);
    const obstacles = [];
    let bounds;

    if (horizontal) {
      const valueW = Math.max(...bars.map((b) => textWidth(svg, b.display, 'label-value')));
      const m = { l: 16, r: 16 + valueW + 8, t: 30, b: 12 };
      const rowH = Math.min(84, (H - m.t - m.b) / n);
      const top = m.t + Math.max(0, (H - m.t - m.b - rowH * n) / 2.4);
      const x = d3.scaleLinear().domain([0, max]).range([m.l, W - m.r]);
      const ticks = axis.ticks.filter((t) => t <= max);
      svg.append('g').attr('class', 'grid').selectAll('line').data(ticks).join('line')
        .attr('x1', x).attr('x2', x).attr('y1', top - 4).attr('y2', top + rowH * n - 6);
      svg.append('g').attr('class', 'axis').attr('transform', `translate(0,${top - 8})`)
        .call(d3.axisTop(x).tickValues(ticks).tickSize(0).tickFormat(fmt))
        .call((g) => { const t = g.selectAll('.tick text').nodes(); if (t.length) d3.select(t[0]).attr('text-anchor', 'start'); });
      const barH = Math.max(12, Math.min(24, rowH * 0.3));
      const iconW = hasIcons ? 38 : 0;
      svg.selectAll('g.row').data(bars).join('g').attr('class', 'row')
        .attr('transform', (_, i) => `translate(0,${top + i * rowH})`)
        .each(function (b, i) {
          const g = d3.select(this);
          const color = PALETTE[i % PALETTE.length];
          const y0 = rowH * 0.1;
          if (b.image) icon(g, b.image, color, m.l, y0, iconW - 8, 20);
          const nameT = g.append('text').attr('class', 'label-name').attr('x', m.l + iconW).attr('y', y0 + 15).text(b.name);
          const by = y0 + 26;
          const bw = Math.max(1.5, x(b.valueSi) - m.l);
          g.append('rect').attr('x', m.l).attr('y', by).attr('height', barH).attr('width', 0).attr('fill', color)
            .transition().delay(dur(150 + i * 150)).duration(dur(900)).ease(d3.easeCubicOut).attr('width', bw);
          const v = g.append('text').attr('class', 'label-value').attr('y', by + barH / 2 + 4.5).attr('x', m.l + 6);
          v.transition().delay(dur(150 + i * 150)).duration(dur(900)).ease(d3.easeCubicOut)
            .attr('x', m.l + bw + 6)
            .tween('text', () => (t) => v.text(t < 1 ? fmtSi(b.valueSi * t, p.units) : b.display));
          if (reduce()) v.text(b.display);
          const rowTop = top + i * rowH;
          obstacles.push({ x0: m.l, x1: m.l + bw + 8 + valueW, y0: rowTop + by - 2, y1: rowTop + by + barH + 2 });
          obstacles.push({ w: 8, x0: m.l, x1: m.l + iconW + nameT.node().getComputedTextLength(), y0: rowTop + y0, y1: rowTop + y0 + 20 });
          b._anchor = { x: m.l + bw * 0.92, y: rowTop + by + barH };
        });
      bounds = { x: 16, y: top, w: W - 32, h: Math.min(H - top - 8, rowH * n + 40) };
    } else {
      const m = { l: 16, r: 16, t: 26, b: 42 };
      const ih = H - m.t - m.b;
      const xb = d3.scaleBand().domain(d3.range(n)).range([m.l, W - m.r]).padding(0.34);
      const y = d3.scaleLinear().domain([0, max]).range([m.t + ih, m.t + 18]);
      svg.append('line').attr('class', 'baseline').attr('x1', m.l).attr('x2', W - m.r).attr('y1', m.t + ih).attr('y2', m.t + ih);
      svg.selectAll('g.col').data(bars).join('g').attr('class', 'col').each(function (b, i) {
        const g = d3.select(this);
        const color = PALETTE[i % PALETTE.length];
        const bx = xb(i), bw = xb.bandwidth();
        const by = y(b.valueSi);
        g.append('rect').attr('x', bx).attr('width', bw).attr('y', m.t + ih).attr('height', 0).attr('fill', color)
          .transition().delay(dur(150 + i * 150)).duration(dur(900)).ease(d3.easeCubicOut)
          .attr('y', by).attr('height', Math.max(1.5, m.t + ih - by));
        g.append('text').attr('class', 'label-value').attr('text-anchor', 'middle').attr('x', bx + bw / 2)
          .attr('y', by - 6).text(b.display).attr('opacity', 0)
          .transition().delay(dur(700 + i * 150)).duration(dur(300)).attr('opacity', 1);
        const t = g.append('text').attr('class', 'label-name').attr('text-anchor', 'middle').attr('y', m.t + ih + 16);
        wrapCentered(t, b.name, xb.step() - 4, bx + bw / 2);
        obstacles.push({ x0: bx - 4, x1: bx + bw + 4, y0: by - 20, y1: m.t + ih });
        b._anchor = { x: bx + bw / 2, y: by + Math.min(30, (m.t + ih - by) / 3) };
      });
      bounds = { x: 16, y: m.t, w: W - 32, h: ih };
    }

    const gNote = svg.append('g').attr('class', 'annotation-group').attr('opacity', 0);
    annotate(gNote, p.annotations, p.annotations.map((a) => {
      const b = bars[a.index];
      return b && b._anchor ? b._anchor : null;
    }), bounds, obstacles, { wrap: 160 });
    gNote.transition().delay(dur(500 + n * 150 + 700)).duration(dur(400)).attr('opacity', 1);
  }

  function wrapCentered(text, str, width, cx) {
    const words = str.split(/\s+/);
    let line = [];
    let tspan = text.append('tspan').attr('x', cx);
    words.forEach((w) => {
      line.push(w);
      tspan.text(line.join(' '));
      if (tspan.node().getComputedTextLength() > width && line.length > 1) {
        line.pop();
        tspan.text(line.join(' '));
        line = [w];
        tspan = text.append('tspan').attr('x', cx).attr('dy', 13).text(w);
      }
    });
  }

  /** A small picture beside a label: photo or silhouette, fitted to box. */
  function icon(g, image, color, x, y, w, h) {
    if (image.kind === 'photo') {
      const s = Math.min(w, h);
      g.append('image').attr('href', image.src).attr('x', x).attr('y', y).attr('width', s).attr('height', s / image.aspect);
      return;
    }
    const sil = silhouette(g, image.key, color);
    if (!sil) return;
    const a = sil.box[2] / sil.box[3];
    const fw = Math.min(w, h * a), fh = fw / a;
    placeSilhouette(sil.g.node(), sil.box, x, y + (h - fh), fw, fh);
  }

  // ---------------------------------------------------------------------
  // process_steps: a cycle diagram, or a vertical sequence, that autoplays.

  function renderSteps(p) {
    const steps = p.steps;
    const n = steps.length;
    const ring = p.loop && n <= 8;
    const stage = root.append('div').attr('class', 'stage');
    const panel = ring ? root.append('div').attr('class', 'step-panel') : null;
    const controls = root.append('div').attr('class', 'controls');
    const W = stage.node().clientWidth, H = stage.node().clientHeight;
    let list = null, nodes = null, arcs = null;

    if (ring) {
      const svg = stage.append('svg').attr('role', 'img')
        .attr('aria-label', `${p.title}: ${steps.map((s) => s.title).join(', then ')}, and repeat.`);
      const labelRoom = Math.max(...steps.map((s) => textWidth(svg, s.title, 'label-name'))) + 14;
      const r = Math.max(26, Math.min(W / 2 - labelRoom - 6, H / 2 - 26));
      const cx = W / 2, cy = H / 2 + 2;
      const nodeR = 14;
      const ang = (i) => -Math.PI / 2 + (2 * Math.PI * i) / n;
      const pt = (a, rr = r) => [cx + rr * Math.cos(a), cy + rr * Math.sin(a)];
      svg.append('defs').append('marker').attr('id', 'arrow').attr('viewBox', '0 0 10 10').attr('refX', 8).attr('refY', 5)
        .attr('markerWidth', 6).attr('markerHeight', 6).attr('orient', 'auto')
        .append('path').attr('d', 'M0,1L9,5L0,9z').attr('fill', 'context-stroke');
      svg.append('circle').attr('cx', cx).attr('cy', cy).attr('r', r).attr('fill', 'none')
        .attr('stroke', RULE).attr('stroke-dasharray', '2 4');
      arcs = svg.append('g').selectAll('path').data(steps).join('path')
        .attr('fill', 'none').attr('stroke', INK3).attr('stroke-width', 1.2).attr('marker-end', 'url(#arrow)')
        .attr('d', (_, i) => {
          const pad = (nodeR + 6) / r;
          const [x0, y0] = pt(ang(i) + pad);
          const [x1, y1] = pt(ang(i + 1) - pad);
          const large = 2 * Math.PI / n - 2 * pad > Math.PI ? 1 : 0;
          return `M${x0},${y0}A${r},${r} 0 ${large} 1 ${x1},${y1}`;
        });
      nodes = svg.append('g').selectAll('g').data(steps).join('g')
        .attr('transform', (_, i) => `translate(${pt(ang(i)).join(',')})`)
        .attr('role', 'button').attr('aria-label', (s) => `Step ${s.order}: ${s.title}`)
        .on('click', (_, s) => goTo(steps.indexOf(s)));
      nodes.append('circle').attr('r', nodeR).attr('stroke', INK).attr('stroke-width', 1.2);
      nodes.append('text').attr('class', 'num').attr('text-anchor', 'middle').attr('dy', '0.35em')
        .style('font', '600 12px var(--sans)').text((s) => s.order);
      nodes.append('text').attr('class', 'label-name halo').attr('dy', '0.35em')
        .each(function (_, i) {
          const c = Math.cos(ang(i)), sn = Math.sin(ang(i));
          const t = d3.select(this);
          if (Math.abs(c) > 0.5) t.attr('x', c > 0 ? nodeR + 8 : -nodeR - 8).attr('text-anchor', c > 0 ? 'start' : 'end');
          else t.attr('y', sn > 0 ? nodeR + 12 : -nodeR - 12).attr('text-anchor', 'middle');
        })
        .text((s) => s.title);
      svg.append('text').attr('x', cx).attr('y', cy).attr('text-anchor', 'middle').attr('dy', '0.35em')
        .style('font', 'italic 400 13px var(--serif)').attr('fill', INK3).text('and repeat');
    } else {
      list = stage.append('ol').attr('class', 'step-list');
      const li = list.selectAll('li').data(steps).join('li').on('click', (_, s) => goTo(steps.indexOf(s)));
      li.append('div').attr('class', 'dot').text((s) => s.order);
      const body = li.append('div');
      body.append('h4').text((s) => s.title);
      body.append('p').text((s) => s.description);
    }
    const bar = stage.append('div').attr('class', 'progress').append('div');

    let index = 0, playing = false, timer = null;
    function show(i) {
      index = (i + n) % n;
      const s = steps[index];
      if (ring) {
        nodes.select('circle').attr('fill', (_, j) => (j === index ? INK : PAPER));
        nodes.select('text.num').attr('fill', (_, j) => (j === index ? PAPER : INK));
        arcs.attr('stroke', (_, j) => (j === index ? INK : INK3)).attr('stroke-width', (_, j) => (j === index ? 2 : 1.2));
        panel.html('');
        panel.append('div').attr('class', 'num').text(`Step ${s.order} of ${n}`);
        panel.append('h3').text(s.title);
        panel.append('p').text(s.description);
      } else {
        list.selectAll('li').attr('class', (_, j) => (j === index ? 'active' : j < index ? 'done' : ''));
        const node = list.selectAll('li').nodes()[index];
        if (node) node.scrollIntoView({ block: 'nearest', behavior: reduce() ? 'auto' : 'smooth' });
      }
      status.text(`Step ${s.order} of ${n}`);
      prevBtn.property('disabled', !p.loop && index === 0);
      nextBtn.property('disabled', !p.loop && index === n - 1);
    }
    function tick() {
      stopTimer();
      bar.style('width', '0%');
      if (!playing) return;
      const ms = p.autoplayMs;
      timer = track(d3.timer((e) => {
        bar.style('width', `${Math.min(100, (e / ms) * 100)}%`);
        if (e < ms) return;
        stopTimer();
        if (index === n - 1 && !p.loop) { playing = false; updatePlay(); return; }
        show(index + 1);
        tick();
      }));
    }
    function stopTimer() { if (timer) { timer.stop(); timer = null; } }
    function updatePlay() { playBtn.html(ICONS[playing ? 'pause' : 'play']).attr('aria-label', playing ? 'Pause' : 'Play'); }
    function goTo(i) { show(i); tick(); }

    const prevBtn = button(controls, 'prev', 'Previous step', () => goTo(index - 1));
    const playBtn = button(controls, 'play', 'Play', () => {
      playing = !playing;
      if (playing && index === n - 1 && !p.loop) show(0);
      updatePlay();
      tick();
    }, 'primary');
    const nextBtn = button(controls, 'next', 'Next step', () => goTo(index + 1));
    const status = controls.append('div').attr('class', 'status');

    show(0);
    playing = !reduce();
    updatePlay();
    tick();
  }

  // ---------------------------------------------------------------------

  const renderers = {
    scale_zoom: renderScale,
    timeline: renderTimeline,
    exponential_growth: renderGrowth,
    comparison_bars: renderBars,
    process_steps: renderSteps,
  };

  function render(payload, options) {
    teardown();
    state.payload = payload;
    state.options = options || {};
    root.html('');
    const fn = renderers[payload && payload.template];
    try {
      if (!fn) throw new Error('unknown template ' + (payload && payload.template));
      fn(payload);
      post({ type: 'rendered', template: payload.template });
    } catch (e) {
      root.html('').append('div').attr('class', 'error').text("This visualization couldn't be drawn.");
      post({ type: 'error', message: String(e && e.stack || e) });
    }
  }

  function replay() {
    if (state.payload) render(state.payload, state.options);
  }

  let resizeTimer = null;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => { if (state.payload) render(state.payload, Object.assign({}, state.options, { reduceMotion: true })); }, 150);
  });

  // Shared toolkit for the extended chart library (viz_extra.js).
  const kit = {
    root, state, PALETTE, INK, INK2, INK3, RULE, PAPER, ACCENT, ICONS,
    post, fmtNumber, fmtSi, axisFormatter, niceNum, clamp, reduce, dur, track, button, layout,
    textWidth, silhouette, placeSilhouette, annotate, wrapText, wrapCentered, icon, yearLabel,
    pickUnit, unitFmt, unitAxis, logAxis,
  };
  const register = (name, fn) => { renderers[name] = fn; };

  window.FactvizViz = { render, replay, fmtNumber, fmtSi, kit, register };
  // Announce readiness after viz_extra.js has registered its charts.
  window.addEventListener('load', () => post({ type: 'ready' }));
})();
