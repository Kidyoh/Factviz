/*
 * Explain It Visually: extended chart library.
 *
 * Same contract as viz.js: the app sends resolved JSON with every figure
 * already formatted (render_json_extra.dart). These renderers only lay out,
 * scale and animate. The one live number, the rate counter, multiplies a
 * fact's per-second rate by the time since the chart opened.
 */
(function () {
  'use strict';

  const V = window.FactvizViz;
  const K = V.kit;
  const { root, PALETTE, INK, INK2, INK3, RULE, PAPER, ACCENT } = K;
  const { fmtNumber, dur, reduce, track, layout, textWidth, annotate, icon, yearLabel } = K;
  const OTHER = '#CBC3B4';
  const LAND = '#E6DFD1';

  const colorOf = (item, i) => (item && item.remainder ? OTHER : PALETTE[i % PALETTE.length]);

  /** A tappable detail strip under a chart (name, value, source). */
  function detailStrip(hint) {
    const el = root.append('div').attr('class', 'detail');
    const set = (kicker, title, desc) => {
      el.html('');
      if (kicker) el.append('div').attr('class', 'date').text(kicker);
      if (title) el.append('div').attr('class', 'title').text(title);
      if (desc) el.append('div').attr('class', 'desc').text(desc);
    };
    if (hint) el.append('div').attr('class', 'hint').text(hint);
    return { el, set };
  }

  /** Pushes label centres apart so boxes of height h don't overlap, within [lo, hi]. */
  function spread(ys, h, lo, hi) {
    const order = ys.map((y, i) => ({ y, i })).sort((a, b) => a.y - b.y);
    const out = order.map((o) => o.y);
    for (let pass = 0; pass < 60; pass++) {
      let moved = false;
      for (let k = 1; k < out.length; k++) {
        const gap = out[k] - out[k - 1];
        if (gap < h) {
          const push = (h - gap) / 2;
          out[k - 1] -= push; out[k] += push; moved = true;
        }
      }
      for (let k = 0; k < out.length; k++) out[k] = Math.max(lo + h / 2, Math.min(hi - h / 2, out[k]));
      if (!moved) break;
    }
    const res = new Array(ys.length);
    order.forEach((o, k) => { res[o.i] = out[k]; });
    return res;
  }

  /** An italic one-line note (used where a callout would cover the data). */
  function noteLine(svg, text, x, y, grow, delay) {
    // Wraps to two lines when needed. grow 'up': the last line sits on y
    // (notes at the foot of a chart); 'down': the first line does.
    const W = +svg.attr('width') || svg.node().getBoundingClientRect().width;
    const g = svg.append('g').attr('opacity', 0);
    const t = g.append('text').attr('class', 'note-line');
    K.wrapText(t, text, W - 32, 2, 17);
    const lines = t.selectAll('tspan').size();
    g.attr('transform', `translate(${x},${grow === 'down' ? y : y - (lines - 1) * 17})`);
    g.transition().delay(dur(delay)).duration(dur(400)).attr('opacity', 1);
  }

  const isPercent = (p) => p.units && p.units.dimension === 'percent';

  /** Drops ticks whose labels would collide on a horizontal axis. */
  function thinTicks(svg, x, ticks, fmt) {
    // Conservative spacing: edge labels are anchored at their ends, so a
    // label may extend its full width to one side.
    const out = [];
    let lastX = -Infinity, lastW = 0;
    for (const t of ticks) {
      const w = textWidth(svg, fmt(t), 'axis-label');
      if (x(t) - lastX < lastW + w + 8) continue;
      out.push(t);
      lastX = x(t);
      lastW = w;
    }
    return out;
  }

  /** Keeps the outermost tick labels of a horizontal axis inside the chart. */
  function edgeTicks(g) {
    const texts = g.selectAll('.tick text').nodes();
    if (texts.length) {
      d3.select(texts[0]).attr('text-anchor', 'start');
      d3.select(texts[texts.length - 1]).attr('text-anchor', 'end');
    }
    return g;
  }

  function vscroll(stage) {
    return stage.append('div').attr('class', 'vscroll');
  }

  // ---------------------------------------------------------------------
  // donut: a ring of shares; tap a slice for its numbers.

  function renderDonut(p) {
    const items = p.items;
    const { svg, stage, w: W, h: H } = layout();
    svg.attr('aria-label', `${p.title}. ${items.map((i) => `${i.name}: ${i.shareDisplay}`).join('; ')}`);
    const legendRowH = 24;
    const legendH = items.length * legendRowH + 10;
    const ringH = Math.max(150, H - legendH - 8);
    const r = Math.min(W / 2 - 24, ringH / 2 - 10);
    const cx = W / 2, cy = 10 + ringH / 2;
    const arc = d3.arc().innerRadius(r * 0.62).outerRadius(r).cornerRadius(1.5).padAngle(0.008);
    const pie = d3.pie().sort(null).value((d) => Math.max(0, d.share));
    const arcs = pie(items);
    const g = svg.append('g').attr('transform', `translate(${cx},${cy})`);

    const centre = g.append('g');
    const big = centre.append('text').attr('class', 'big-figure').attr('text-anchor', 'middle').attr('y', -2);
    const sub = centre.append('text').attr('class', 'label-name').attr('text-anchor', 'middle').attr('y', 20);
    const sub2 = centre.append('text').attr('class', 'label-value').attr('text-anchor', 'middle').attr('y', 37);
    let largest = 0;
    items.forEach((it, i) => { if (!it.remainder && it.share > items[largest].share) largest = i; });
    function focus(i) {
      const it = items[i];
      big.text(it.shareDisplay);
      sub.text(it.name);
      sub2.text(isPercent(p) ? '' : it.display);
      paths.attr('opacity', (_, j) => (j === i ? 1 : 0.55));
      legend.attr('opacity', (_, j) => (j === i ? 1 : 0.7));
    }

    const paths = g.selectAll('path').data(arcs).join('path')
      .attr('fill', (d, i) => colorOf(d.data, i)).attr('stroke', PAPER).attr('stroke-width', 1.5)
      .attr('role', 'button').attr('aria-label', (d) => `${d.data.name}: ${d.data.shareDisplay}, ${d.data.display}`)
      .on('click', (_, d) => focus(arcs.indexOf(d)));
    if (reduce()) paths.attr('d', arc);
    else {
      paths.attr('d', (d) => arc({ ...d, endAngle: d.startAngle }))
        .transition().delay((_, i) => 120 + i * 140).duration(700).ease(d3.easeCubicOut)
        .attrTween('d', (d) => { const it = d3.interpolate(d.startAngle, d.endAngle); return (t) => arc({ ...d, endAngle: it(t) }); });
    }
    // Share labels on slices big enough to hold them.
    g.selectAll('text.slice').data(arcs.filter((d) => d.endAngle - d.startAngle > 0.32)).join('text')
      .attr('class', 'slice-label').attr('text-anchor', 'middle').attr('dy', '0.35em')
      .attr('transform', (d) => `translate(${arc.centroid(d)})`).text((d) => d.data.shareDisplay)
      .attr('opacity', 0).transition().delay(dur(900 + items.length * 140)).duration(dur(300)).attr('opacity', 1);

    const lg = svg.append('g').attr('transform', `translate(18,${10 + ringH + 6})`);
    const valueW = isPercent(p) ? -10 : Math.max(...items.map((i) => textWidth(svg, i.display, 'label-value')));
    const legend = lg.selectAll('g').data(items).join('g')
      .attr('transform', (_, i) => `translate(0,${i * legendRowH})`)
      .attr('role', 'button').on('click', (_, d) => focus(items.indexOf(d)));
    legend.append('rect').attr('width', 12).attr('height', 12).attr('y', 3).attr('rx', 2).attr('fill', (d, i) => colorOf(d, i));
    legend.append('text').attr('class', 'label-name').attr('x', 20).attr('y', 13).text((d) => d.name);
    legend.append('text').attr('class', 'label-share').attr('x', W - 36 - valueW - 10).attr('y', 13).attr('text-anchor', 'end')
      .text((d) => d.shareDisplay);
    legend.append('text').attr('class', 'label-value').attr('x', W - 36).attr('y', 13).attr('text-anchor', 'end').text((d) => (isPercent(p) ? '' : d.display));
    focus(largest);
    stage.attr('data-focus', largest);
  }

  // ---------------------------------------------------------------------
  // stacked_bar: one bar split into its parts.

  function renderStacked(p) {
    const items = p.items;
    const { svg, w: W, h: H } = layout();
    svg.attr('aria-label', `${p.title}. ${items.map((i) => `${i.name}: ${i.shareDisplay}`).join('; ')}`);
    const m = { l: 16, r: 16 };
    const barH = 54;
    const rowH0 = 36;
    const blockH = 24 + barH + 54 + rowH0 * items.length;
    const top = 34 + Math.max(0, (H - blockH) / 2.4);
    const x = d3.scaleLinear().domain([0, 1]).range([m.l, W - m.r]);
    let acc = 0;
    const segs = items.map((it, i) => { const s = { it, i, x0: acc, x1: acc + it.share }; acc += it.share; return s; });
    const scale = acc > 0 ? 1 / Math.max(1, acc) : 1;
    segs.forEach((s) => { s.x0 *= scale; s.x1 *= scale; });

    svg.append('text').attr('class', 'label-faint').attr('x', m.l).attr('y', top - 10)
      .text(p.total ? `${p.total.label}: ${p.total.display}` : 'Share of the whole');
    const g = svg.append('g');
    g.selectAll('rect').data(segs).join('rect')
      .attr('y', top).attr('height', barH).attr('fill', (s) => colorOf(s.it, s.i)).attr('stroke', PAPER).attr('stroke-width', 1.5)
      .attr('x', (s) => x(s.x0)).attr('width', 0)
      .transition().delay((s) => dur(150 + s.i * 160)).duration(dur(650)).ease(d3.easeCubicOut)
      .attr('width', (s) => Math.max(0.5, x(s.x1) - x(s.x0)));
    g.selectAll('text').data(segs.filter((s) => x(s.x1) - x(s.x0) > textWidth(svg, s.it.shareDisplay, 'slice-label') + 10)).join('text')
      .attr('class', 'slice-label').attr('text-anchor', 'middle').attr('x', (s) => (x(s.x0) + x(s.x1)) / 2).attr('y', top + barH / 2 + 4)
      .text((s) => s.it.shareDisplay).attr('opacity', 0)
      .transition().delay((s) => dur(600 + s.i * 160)).duration(dur(300)).attr('opacity', 1);

    // Legend rows with leader ticks to their segments.
    const rowsTop = top + barH + 54;
    const rowH = Math.min(rowH0, (H - rowsTop - 8) / items.length);
    const valueW = isPercent(p) ? -10 : Math.max(...items.map((i) => textWidth(svg, i.display, 'label-value')));
    const rows = svg.append('g').selectAll('g').data(segs).join('g').attr('transform', (s) => `translate(0,${rowsTop + s.i * rowH})`);
    rows.append('rect').attr('x', m.l).attr('y', 2).attr('width', 12).attr('height', 12).attr('rx', 2).attr('fill', (s) => colorOf(s.it, s.i));
    rows.append('text').attr('class', 'label-name').attr('x', m.l + 20).attr('y', 12).text((s) => s.it.name);
    rows.append('text').attr('class', 'label-share').attr('x', W - m.r - valueW - 10).attr('y', 12).attr('text-anchor', 'end')
      .text((s) => s.it.shareDisplay);
    rows.append('text').attr('class', 'label-value').attr('x', W - m.r).attr('y', 12).attr('text-anchor', 'end').text((s) => (isPercent(p) ? '' : s.it.display));

    const gNote = svg.append('g').attr('class', 'annotation-group').attr('opacity', 0);
    annotate(gNote, p.annotations, p.annotations.map((a) => {
      const s = segs[a.index];
      return s ? { x: x((s.x0 + s.x1) / 2), y: top + barH } : null;
    }), { x: 16, y: top + barH, w: W - 32, h: rowsTop - top - barH - 4 }, [], { wrap: Math.min(240, W - 40) });
    gNote.transition().delay(dur(900 + items.length * 160)).duration(dur(400)).attr('opacity', 1);
  }

  // ---------------------------------------------------------------------
  // waffle: a 10×10 grid per percentage.

  function renderWaffle(p) {
    const items = p.items;
    const n = items.length;
    const { svg, w: W, h: H } = layout();
    svg.attr('aria-label', `${p.title}. ${items.map((i) => `${i.name}: ${i.display}`).join('; ')}`);
    const cols = n === 1 ? 1 : 2;
    const rows = Math.ceil(n / cols);
    const labelH = 46;
    const noteH = p.annotations.length ? 30 : 0;
    const cellW = (W - 32 - (cols - 1) * 20) / cols;
    const cellH = (H - noteH - 10) / rows - labelH;
    const size = Math.max(60, Math.min(cellW, cellH, n === 1 ? 300 : 999));
    const gap = size / 10 * 0.14;
    const sq = (size - gap * 9) / 10;
    const totalW = cols * size + (cols - 1) * 20;
    const left = (W - totalW) / 2;
    const offY = Math.max(0, (H - noteH - rows * (size + labelH)) / 2.4);
    items.forEach((it, k) => {
      const c = k % cols, r = Math.floor(k / cols);
      const gx = left + c * (size + 20), gy = 8 + offY + r * (size + labelH);
      const color = colorOf(it, k);
      const filled = it.share * 100;
      const g = svg.append('g').attr('transform', `translate(${gx},${gy})`);
      const cells = d3.range(100).map((i) => ({ i, col: i % 10, row: 9 - Math.floor(i / 10) }));
      g.selectAll('rect').data(cells).join('rect')
        .attr('x', (d) => d.col * (sq + gap)).attr('y', (d) => d.row * (sq + gap))
        .attr('width', sq).attr('height', sq).attr('rx', Math.min(2, sq * 0.15))
        .attr('fill', '#E9E3D7')
        .transition().delay((d) => dur(200 + k * 250 + d.i * 12)).duration(dur(200))
        .attr('fill', (d) => (d.i < Math.floor(filled) ? color : '#E9E3D7'));
      // A partly filled cell for fractions.
      const frac = filled - Math.floor(filled);
      if (frac > 0.05 && filled < 100) {
        const d = cells[Math.floor(filled)];
        g.append('rect').attr('x', d.col * (sq + gap)).attr('y', d.row * (sq + gap)).attr('height', sq).attr('rx', Math.min(2, sq * 0.15))
          .attr('fill', color).attr('width', 0)
          .transition().delay(dur(200 + k * 250 + Math.floor(filled) * 12)).duration(dur(200)).attr('width', sq * frac);
      }
      g.append('text').attr('class', 'big-figure small').attr('x', 0).attr('y', size + 26).text(it.display);
      g.append('text').attr('class', 'label-name').attr('x', 0).attr('y', size + 42).text(it.name);
    });
    if (p.annotations.length) {
      svg.append('text').attr('class', 'note-line').attr('x', W / 2).attr('text-anchor', 'middle')
        .attr('y', Math.min(H - 10, 8 + offY + rows * (size + labelH) + 18)).text(p.annotations[0].text)
        .attr('opacity', 0).transition().delay(dur(1600)).duration(dur(400)).attr('opacity', 1);
    }
  }

  // ---------------------------------------------------------------------
  // treemap and bubble_pack: many parts by size; tap for detail.

  /** Detail strip for treemap/bubble charts; partsDetail.show(i) fills it. */
  function partsDetail(items) {
    const strip = detailStrip(null);
    partsDetail.show = (i) => {
      const it = items[i];
      strip.set(`${it.shareDisplay} of the total`, `${it.name}: ${it.display}`, it.source);
    };
    return {};
  }

  function renderTreemap(p) {
    const items = p.items;
    const { svg, w: W, h: H } = layout(() => partsDetail(items));
    svg.attr('aria-label', `${p.title}. ${items.map((i) => `${i.name}: ${i.display}`).join('; ')}`);
    const data = d3.hierarchy({ children: items.map((it, i) => ({ it, i })) }).sum((d) => (d.it ? d.it.valueSi : 0));
    d3.treemap().tile(d3.treemapSquarify.ratio(1.2)).size([W - 24, H - 16]).paddingInner(2).round(true)(data);
    const g = svg.append('g').attr('transform', 'translate(12,8)');
    const leaves = g.selectAll('g').data(data.leaves()).join('g').attr('transform', (d) => `translate(${d.x0},${d.y0})`)
      .attr('role', 'button').attr('aria-label', (d) => `${d.data.it.name}: ${d.data.it.display}`)
      .on('click', (_, d) => select(d.data.i));
    leaves.append('rect').attr('width', (d) => d.x1 - d.x0).attr('height', (d) => d.y1 - d.y0)
      .attr('fill', (d) => colorOf(d.data.it, d.data.i)).attr('opacity', 0)
      .transition().delay((d) => dur(100 + d.data.i * 60)).duration(dur(450)).attr('opacity', 1);
    leaves.each(function (d) {
      const w = d.x1 - d.x0, h = d.y1 - d.y0;
      const it = d.data.it;
      const gg = d3.select(this);
      if (w < 44 || h < 26) return;
      const t = gg.append('text').attr('class', 'cell-name').attr('x', 6).attr('y', 16).text(it.name);
      if (t.node().getComputedTextLength() > w - 10) { t.text(it.name.slice(0, Math.max(1, Math.floor((w - 14) / 7))) + '…'); }
      if (h > 44) gg.append('text').attr('class', 'cell-value').attr('x', 6).attr('y', 32).text(it.shareDisplay);
      gg.attr('opacity', 0).transition().delay(dur(400 + d.data.i * 60)).duration(dur(300)).attr('opacity', 1);
    });
    function select(i) {
      leaves.select('rect').attr('stroke', (d) => (d.data.i === i ? INK : 'none')).attr('stroke-width', 2);
      partsDetail.show(i);
    }
    select(0);
  }

  function renderBubbles(p) {
    const items = p.items;
    const { svg, w: W, h: H } = layout(() => partsDetail(items));
    svg.attr('aria-label', `${p.title}. ${items.map((i) => `${i.name}: ${i.display}`).join('; ')}`);
    const data = d3.hierarchy({ children: items.map((it, i) => ({ it, i })) }).sum((d) => (d.it ? d.it.valueSi : 0));
    d3.pack().size([W - 16, H - 12]).padding(3)(data);
    const g = svg.append('g').attr('transform', 'translate(8,6)');
    const nodes = g.selectAll('g').data(data.leaves()).join('g').attr('transform', (d) => `translate(${d.x},${d.y})`)
      .attr('role', 'button').attr('aria-label', (d) => `${d.data.it.name}: ${d.data.it.display}`)
      .on('click', (_, d) => select(d.data.i));
    nodes.append('circle').attr('fill', (d) => colorOf(d.data.it, d.data.i)).attr('r', reduce() ? (d) => d.r : 0)
      .transition().delay((d) => dur(100 + d.data.i * 50)).duration(dur(600)).ease(d3.easeBackOut.overshoot(1.2)).attr('r', (d) => d.r);
    nodes.each(function (d) {
      if (d.r < 22) return;
      const gg = d3.select(this);
      const it = d.data.it;
      const t = gg.append('text').attr('class', 'cell-name').attr('text-anchor', 'middle').attr('y', d.r > 34 ? -2 : 4).text(it.name);
      if (t.node().getComputedTextLength() > d.r * 1.8) {
        if (d.r < 34) { t.remove(); return; }
        t.text(it.name.slice(0, Math.max(1, Math.floor(d.r * 1.8 / 7))) + '…');
      }
      if (d.r > 34) {
        const v = gg.append('text').attr('class', 'cell-value').attr('text-anchor', 'middle').attr('y', 14).text(it.display);
        if (v.node().getComputedTextLength() > d.r * 1.75) v.text(it.shareDisplay);
      }
      gg.selectAll('text').attr('opacity', 0).transition().delay(dur(600 + d.data.i * 50)).duration(dur(300)).attr('opacity', 1);
    });
    function select(i) {
      nodes.select('circle').attr('stroke', (d) => (d.data.i === i ? INK : 'none')).attr('stroke-width', 2);
      partsDetail.show(i);
    }
    select(0);
  }

  // ---------------------------------------------------------------------
  // lollipop: a ranking, largest first.

  function renderLollipop(p) {
    const items = p.items;
    const n = items.length;
    const { svg, stage, w: W, h: H0 } = layout();
    const log = p.scale === 'log';
    const noteH = p.annotations.length ? 30 : 0;
    const rowH = Math.max(26, Math.min(44, (H0 - 30 - noteH) / n));
    const H = Math.max(H0, 30 + rowH * n + 8 + noteH);
    if (H > H0) {
      // Too many rows to fit: scroll vertically.
      svg.remove();
      const sc = vscroll(stage);
      return drawLollipop(p, sc.append('svg').attr('width', W).attr('height', H), W, H, rowH, log);
    }
    drawLollipop(p, svg, W, H, rowH, log);
  }

  function drawLollipop(p, svg, W, H, rowH, log) {
    const items = p.items;
    svg.attr('role', 'img').attr('aria-label', `${p.title}. ${items.map((i, k) => `${k + 1}. ${i.name}: ${i.display}`).join('; ')}`);
    const valueW = Math.max(...items.map((i) => textWidth(svg, i.display, 'label-value')));
    const m = { l: 16, r: 16 + valueW + 10, t: 26 };
    const vals = items.map((i) => i.valueSi);
    const max = d3.max(vals);
    const ax = K.unitAxis(p.units, 0, max, 3);
    const x = log
      ? d3.scaleLog().domain([d3.min(vals) / 2, max]).range([m.l, W - m.r])
      : d3.scaleLinear().domain([0, max]).range([m.l, W - m.r]);
    const la = log ? K.logAxis(p.units, x.domain()[0], max, 4) : null;
    const fmt = log ? la.fmt : ax.fmt;
    const ticks = thinTicks(svg, x, log ? la.ticks : ax.ticks.filter((t) => t <= max), fmt);
    svg.append('g').attr('class', 'grid').selectAll('line').data(ticks).join('line')
      .attr('x1', x).attr('x2', x).attr('y1', m.t - 4).attr('y2', m.t + rowH * items.length - 4);
    svg.append('g').attr('class', 'axis').attr('transform', `translate(0,${m.t - 8})`)
      .call(d3.axisTop(x).tickValues(ticks).tickSize(0).tickFormat(fmt)).call(edgeTicks);
    const x0 = x.range()[0];
    const obstacles = [];
    const rows = svg.append('g').selectAll('g').data(items).join('g').attr('transform', (_, i) => `translate(0,${m.t + i * rowH})`);
    rows.each(function (it, i) {
      const g = d3.select(this);
      const color = i === 0 ? ACCENT : INK2;
      const cy = rowH - 9;
      const xe = x(Math.max(it.valueSi, x.domain()[0]));
      g.append('text').attr('class', 'label-name').attr('x', m.l).attr('y', cy - 7).text(`${i + 1}. ${it.name}`);
      g.append('line').attr('x1', x0).attr('x2', x0).attr('y1', cy).attr('y2', cy).attr('stroke', color).attr('stroke-width', 1.5)
        .transition().delay(dur(100 + i * 70)).duration(dur(700)).ease(d3.easeCubicOut).attr('x2', xe);
      g.append('circle').attr('cy', cy).attr('r', 4.5).attr('fill', color).attr('cx', x0)
        .transition().delay(dur(100 + i * 70)).duration(dur(700)).ease(d3.easeCubicOut).attr('cx', xe);
      g.append('text').attr('class', 'label-value').attr('y', cy + 4).attr('x', xe + 9).text(it.display)
        .attr('opacity', 0).transition().delay(dur(600 + i * 70)).duration(dur(300)).attr('opacity', 1);
      const top = m.t + i * rowH;
      obstacles.push({ x0: m.l, x1: xe + 12 + valueW, y0: top + cy - 18, y1: top + cy + 6 });
      it._anchor = { x: xe, y: top + cy };
    });
    void obstacles;
    if (p.annotations.length) noteLine(svg, p.annotations[0].text, 16, H - 8, 'up', 900 + items.length * 70);
  }

  // ---------------------------------------------------------------------
  // number_line: values on one vertical axis, largest at the top.

  function renderNumberLine(p) {
    const items = p.items;
    const { svg, w: W, h: H } = layout();
    svg.attr('aria-label', `${p.title}. ${items.map((i) => `${i.name}: ${i.display}`).join('; ')}`);
    const log = p.scale === 'log';
    const vals = items.map((i) => i.valueSi);
    const lo = d3.min(vals), hi = d3.max(vals);
    const m = { t: 18, b: p.annotations.length ? 44 : 18 };
    const axisX = Math.min(96, W * 0.27);
    const y = log
      ? d3.scaleLog().domain([lo / 1.6, hi * 1.6]).range([H - m.b, m.t])
      : d3.scaleLinear().domain([0, K.unitAxis(p.units, 0, hi, 5).max]).range([H - m.b, m.t]);
    const axis = log ? K.logAxis(p.units, y.domain()[0], y.domain()[1], 7) : K.unitAxis(p.units, 0, hi, 5);
    const ticks = axis.ticks;
    const fmt = axis.fmt;
    svg.append('line').attr('x1', axisX).attr('x2', axisX).attr('y1', m.t - 6).attr('y2', H - m.b + 6).attr('stroke', INK).attr('stroke-width', 1.2);
    const tg = svg.append('g').selectAll('g').data(ticks).join('g').attr('transform', (t) => `translate(${axisX},${y(t)})`);
    tg.append('line').attr('x1', -5).attr('x2', 0).attr('stroke', INK);
    tg.append('text').attr('class', 'axis-label').attr('x', -9).attr('dy', '0.32em').attr('text-anchor', 'end').text(fmt);

    const labelH = 31;
    const ys = spread(items.map((it) => y(it.valueSi)), labelH, m.t - 10, H - m.b + 14);
    const lx = axisX + 46;
    items.forEach((it, i) => {
      const yy = y(it.valueSi);
      const color = PALETTE[i % PALETTE.length];
      const g = svg.append('g').attr('opacity', 0);
      g.append('path').attr('d', `M${axisX},${yy}C${axisX + 22},${yy} ${lx - 22},${ys[i]} ${lx - 6},${ys[i]}`)
        .attr('fill', 'none').attr('stroke', RULE);
      g.append('circle').attr('cx', axisX).attr('cy', yy).attr('r', 5).attr('fill', color).attr('stroke', PAPER).attr('stroke-width', 1.5);
      g.append('text').attr('class', 'label-name').attr('x', lx).attr('y', ys[i] - 2).text(it.name);
      g.append('text').attr('class', 'label-value').attr('x', lx).attr('y', ys[i] + 13).text(it.display);
      g.transition().delay(dur(150 + i * 140)).duration(dur(400)).attr('opacity', 1);
    });
    if (p.annotations.length) {
      noteLine(svg, p.annotations[0].text, 16, H - 6, 'up', 400 + items.length * 140);
    }
  }

  // ---------------------------------------------------------------------
  // slope: before → after.

  function commonYear(rows, side) {
    const ys = rows.map((r) => r[side].year);
    return ys.every((y) => y != null && y === ys[0]) ? yearLabel(ys[0]) : null;
  }

  function renderSlope(p) {
    const rows = p.rows;
    const { svg, w: W, h: H } = layout();
    svg.attr('aria-label', `${p.title}. ${rows.map((r) => `${r.label}: ${r.a.display} to ${r.b.display}`).join('; ')}`);
    const aHead = p.aName || commonYear(rows, 'a') || 'Before';
    const bHead = p.bName || commonYear(rows, 'b') || 'After';
    const vals = rows.flatMap((r) => [r.a.valueSi, r.b.valueSi]);
    const lo = d3.min(vals), hi = d3.max(vals);
    const log = lo > 0 && hi / lo > 60;
    const single = rows.length === 1;
    // Label columns are capped so the slopes always get the middle third.
    const aW = Math.max(...rows.map((r) => textWidth(svg, r.a.display, 'label-value')));
    const bW = Math.max(...rows.map((r) => Math.max(textWidth(svg, r.b.display, 'label-value'),
      r.change ? textWidth(svg, r.change, 'label-change') : 0)));
    const nameW = single ? 0 : Math.max(...rows.map((r) => textWidth(svg, r.label, 'label-name')));
    const leftW = Math.min(W * 0.34, Math.max(aW, nameW));
    const xa = 16 + leftW + 10;
    const xb = W - 16 - Math.min(W * 0.3, bW) - 10;
    const m = { t: 46, b: 22 };
    const y = log
      ? d3.scaleLog().domain([lo, hi]).range([H - m.b, m.t])
      : d3.scaleLinear().domain([Math.min(lo, 0), hi]).range([H - m.b, m.t]);
    // Column heads lean outward so long names don't meet in the middle, but
    // stay inside the chart; anything still too long is shortened.
    const mid = (xa + xb) / 2;
    const head = (text, anchorX, side) => {
      const t = svg.append('text').attr('class', 'kicker').attr('y', 20).text(text);
      const room = side === 'a' ? mid - 4 - 16 : W - 16 - (mid + 4);
      while (t.node().getComputedTextLength() > room && t.text().length > 3) t.text(t.text().slice(0, -2) + '…');
      const w = t.node().getComputedTextLength();
      if (side === 'a') t.attr('text-anchor', 'end').attr('x', Math.min(mid - 4, Math.max(anchorX, 16 + w)));
      else t.attr('text-anchor', 'start').attr('x', Math.max(mid + 4, Math.min(anchorX, W - 16 - w)));
    };
    head(aHead, xa + 4, 'a');
    head(bHead, xb - 4, 'b');
    for (const xx of [xa, xb]) svg.append('line').attr('x1', xx).attr('x2', xx).attr('y1', 30).attr('y2', H - m.b + 8).attr('stroke', RULE);
    const lh = single ? 20 : 30;
    const ya = spread(rows.map((r) => y(r.a.valueSi)), lh, 30, H);
    const yb = spread(rows.map((r) => y(r.b.valueSi)), lh, 30, H);
    const obstacles = [];
    rows.forEach((r, i) => {
      const color = rows.length <= 2 || i === 0 ? PALETTE[i % PALETTE.length] : PALETTE[i % PALETTE.length];
      const y0 = y(r.a.valueSi), y1 = y(r.b.valueSi);
      const g = svg.append('g');
      const line = g.append('line').attr('x1', xa).attr('y1', y0).attr('x2', xa).attr('y2', y0).attr('stroke', color).attr('stroke-width', 2.2);
      line.transition().delay(dur(200 + i * 120)).duration(dur(900)).ease(d3.easeCubicInOut).attr('x2', xb).attr('y2', y1);
      g.append('circle').attr('cx', xa).attr('cy', y0).attr('r', 4.5).attr('fill', color);
      g.append('circle').attr('cx', xb).attr('cy', y1).attr('r', 4.5).attr('fill', color).attr('opacity', 0)
        .transition().delay(dur(1000 + i * 120)).duration(dur(200)).attr('opacity', 1);
      g.append('text').attr('class', 'label-value').attr('x', xa - 9).attr('y', ya[i] + (single ? 4 : 13)).attr('text-anchor', 'end').text(r.a.display);
      if (!single) {
        const t = g.append('text').attr('class', 'label-name').attr('x', xa - 9).attr('y', ya[i] - 2).attr('text-anchor', 'end').text(r.label);
        while (t.node().getComputedTextLength() > leftW && t.text().length > 4) t.text(t.text().slice(0, -2) + '…');
      }
      const right = g.append('g').attr('opacity', 0);
      right.append('text').attr('class', 'label-value').attr('x', xb + 9).attr('y', yb[i] + (single ? 4 : -1)).text(r.b.display);
      if (r.change && !single) right.append('text').attr('class', 'label-change').attr('x', xb + 9).attr('y', yb[i] + 14).text(r.change);
      right.transition().delay(dur(1000 + i * 120)).duration(dur(300)).attr('opacity', 1);
      obstacles.push({ x0: xa - aW - 12, x1: xa, y0: ya[i] - 14, y1: ya[i] + 16 }, { x0: xb, x1: W, y0: yb[i] - 14, y1: yb[i] + 16 });
      r._anchor = { x: (xa + xb) / 2, y: (y0 + y1) / 2 };
    });
    const gNote = svg.append('g').attr('class', 'annotation-group').attr('opacity', 0);
    // With several rows the change is already printed beside each line.
    if (single) {
      annotate(gNote, p.annotations, p.annotations.map((a) => (rows[a.index] ? rows[a.index]._anchor : null)),
        { x: xa + 4, y: 30, w: xb - xa - 8, h: H - 40 }, obstacles, { wrap: Math.max(90, xb - xa - 20) });
    }
    gNote.transition().delay(dur(1300 + rows.length * 120)).duration(dur(400)).attr('opacity', 1);
  }

  // ---------------------------------------------------------------------
  // range_bars: low–high spans.

  function renderRange(p) {
    const rows = p.rows;
    const { svg, w: W, h: H } = layout();
    svg.attr('aria-label', `${p.title}. ${rows.map((r) => `${r.label}: ${r.a.display} to ${r.b.display}`).join('; ')}`);
    const lo = d3.min(rows, (r) => r.a.valueSi), hi = d3.max(rows, (r) => r.b.valueSi);
    const log = lo > 0 && hi / lo > 200;
    const m = { l: 16, r: 16, t: 28 };
    const ax = K.unitAxis(p.units, 0, hi, 4);
    const x = log ? d3.scaleLog().domain([lo / 1.5, hi * 1.2]).range([m.l, W - m.r])
      : d3.scaleLinear().domain([0, ax.max]).range([m.l, W - m.r]);
    const la = log ? K.logAxis(p.units, x.domain()[0], x.domain()[1], 4) : null;
    const fmt = log ? la.fmt : ax.fmt;
    const ticks = thinTicks(svg, x, log ? la.ticks : ax.ticks, fmt);
    const noteH = p.annotations.length ? 34 : 0;
    const rowH = Math.min(50, (H - m.t - 6 - noteH) / rows.length);
    m.t += Math.max(0, (H - noteH - m.t - rowH * rows.length) / 3);
    svg.append('g').attr('class', 'grid').selectAll('line').data(ticks).join('line')
      .attr('x1', x).attr('x2', x).attr('y1', m.t - 4).attr('y2', m.t + rowH * rows.length);
    svg.append('g').attr('class', 'axis').attr('transform', `translate(0,${m.t - 8})`)
      .call(d3.axisTop(x).tickValues(ticks).tickSize(0).tickFormat(fmt)).call(edgeTicks);
    const obstacles = [];
    rows.forEach((r, i) => {
      const top = m.t + i * rowH;
      const cy = top + Math.min(rowH * 0.62, 30);
      const color = PALETTE[i % PALETTE.length];
      const xa = x(Math.max(r.a.valueSi, x.domain()[0])), xb = x(r.b.valueSi);
      const g = svg.append('g');
      g.append('text').attr('class', 'label-name').attr('x', m.l).attr('y', top + 13).text(r.label);
      const valueText = r.a.display === r.b.display ? r.a.display : `${r.a.display} – ${r.b.display}`;
      const vt = g.append('text').attr('class', 'label-value').attr('x', W - m.r).attr('y', top + 13).attr('text-anchor', 'end').text(valueText);
      const mid = (xa + xb) / 2;
      g.append('rect').attr('y', cy - 5).attr('height', 10).attr('rx', 5).attr('fill', color).attr('opacity', 0.85)
        .attr('x', mid).attr('width', 0)
        .transition().delay(dur(150 + i * 100)).duration(dur(700)).ease(d3.easeCubicOut).attr('x', xa - 5).attr('width', Math.max(10, xb - xa + 10));
      obstacles.push({ x0: m.l, x1: W - m.r, y0: top, y1: top + 16, w: 6 }, { x0: xa - 6, x1: xb + 6, y0: cy - 7, y1: cy + 7 });
      void vt;
      r._anchor = { x: xb, y: cy };
    });
    void obstacles;
    if (p.annotations.length) noteLine(svg, p.annotations[0].text, 16, m.t + rowH * rows.length + 22, 'down', 900 + rows.length * 100);
  }

  // ---------------------------------------------------------------------
  // versus: two subjects head to head, attribute by attribute.

  function renderVersus(p) {
    const rows = p.rows;
    const { svg, w: W, h: H } = layout();
    svg.attr('aria-label', `${p.aName} versus ${p.bName}. ${rows.map((r) => `${r.label}: ${r.a.display} vs ${r.b.display}`).join('; ')}`);
    const cx = W / 2;
    const headH = p.aImage || p.bImage ? 86 : 52;
    const colA = PALETTE[0], colB = PALETTE[1];
    // Header: names (and pictures) on each side.
    const head = svg.append('g');
    const side = (name, image, color, x, anchor) => {
      if (image) icon(head, image, color, anchor === 'end' ? x - 64 : x, 6, 64, 40);
      head.append('text').attr('class', 'vs-name').attr('x', x + (anchor === 'end' ? 0 : 0)).attr('y', headH - 14)
        .attr('text-anchor', anchor).attr('fill', color).text(name);
    };
    side(p.aName, p.aImage, colA, cx - 22, 'end');
    side(p.bName, p.bImage, colB, cx + 22, 'start');
    head.append('text').attr('class', 'vs-mark').attr('x', cx).attr('y', headH - 14).attr('text-anchor', 'middle').text('vs');
    const rowH = Math.min(74, (H - headH - 6) / rows.length);
    const half = cx - 18;
    const offY = Math.max(0, (H - headH - 6 - rowH * rows.length) / 3);
    head.attr('transform', `translate(0,${offY})`);
    rows.forEach((r, i) => {
      const top = offY + headH + 6 + i * rowH;
      const g = svg.append('g').attr('transform', `translate(0,${top})`);
      g.append('line').attr('x1', 16).attr('x2', W - 16).attr('y1', 0).attr('y2', 0).attr('stroke', RULE);
      g.append('text').attr('class', 'label-faint caps').attr('x', cx).attr('y', 17).attr('text-anchor', 'middle').text(r.label);
      const max = Math.max(r.a.valueSi, r.b.valueSi) || 1;
      const by = 26, bh = Math.max(8, Math.min(14, rowH * 0.2));
      const wa = (r.a.valueSi / max) * (half - 8), wb = (r.b.valueSi / max) * (half - 8);
      g.append('rect').attr('y', by).attr('height', bh).attr('fill', colA).attr('opacity', r.winner === 'b' ? 0.45 : 1)
        .attr('x', cx - 4).attr('width', 0)
        .transition().delay(dur(200 + i * 160)).duration(dur(750)).ease(d3.easeCubicOut).attr('x', cx - 4 - wa).attr('width', Math.max(1, wa));
      g.append('rect').attr('y', by).attr('height', bh).attr('fill', colB).attr('opacity', r.winner === 'a' ? 0.45 : 1)
        .attr('x', cx + 4).attr('width', 0)
        .transition().delay(dur(200 + i * 160)).duration(dur(750)).ease(d3.easeCubicOut).attr('width', Math.max(1, wb));
      const vy = by + bh + 15;
      g.append('text').attr('class', r.winner === 'a' ? 'label-value strong' : 'label-value').attr('x', cx - 6).attr('y', vy)
        .attr('text-anchor', 'end').text(r.a.display);
      g.append('text').attr('class', r.winner === 'b' ? 'label-value strong' : 'label-value').attr('x', cx + 6).attr('y', vy).text(r.b.display);
      if (r.ratio) {
        const winX = r.winner === 'a' ? 16 : W - 16;
        g.append('text').attr('class', 'label-change').attr('x', winX).attr('y', vy).attr('text-anchor', r.winner === 'a' ? 'start' : 'end')
          .text(r.ratio).attr('opacity', 0).transition().delay(dur(900 + i * 160)).duration(dur(300)).attr('opacity', 1);
      }
    });
  }

  // ---------------------------------------------------------------------
  // rate_counter: what happens while you watch.

  function renderRate(p) {
    const rows = p.rows;
    const stage = root.append('div').attr('class', 'stage counter-stage');
    const wrap = stage.append('div').attr('class', 'counters' + (rows.length === 1 ? ' single' : ''))
      .attr('role', 'img').attr('aria-label', `${p.title}. ${rows.map((r) => `${r.label}: ${r.rateDisplay}`).join('; ')}`);
    wrap.append('div').attr('class', 'since').text('Since you opened this');
    const cells = rows.map((r, i) => {
      const c = wrap.append('div').attr('class', 'counter');
      const num = c.append('div').attr('class', 'count').style('color', i === 0 ? ACCENT : INK);
      c.append('div').attr('class', 'what').text(r.label);
      c.append('div').attr('class', 'rate').text(r.rateDisplay);
      return { r, num, last: -1 };
    });
    const clock = wrap.append('div').attr('class', 'elapsed');
    const fmtCount = (r, v) => {
      const s = r.suffix;
      // Whole things are counted whole; measured amounts (t, km², USD) keep
      // enough decimals to visibly move.
      const decimals = !s || r.perSecond >= 10 ? 0 : r.perSecond >= 1 ? 1 : r.perSecond >= 0.01 ? 3 : 5;
      const n = decimals === 0 ? fmtNumber(Math.floor(v)) : v.toLocaleString('en-US', { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
      if (!s) return n;
      if (s === 'USD') return '$' + n;
      if (s === 'EUR') return '€' + n;
      return `${n} ${s}`;
    };
    const start = performance.now();
    const update = () => {
      const t = (performance.now() - start) / 1000;
      for (const c of cells) {
        const v = c.r.perSecond * t;
        c.num.text(fmtCount(c.r, v));
        const whole = Math.floor(v);
        if (whole !== c.last && !reduce() && c.r.perSecond < 15) {
          c.num.classed('bump', false);
          void c.num.node().offsetWidth;
          c.num.classed('bump', true);
        }
        c.last = whole;
      }
      const s = Math.floor(t);
      clock.text(s < 60 ? `${s} s` : `${Math.floor(s / 60)} min ${s % 60} s`);
    };
    update();
    if (reduce()) {
      const id = setInterval(update, 1000);
      track({ stop: () => clearInterval(id) });
    } else {
      track(d3.timer(update));
    }
  }

  // ---------------------------------------------------------------------
  // pictogram: how many of one thing make another.

  function renderPictogram(p) {
    const { svg, w: W, h: H } = layout();
    svg.attr('aria-label', `${p.title}. ${p.headline}. ${p.total.name}: ${p.total.display}; one ${p.unit.name}: ${p.unit.display}`);
    const count = p.count;
    // Each icon stands for 1, 10 or 100 units so the grid stays legible.
    const per = count > 1000 ? 100 : count > 200 ? 10 : 1;
    const icons = count / per;
    const full = Math.floor(icons + 1e-9);
    const frac = icons - full;
    const n = full + (frac > 0.02 ? 1 : 0);
    const headH = 64, footH = per > 1 ? 44 : 28;
    svg.append('text').attr('class', 'big-figure').attr('x', 16).attr('y', 34).text(`${p.countDisplay}`);
    const bigW = textWidth(svg, p.countDisplay, 'big-figure');
    svg.append('text').attr('class', 'label-name').attr('x', 16 + bigW + 8).attr('y', 22).text(p.unit.name);
    svg.append('text').attr('class', 'label-value').attr('x', 16 + bigW + 8).attr('y', 38).text(`= ${p.totalPhrase}`);

    const sil = p.image && p.image.kind === 'silhouette' ? window.FactvizSilhouettes[p.image.key] : null;
    const aspect = sil ? sil.box[2] / sil.box[3] : 1;
    const areaW = W - 32, areaH = H - headH - footH;
    // Choose the column count that makes icons largest.
    let best = { size: 0, cols: 1 };
    for (let cols = 1; cols <= n; cols++) {
      const rows = Math.ceil(n / cols);
      const cw = areaW / cols, ch = areaH / rows;
      const s = Math.min(cw / 1.18, (ch / 1.18) * aspect);
      if (s > best.size) best = { size: s, cols };
    }
    const iw = Math.max(3, best.size), ih = iw / aspect;
    const cw = areaW / best.cols;
    const ch = ih * 1.18;
    const g = svg.append('g').attr('transform', `translate(16,${headH})`);
    const step = Math.max(4, Math.min(60, 1800 / n));
    for (let k = 0; k < n; k++) {
      const c = k % best.cols, r = Math.floor(k / best.cols);
      const x = c * cw + (cw - iw) / 2, y = r * ch;
      const part = k === full ? frac : 1;
      const cell = g.append('g').attr('opacity', 0);
      if (part < 1) {
        const id = `clip-${k}`;
        // Clip coordinates are in the icon's own space (inside the grid group).
        svg.append('clipPath').attr('id', id).append('rect').attr('x', x).attr('y', y - 2).attr('width', iw * part).attr('height', ih + 4);
        cell.attr('clip-path', `url(#${id})`);
        // Ghost outline of the whole icon.
        drawIcon(g.append('g').attr('opacity', 0.18), sil, p.image, x, y, iw, ih);
      }
      drawIcon(cell, sil, p.image, x, y, iw, ih);
      // Each icon pops up from its own base with a little spring.
      const cx = x + iw / 2, by = y + ih;
      const at = (sc) => `translate(${cx},${by}) scale(${sc}) translate(${-cx},${-by})`;
      if (reduce()) cell.attr('opacity', 1);
      else {
        cell.attr('transform', at(0.01)).transition().delay(150 + k * step).duration(420)
          .ease(d3.easeBackOut.overshoot(1.8)).attr('opacity', 1).attr('transform', at(1));
      }
    }
    const foot = svg.append('g').attr('transform', `translate(16,${H - footH + 14})`);
    if (per > 1) foot.append('text').attr('class', 'label-faint').attr('y', 0).text(`Each icon = ${per} ${p.unit.name}`);
    foot.append('text').attr('class', 'label-faint').attr('y', per > 1 ? 16 : 0)
      .text(`${p.total.label}: ${p.total.display} · ${p.unit.label}: ${p.unit.display}`);
  }

  function drawIcon(g, sil, image, x, y, w, h) {
    if (sil) {
      const s = K.silhouette(g, image.key, INK);
      K.placeSilhouette(s.g.node(), s.box, x, y, w, h);
      return;
    }
    if (image && image.kind === 'photo') {
      g.append('image').attr('href', image.src).attr('x', x).attr('y', y).attr('width', w).attr('height', h);
      return;
    }
    g.append('rect').attr('x', x).attr('y', y).attr('width', w).attr('height', h).attr('rx', Math.min(w, h) * 0.22).attr('fill', ACCENT);
  }

  // ---------------------------------------------------------------------
  // line_series: values across years; drag to read off a year.

  function renderLines(p) {
    const series = p.series;
    const readout = { el: null };
    const { svg, w: W, h: H } = layout(() => {
      readout.el = root.append('div').attr('class', 'detail');
      return {};
    });
    svg.attr('aria-label', `${p.title}. ${series.map((s) => `${s.name}: ${s.points.map((pt) => `${pt.year} ${pt.display}`).join(', ')}`).join('; ')}`);
    const log = p.scale === 'log';
    const all = series.flatMap((s) => s.points);
    const years = all.map((pt) => pt.year);
    const vals = all.map((pt) => pt.valueSi);
    const hi = d3.max(vals);
    const endW = Math.min(W * 0.34, Math.max(...series.map((s) => Math.max(
      textWidth(svg, s.points[s.points.length - 1].display, 'label-value'),
      series.length > 1 ? textWidth(svg, s.name, 'label-name') : 0)))) + 12;
    const m = { l: 16, r: endW + 6, t: 16, b: 26 };
    const x = d3.scaleLinear().domain(d3.extent(years)).range([m.l, W - m.r]);
    // Lines show change, so the axis need not start at zero.
    const ax = K.unitAxis(p.units, d3.min(vals), hi, 4, false);
    const y = log ? d3.scaleLog().domain([d3.min(vals), hi]).nice().range([H - m.b, m.t])
      : d3.scaleLinear().domain([ax.min, ax.max]).range([H - m.b, m.t]);
    const la = log ? K.logAxis(p.units, y.domain()[0], y.domain()[1], 5) : null;
    const yt = log ? la.ticks : ax.ticks;
    const fmt = log ? la.fmt : ax.fmt;
    svg.append('g').attr('class', 'grid').selectAll('line').data(yt).join('line')
      .attr('x1', m.l).attr('x2', W - m.r).attr('y1', y).attr('y2', y);
    svg.append('g').selectAll('text').data(yt).join('text').attr('class', 'axis-label halo').attr('x', m.l).attr('y', (t) => y(t) - 4).text(fmt);
    const xt = x.ticks(Math.min(5, Math.floor((W - m.l - m.r) / 60))).filter((t) => Number.isInteger(t));
    svg.append('g').attr('class', 'axis').attr('transform', `translate(0,${H - m.b + 4})`)
      .call(d3.axisBottom(x).tickValues(xt).tickSize(0).tickFormat(yearLabel));
    svg.append('line').attr('class', 'baseline').attr('x1', m.l).attr('x2', W - m.r).attr('y1', H - m.b).attr('y2', H - m.b);

    const line = d3.line().x((pt) => x(pt.year)).y((pt) => y(pt.valueSi)).curve(d3.curveMonotoneX);
    const ends = spread(series.map((s) => y(s.points[s.points.length - 1].valueSi)), series.length > 1 ? 30 : 16, m.t - 6, H - m.b);
    series.forEach((s, i) => {
      const color = PALETTE[i % PALETTE.length];
      const path = svg.append('path').datum(s.points).attr('d', line).attr('fill', 'none').attr('stroke', color).attr('stroke-width', 2.4)
        .attr('stroke-linejoin', 'round').attr('stroke-linecap', 'round');
      const len = path.node().getTotalLength();
      if (!reduce()) {
        path.attr('stroke-dasharray', `${len} ${len}`).attr('stroke-dashoffset', len)
          .transition().delay(200 + i * 200).duration(1600).ease(d3.easeCubicInOut).attr('stroke-dashoffset', 0)
          .on('end', () => path.attr('stroke-dasharray', null));
      }
      if (s.points.length <= 24) {
        svg.append('g').selectAll('circle').data(s.points).join('circle').attr('cx', (pt) => x(pt.year)).attr('cy', (pt) => y(pt.valueSi))
          .attr('r', 2.6).attr('fill', PAPER).attr('stroke', color).attr('stroke-width', 1.6)
          .attr('opacity', 0).transition().delay((_, k) => dur(200 + i * 200 + (1600 * k) / s.points.length)).duration(dur(150)).attr('opacity', 1);
      }
      const last = s.points[s.points.length - 1];
      const lab = svg.append('g').attr('transform', `translate(${W - m.r + 8},${ends[i]})`).attr('opacity', 0);
      if (series.length > 1) lab.append('text').attr('class', 'label-name').attr('y', -2).attr('fill', color).text(s.name);
      lab.append('text').attr('class', 'label-value').attr('y', series.length > 1 ? 13 : 4).text(last.display);
      lab.transition().delay(dur(1700 + i * 200)).duration(dur(300)).attr('opacity', 1);
      s._color = color;
    });

    const gNote = svg.append('g').attr('class', 'annotation-group').attr('opacity', 0);
    annotate(gNote, p.annotations, p.annotations.map((a) => {
      const s = series[a.index];
      const pt = s && s.points[a.index2 == null ? s.points.length - 1 : a.index2];
      return pt ? { x: x(pt.year), y: y(pt.valueSi) } : null;
    }), { x: m.l, y: m.t, w: W - m.r - m.l, h: H - m.t - m.b },
    series.flatMap((s) => {
      // The line itself, sampled as small boxes, is what the note must not cover.
      const out = [];
      for (let k = 0; k + 1 < s.points.length; k++) {
        const a = s.points[k], b = s.points[k + 1];
        for (let t = 0; t <= 1; t += 0.25) {
          const px = x(a.year + (b.year - a.year) * t), py = y(a.valueSi + (b.valueSi - a.valueSi) * t);
          out.push({ x0: px - 6, x1: px + 6, y0: py - 6, y1: py + 6, w: 4 });
        }
      }
      return out;
    }), { wrap: 150 });
    gNote.transition().delay(dur(2000)).duration(dur(400)).attr('opacity', 1);

    // Scrubbing.
    const rule = svg.append('line').attr('y1', m.t).attr('y2', H - m.b).attr('stroke', INK).attr('stroke-dasharray', '2 3').attr('opacity', 0);
    const hint = () => {
      readout.el.html('').append('div').attr('class', 'hint').text('Drag across the chart to read a year.');
    };
    hint();
    const yearsSorted = Array.from(new Set(years)).sort((a, b) => a - b);
    const scrub = (ev) => {
      const [px] = d3.pointer(ev, svg.node());
      const yr = x.invert(px);
      const near = yearsSorted.reduce((a, b) => (Math.abs(b - yr) < Math.abs(a - yr) ? b : a));
      rule.attr('x1', x(near)).attr('x2', x(near)).attr('opacity', 1);
      readout.el.html('');
      readout.el.append('div').attr('class', 'date').text(yearLabel(near));
      const parts = series.map((s) => {
        const pt = s.points.find((q) => q.year === near);
        return pt ? `${series.length > 1 ? s.name + ': ' : ''}${pt.display}` : null;
      }).filter(Boolean);
      readout.el.append('div').attr('class', 'title').text(parts.join(' · '));
      const src = series.map((s) => s.points.find((q) => q.year === near)).filter(Boolean)[0];
      if (src) readout.el.append('div').attr('class', 'desc').text(src.source);
    };
    svg.append('rect').attr('x', m.l).attr('y', m.t).attr('width', W - m.l - m.r).attr('height', H - m.t - m.b)
      .attr('fill', 'transparent').style('touch-action', 'pan-y')
      .on('pointerdown pointermove', scrub);
  }

  // ---------------------------------------------------------------------
  // cosmic_clock: a long history squeezed into one day.

  function renderClock(p) {
    const events = p.events;
    const n = events.length;
    const stage = root.append('div').attr('class', 'stage clock-stage');
    const W = stage.node().clientWidth, H = stage.node().clientHeight;
    const dialH = Math.min(W * 0.78, H * 0.52);
    const svg = stage.append('svg').attr('role', 'img').attr('height', dialH + 28).style('height', `${dialH + 28}px`)
      .attr('aria-label', `${p.title}. ${events.map((e) => `${e.label} at ${e.clock}`).join('; ')}`);
    const list = stage.append('ol').attr('class', 'clock-list').style('top', `${dialH + 30}px`);
    const r = dialH / 2 - 16;
    const cx = W / 2, cy = dialH / 2 + 4;
    const ang = (f) => -Math.PI / 2 + f * 2 * Math.PI;
    const pt = (f, rr) => [cx + rr * Math.cos(ang(f)), cy + rr * Math.sin(ang(f))];
    svg.append('circle').attr('cx', cx).attr('cy', cy).attr('r', r).attr('fill', '#FBF9F5').attr('stroke', INK).attr('stroke-width', 1.2);
    for (let h = 0; h < 24; h++) {
      const major = h % 6 === 0;
      const [x0, y0] = pt(h / 24, r - (major ? 9 : 5)), [x1, y1] = pt(h / 24, r);
      svg.append('line').attr('x1', x0).attr('y1', y0).attr('x2', x1).attr('y2', y1).attr('stroke', major ? INK : INK3);
      if (major) {
        const [lx, ly] = pt(h / 24, r - 20);
        svg.append('text').attr('class', 'axis-label').attr('x', lx).attr('y', ly).attr('dy', '0.35em').attr('text-anchor', 'middle')
          .text(`${String(h).padStart(2, '0')}:00`);
      }
    }
    svg.append('text').attr('class', 'note-line').attr('x', cx).attr('y', dialH + 22).attr('text-anchor', 'middle').text(p.scaleNote);
    const marks = svg.append('g').selectAll('g').data(events).join('g').attr('opacity', 0);
    marks.append('line').each(function (e, i) {
      const [x0, y0] = pt(e.dayFraction, r - 2), [x1, y1] = pt(e.dayFraction, r + 9);
      d3.select(this).attr('x1', x0).attr('y1', y0).attr('x2', x1).attr('y2', y1)
        .attr('stroke', i === n - 1 ? ACCENT : PALETTE[1]).attr('stroke-width', 2);
    });
    marks.append('circle').each(function (e, i) {
      const [x, y] = pt(e.dayFraction, r + 11);
      d3.select(this).attr('cx', x).attr('cy', y).attr('r', 2.5).attr('fill', i === n - 1 ? ACCENT : PALETTE[1]);
    });
    const hand = svg.append('line').attr('x1', cx).attr('y1', cy).attr('stroke', ACCENT).attr('stroke-width', 2).attr('stroke-linecap', 'round');
    svg.append('circle').attr('cx', cx).attr('cy', cy).attr('r', 4).attr('fill', ACCENT);
    const centre = svg.append('text').attr('class', 'clock-time').attr('x', cx).attr('y', cy + r * 0.42).attr('text-anchor', 'middle');

    const items = list.selectAll('li').data(events).join('li').attr('class', 'pending');
    items.append('span').attr('class', 't').text((e) => e.clock);
    const body = items.append('span').attr('class', 'b');
    body.append('span').attr('class', 'l').text((e) => e.label);
    body.append('span').attr('class', 'd').text((e) => `${e.date} · ${e.before}`);

    const setHand = (f) => {
      const [x, y] = pt(f, r - 12);
      hand.attr('x2', x).attr('y2', y);
      const secs = Math.min(86399, Math.floor(f * 86400));
      const two = (v) => String(v).padStart(2, '0');
      centre.text(`${two(Math.floor(secs / 3600))}:${two(Math.floor((secs % 3600) / 60))}:${two(secs % 60)}`);
      let current = -1;
      events.forEach((e, i) => { if (e.dayFraction <= f + 1e-12) current = i; });
      marks.attr('opacity', (_, i) => (i <= current ? 1 : 0));
      items.attr('class', (_, i) => (i === current ? 'active' : i < current ? 'done' : 'pending'));
      return current;
    };
    let shown = -1;
    const scrollTo = (i) => {
      const node = items.nodes()[i];
      if (node) list.node().scrollTop = Math.max(0, node.offsetTop - list.node().clientHeight / 2);
    };
    if (reduce()) {
      shown = setHand(1 - 1e-9);
      scrollTo(n - 1);
      return;
    }
    // The hand sweeps the day; it slows down near midnight, where history crowds.
    const total = 7000;
    const ease = (t) => 1 - Math.pow(1 - t, 2.4);
    track(d3.timer((e) => {
      const t = Math.min(1, e / total);
      const cur = setHand(Math.min(1 - 1e-9, ease(t)));
      if (cur !== shown) { shown = cur; scrollTo(cur); K.post({ type: 'haptic' }); }
      if (t >= 1) return true;
    }));
  }

  // ---------------------------------------------------------------------
  // map_points: places on a world map.

  function renderMap(p) {
    const points = p.points;
    const strip = { s: null };
    const { svg, w: W, h: H } = layout(() => { strip.s = detailStrip('Tap a point.'); return {}; });
    svg.attr('aria-label', `${p.title}. ${points.map((q) => q.name + (q.value ? `: ${q.value.display}` : '')).join('; ')}`);
    const land = topojson.feature(window.FactvizLand, window.FactvizLand.objects.land);
    const lons = points.map((q) => q.lon), lats = points.map((q) => q.lat);
    const lonSpan = d3.max(lons) - d3.min(lons), latSpan = d3.max(lats) - d3.min(lats);
    const projection = d3.geoNaturalEarth1();
    const pad = 12;
    if (points.length && lonSpan < 110 && latSpan < 70) {
      // Regional: frame the points with some breathing room.
      const mx = Math.max(14, lonSpan * 0.35, (40 - lonSpan) / 2), my = Math.max(10, latSpan * 0.35, (24 - latSpan) / 2);
      const x0 = Math.max(-180, d3.min(lons) - mx), x1 = Math.min(180, d3.max(lons) + mx);
      const y0 = Math.max(-85, d3.min(lats) - my), y1 = Math.min(85, d3.max(lats) + my);
      projection.rotate([-(x0 + x1) / 2, 0]).fitExtent([[pad, pad], [W - pad, H - pad]],
        { type: 'MultiPoint', coordinates: [[x0, y0], [x1, y0], [x0, y1], [x1, y1], [(x0 + x1) / 2, y0], [(x0 + x1) / 2, y1]] });
    } else {
      projection.fitExtent([[pad, pad], [W - pad, H - pad]], { type: 'Sphere' });
    }
    const path = d3.geoPath(projection);
    svg.append('defs').append('clipPath').attr('id', 'map-clip').append('rect').attr('width', W).attr('height', H);
    const mapG = svg.append('g').attr('clip-path', 'url(#map-clip)');
    mapG.append('path').datum({ type: 'Sphere' }).attr('d', path).attr('fill', '#FBF9F5').attr('stroke', RULE);
    mapG.append('path').datum(d3.geoGraticule10()).attr('d', path).attr('fill', 'none').attr('stroke', '#ECE6DA').attr('stroke-width', 0.6);
    mapG.append('path').datum(land).attr('d', path).attr('fill', LAND).attr('stroke', '#D3CBBB').attr('stroke-width', 0.5);

    const withValues = points.every((q) => q.value);
    const maxV = withValues ? d3.max(points, (q) => q.value.valueSi) : 0;
    const rScale = withValues ? d3.scaleSqrt().domain([0, maxV]).range([0, Math.min(18, Math.max(9, W / 22))]) : null;
    const proj = points.map((q, i) => {
      const xy = projection([q.lon, q.lat]);
      return { q, i, x: xy[0], y: xy[1], r: rScale ? Math.max(3, rScale(q.value.valueSi)) : 5 };
    }).filter((d) => d.x >= 0 && d.x <= W && d.y >= 0 && d.y <= H);
    const order = proj.slice().sort((a, b) => b.r - a.r);
    const dots = mapG.append('g').selectAll('circle').data(order).join('circle')
      .attr('cx', (d) => d.x).attr('cy', (d) => d.y).attr('r', reduce() ? (d) => d.r : 0)
      .attr('fill', ACCENT).attr('fill-opacity', withValues ? 0.72 : 0.95).attr('stroke', PAPER).attr('stroke-width', 1.2)
      .attr('role', 'button').attr('aria-label', (d) => d.q.name + (d.q.value ? `: ${d.q.value.display}` : ''))
      .on('click', (_, d) => select(d.i));
    dots.transition().delay((d) => dur(200 + d.i * 70)).duration(dur(500)).ease(d3.easeBackOut).attr('r', (d) => d.r);

    // Labels, largest first, skipping any that would collide.
    const taken = proj.map((d) => ({ x0: d.x - d.r, x1: d.x + d.r, y0: d.y - d.r, y1: d.y + d.r }));
    const labels = mapG.append('g');
    const svgNode = svg;
    for (const d of order) {
      const text = d.q.name;
      const tw = textWidth(svgNode, text, 'map-label');
      for (const [dx, anchor] of [[d.r + 4, 'start'], [-d.r - 4, 'end']]) {
        const x0 = anchor === 'start' ? d.x + dx : d.x + dx - tw;
        const box = { x0, x1: x0 + tw, y0: d.y - 7, y1: d.y + 7 };
        if (box.x0 < 2 || box.x1 > W - 2) continue;
        if (taken.some((b) => b.x0 < box.x1 && box.x0 < b.x1 && b.y0 < box.y1 && box.y0 < b.y1)) continue;
        taken.push(box);
        labels.append('text').attr('class', 'map-label halo').attr('x', d.x + dx).attr('y', d.y + 4).attr('text-anchor', anchor).text(text)
          .attr('opacity', 0).transition().delay(dur(500 + d.i * 70)).duration(dur(300)).attr('opacity', 1);
        break;
      }
    }
    function select(i) {
      const q = points[i];
      dots.attr('stroke', (d) => (d.i === i ? INK : PAPER)).attr('stroke-width', (d) => (d.i === i ? 2 : 1.2));
      strip.s.set(q.value ? q.value.display : `${q.lat.toFixed(1)}°, ${q.lon.toFixed(1)}°`, q.name, q.value ? q.value.source : q.source);
    }
    if (withValues && order.length) select(order[0].i);
  }

  V.register('donut', renderDonut);
  V.register('stacked_bar', renderStacked);
  V.register('waffle', renderWaffle);
  V.register('treemap', renderTreemap);
  V.register('bubble_pack', renderBubbles);
  V.register('lollipop', renderLollipop);
  V.register('number_line', renderNumberLine);
  V.register('slope', renderSlope);
  V.register('range_bars', renderRange);
  V.register('versus', renderVersus);
  V.register('rate_counter', renderRate);
  V.register('pictogram', renderPictogram);
  V.register('line_series', renderLines);
  V.register('cosmic_clock', renderClock);
  V.register('map_points', renderMap);
})();
