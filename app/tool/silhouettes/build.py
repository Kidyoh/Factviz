#!/usr/bin/env python3
"""Builds the bundled silhouette library from manifest.json.

Usage (from anywhere):

    python3 app/tool/silhouettes/build.py            # build, using the cache
    python3 app/tool/silhouettes/build.py --refresh  # re-download sources

Sources are downloaded once into app/tool/silhouettes/cache (gitignored):

* phylopic: the image record (to check the license) and its vector.svg from
  https://api.phylopic.org / https://images.phylopic.org,
* mdi:      the @mdi/svg npm package (version from the manifest),
* drawn:    SVG files in app/tool/silhouettes/drawn/.

Every picture is flattened (transforms applied, arcs turned into curves),
optionally mirrored or rotated, moved to the origin and scaled so that its
larger side is SIZE units, then written with rounded relative coordinates.
`box` is the tight bounding box of the drawn geometry (curve extrema included),
because the renderer scales `box` onto the measured size.

Writes:

* app/assets/viz/silhouettes.js
* packages/factviz_core/lib/src/images/silhouette_catalog.g.dart
* the silhouette section of app/assets/viz/img/CREDITS.md

Standard library only.
"""

import argparse
import io
import json
import math
import os
import re
import sys
import tarfile
import urllib.request
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..'))
CACHE = os.path.join(HERE, 'cache')
DRAWN = os.path.join(HERE, 'drawn')
MANIFEST = os.path.join(HERE, 'manifest.json')
OUT_JS = os.path.join(REPO, 'app', 'assets', 'viz', 'silhouettes.js')
OUT_DART = os.path.join(REPO, 'packages', 'factviz_core', 'lib', 'src', 'images', 'silhouette_catalog.g.dart')
CREDITS = os.path.join(REPO, 'app', 'assets', 'viz', 'img', 'CREDITS.md')

SIZE = 1000.0  # larger side of every normalized picture
DECIMALS = 1   # coordinate precision in output units

PHYLOPIC_API = 'https://api.phylopic.org'
PHYLOPIC_FILES = 'https://images.phylopic.org/images'
NPM_MDI = 'https://registry.npmjs.org/@mdi/svg/-/svg-{v}.tgz'

LICENSES = {
    'https://creativecommons.org/publicdomain/zero/1.0/': 'CC0 1.0',
    'https://creativecommons.org/publicdomain/mark/1.0/': 'Public Domain Mark 1.0',
    'https://creativecommons.org/licenses/by/3.0/': 'CC BY 3.0',
    'https://creativecommons.org/licenses/by/4.0/': 'CC BY 4.0',
}
SHAPES = ('bar', 'tower')
GROUPS = ('animals', 'prehistoric', 'people', 'plants', 'landmarks', 'vehicles', 'objects')
SVG_NS = '{http://www.w3.org/2000/svg}'


# ---------------------------------------------------------------------------
# Downloads


def fetch(url, path, refresh=False):
    """Downloads url to path (cached) and returns the bytes."""
    if os.path.exists(path) and not refresh:
        with open(path, 'rb') as f:
            return f.read()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    req = urllib.request.Request(url, headers={'User-Agent': 'factviz-silhouettes/1 (build script)'})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    with open(path + '.tmp', 'wb') as f:
        f.write(data)
    os.replace(path + '.tmp', path)
    return data


def phylopic_source(rec, refresh):
    uuid = rec['id']
    meta = json.loads(fetch(f'{PHYLOPIC_API}/images/{uuid}', os.path.join(CACHE, 'phylopic', uuid + '.json'), refresh))
    lic = meta['_links']['license']['href']
    if lic not in LICENSES:
        raise SystemExit(f'{rec["key"]}: PhyloPic image {uuid} has license {lic}, which is not allowed')
    if LICENSES[lic] != rec['license']:
        raise SystemExit(f'{rec["key"]}: manifest says {rec["license"]} but PhyloPic says {LICENSES[lic]}')
    svg = fetch(f'{PHYLOPIC_FILES}/{uuid}/vector.svg', os.path.join(CACHE, 'phylopic', uuid + '.svg'), refresh)
    return svg.decode('utf-8')


_mdi_tar = {}


def mdi_source(rec, version, refresh):
    if version not in _mdi_tar:
        data = fetch(NPM_MDI.format(v=version), os.path.join(CACHE, 'mdi', f'svg-{version}.tgz'), refresh)
        _mdi_tar[version] = tarfile.open(fileobj=io.BytesIO(data), mode='r:gz')
    tar = _mdi_tar[version]
    try:
        member = tar.getmember(f'package/svg/{rec["id"]}.svg')
    except KeyError:
        raise SystemExit(f'{rec["key"]}: no MDI icon named {rec["id"]!r} in @mdi/svg {version}')
    return tar.extractfile(member).read().decode('utf-8')


def drawn_source(rec):
    with open(os.path.join(DRAWN, rec['id']), encoding='utf-8') as f:
        return f.read()


# ---------------------------------------------------------------------------
# Geometry: affine matrices are (a, b, c, d, e, f) as in SVG.

IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def mul(m, n):
    """Returns m * n: the transform that applies n first, then m."""
    a, b, c, d, e, f = m
    A, B, C, D, E, F = n
    return (a * A + c * B, b * A + d * B, a * C + c * D, b * C + d * D, a * E + c * F + e, b * E + d * F + f)


def apply(m, p):
    a, b, c, d, e, f = m
    x, y = p
    return (a * x + c * y + e, b * x + d * y + f)


_NUM = r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?'


def parse_transform(s):
    m = IDENTITY
    for name, args in re.findall(r'(\w+)\s*\(([^)]*)\)', s or ''):
        v = [float(x) for x in re.findall(_NUM, args)]
        if name == 'matrix':
            t = tuple(v)
        elif name == 'translate':
            t = (1, 0, 0, 1, v[0], v[1] if len(v) > 1 else 0)
        elif name == 'scale':
            t = (v[0], 0, 0, v[1] if len(v) > 1 else v[0], 0, 0)
        elif name == 'rotate':
            r = math.radians(v[0])
            t = (math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0)
            if len(v) == 3:
                t = mul(mul((1, 0, 0, 1, v[1], v[2]), t), (1, 0, 0, 1, -v[1], -v[2]))
        elif name == 'skewX':
            t = (1, 0, math.tan(math.radians(v[0])), 1, 0, 0)
        elif name == 'skewY':
            t = (1, math.tan(math.radians(v[0])), 0, 1, 0, 0)
        else:
            raise ValueError('unknown transform ' + name)
        m = mul(m, t)
    return m


def tokenize_path(d):
    for cmd, args in re.findall(r'([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)', d):
        if cmd in 'Aa':
            # Arc flags may be written without separators ("0 011 2").
            nums, rest = [], args
            idx = 0
            while True:
                rest = rest.lstrip(' ,\t\r\n')
                if not rest:
                    break
                if idx % 7 in (3, 4):
                    nums.append(float(rest[0]))
                    rest = rest[1:]
                else:
                    mt = re.match(_NUM, rest)
                    nums.append(float(mt.group(0)))
                    rest = rest[mt.end():]
                idx += 1
        else:
            nums = [float(x) for x in re.findall(_NUM, args)]
        yield cmd, nums


def arc_to_cubics(p0, rx, ry, phi, large, sweep, p1):
    """Endpoint arc -> list of cubic segments ((c1, c2, end), ...)."""
    x1, y1 = p0
    x2, y2 = p1
    if (x1, y1) == (x2, y2):
        return []
    if rx == 0 or ry == 0:
        return [(p0, p1, p1)]
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(phi)
    cp, sp = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p = cp * dx + sp * dy
    y1p = -sp * dx + cp * dy
    lam = (x1p / rx) ** 2 + (y1p / ry) ** 2
    if lam > 1:
        s = math.sqrt(lam)
        rx, ry = rx * s, ry * s
    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    co = math.sqrt(max(0.0, num / den)) if den else 0.0
    if large == sweep:
        co = -co
    cxp = co * rx * y1p / ry
    cyp = -co * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x1 + x2) / 2
    cy = sp * cxp + cp * cyp + (y1 + y2) / 2

    def ang(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dt > 0:
        dt -= 2 * math.pi
    elif sweep and dt < 0:
        dt += 2 * math.pi
    n = max(1, int(math.ceil(abs(dt) / (math.pi / 2) - 1e-9)))
    step = dt / n
    k = 4 / 3 * math.tan(step / 4)
    out = []

    def pt(t):
        x, y = rx * math.cos(t), ry * math.sin(t)
        return (cp * x - sp * y + cx, sp * x + cp * y + cy)

    def deriv(t):
        x, y = -rx * math.sin(t), ry * math.cos(t)
        return (cp * x - sp * y, sp * x + cp * y)

    t = t1
    for i in range(n):
        a, b = t, t + step
        pa, pb = pt(a), pt(b)
        da, db = deriv(a), deriv(b)
        c1 = (pa[0] + k * da[0], pa[1] + k * da[1])
        c2 = (pb[0] - k * db[0], pb[1] - k * db[1])
        end = p1 if i == n - 1 else pb
        out.append((c1, c2, end))
        t = b
    return out


def parse_path(d):
    """Returns subpaths: list of [start, [seg, ...], closed]; seg = ('L', p) | ('C', c1, c2, p)."""
    subs = []
    cur = None
    pos = (0.0, 0.0)
    start = pos
    last_c2 = None  # reflection point for S
    last_q = None   # reflection point for T
    for cmd, nums in tokenize_path(d):
        rel = cmd.islower()
        C = cmd.upper()

        def P(x, y):
            return (pos[0] + x, pos[1] + y) if rel else (x, y)

        if C == 'Z':
            if cur is not None:
                cur[2] = True
            pos = start
            cur = None
            last_c2 = last_q = None
            continue
        arity = {'M': 2, 'L': 2, 'H': 1, 'V': 1, 'C': 6, 'S': 4, 'Q': 4, 'T': 2, 'A': 7}[C]
        if not nums:
            continue
        for i in range(0, len(nums) - arity + 1, arity):
            a = nums[i:i + arity]
            if C == 'M' and i == 0:
                pos = P(a[0], a[1])
                start = pos
                cur = [pos, [], False]
                subs.append(cur)
                last_c2 = last_q = None
                continue
            if cur is None:
                cur = [pos, [], False]
                start = pos
                subs.append(cur)
            if C in 'ML':
                p = P(a[0], a[1])
                cur[1].append(('L', p))
                last_c2 = last_q = None
            elif C == 'H':
                p = (pos[0] + a[0] if rel else a[0], pos[1])
                cur[1].append(('L', p))
                last_c2 = last_q = None
            elif C == 'V':
                p = (pos[0], pos[1] + a[0] if rel else a[0])
                cur[1].append(('L', p))
                last_c2 = last_q = None
            elif C == 'C':
                c1, c2, p = P(a[0], a[1]), P(a[2], a[3]), P(a[4], a[5])
                cur[1].append(('C', c1, c2, p))
                last_c2, last_q = c2, None
            elif C == 'S':
                c1 = (2 * pos[0] - last_c2[0], 2 * pos[1] - last_c2[1]) if last_c2 else pos
                c2, p = P(a[0], a[1]), P(a[2], a[3])
                cur[1].append(('C', c1, c2, p))
                last_c2, last_q = c2, None
            elif C in 'QT':
                if C == 'Q':
                    q, p = P(a[0], a[1]), P(a[2], a[3])
                else:
                    q = (2 * pos[0] - last_q[0], 2 * pos[1] - last_q[1]) if last_q else pos
                    p = P(a[0], a[1])
                c1 = (pos[0] + 2 / 3 * (q[0] - pos[0]), pos[1] + 2 / 3 * (q[1] - pos[1]))
                c2 = (p[0] + 2 / 3 * (q[0] - p[0]), p[1] + 2 / 3 * (q[1] - p[1]))
                cur[1].append(('C', c1, c2, p))
                last_c2, last_q = None, q
            elif C == 'A':
                p = P(a[5], a[6])
                for c1, c2, e in arc_to_cubics(pos, a[0], a[1], a[2], int(a[3]), int(a[4]), p):
                    cur[1].append(('C', c1, c2, e))
                last_c2 = last_q = None
            if cur[1]:
                pos = cur[1][-1][-1]
    return subs


def shape_to_path(el):
    """Converts basic shapes to path data."""
    tag = el.tag.replace(SVG_NS, '')
    g = lambda k, dflt=0.0: float(el.get(k, dflt))
    if tag == 'path':
        return el.get('d', '')
    if tag == 'rect':
        x, y, w, h = g('x'), g('y'), g('width'), g('height')
        return f'M{x},{y}H{x + w}V{y + h}H{x}Z'
    if tag in ('circle', 'ellipse'):
        cx, cy = g('cx'), g('cy')
        rx = g('r') if tag == 'circle' else g('rx')
        ry = g('r') if tag == 'circle' else g('ry')
        return (f'M{cx - rx},{cy}A{rx},{ry} 0 1 0 {cx + rx},{cy}'
                f'A{rx},{ry} 0 1 0 {cx - rx},{cy}Z')
    if tag in ('polygon', 'polyline'):
        pts = re.findall(_NUM, el.get('points', ''))
        d = 'M' + ' '.join(pts)
        return d + ('Z' if tag == 'polygon' else '')
    return None


def collect(el, m, out, inherited_rule):
    """Walks the SVG tree; appends (subpaths_in_world_coords, fill_rule)."""
    tag = el.tag.replace(SVG_NS, '')
    if tag in ('defs', 'metadata', 'title', 'desc', 'clipPath', 'mask', 'style'):
        return
    style = dict(
        kv.split(':', 1) for kv in (el.get('style') or '').replace(' ', '').split(';') if ':' in kv)
    fill = style.get('fill', el.get('fill'))
    if fill == 'none' or el.get('display') == 'none' or style.get('display') == 'none':
        return
    rule = style.get('fill-rule', el.get('fill-rule', inherited_rule))
    m = mul(m, parse_transform(el.get('transform')))
    d = shape_to_path(el)
    if d is not None:
        subs = parse_path(d)
        world = []
        for s0, segs, closed in subs:
            ws = []
            for seg in segs:
                ws.append((seg[0],) + tuple(apply(m, p) for p in seg[1:]))
            world.append([apply(m, s0), ws, closed])
        if world:
            out.append((world, rule))
    for child in el:
        collect(child, m, out, rule)


def cubic_extrema(p0, p1, p2, p3):
    """Parameter values in (0,1) where a 1-D cubic has zero derivative."""
    a = -p0 + 3 * p1 - 3 * p2 + p3
    b = 2 * (p0 - 2 * p1 + p2)
    c = p1 - p0
    ts = []
    if abs(a) < 1e-12:
        if abs(b) > 1e-12:
            ts.append(-c / b)
    else:
        disc = b * b - 4 * a * c
        if disc >= 0:
            r = math.sqrt(disc)
            ts += [(-b + r) / (2 * a), (-b - r) / (2 * a)]
    return [t for t in ts if 0 < t < 1]


def bez(p0, p1, p2, p3, t):
    u = 1 - t
    return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3


def bbox(paths):
    xs, ys = [], []
    for subs, _ in paths:
        for s0, segs, _closed in subs:
            prev = s0
            xs.append(s0[0])
            ys.append(s0[1])
            for seg in segs:
                p = seg[-1]
                xs.append(p[0])
                ys.append(p[1])
                if seg[0] == 'C':
                    c1, c2 = seg[1], seg[2]
                    for i, arr in ((0, xs), (1, ys)):
                        for t in cubic_extrema(prev[i], c1[i], c2[i], p[i]):
                            arr.append(bez(prev[i], c1[i], c2[i], p[i], t))
                prev = p
    return min(xs), min(ys), max(xs), max(ys)


def transform_paths(paths, m):
    out = []
    for subs, rule in paths:
        ns = []
        for s0, segs, closed in subs:
            ns.append([apply(m, s0), [(seg[0],) + tuple(apply(m, p) for p in seg[1:]) for seg in segs], closed])
        out.append((ns, rule))
    return out


def fmt(v):
    s = f'{v:.{DECIMALS}f}'.rstrip('0').rstrip('.') if DECIMALS else str(int(round(v)))
    if s in ('-0', ''):
        s = '0'
    if s.startswith('0.'):
        s = s[1:]
    elif s.startswith('-0.'):
        s = '-' + s[2:]
    return s


def join_nums(nums):
    out = ''
    for n in nums:
        s = fmt(n)
        if out and not s.startswith('-') and not (s.startswith('.') and ('.' in _last_num(out))):
            out += ' '
        out += s
    return out


def _last_num(s):
    m = re.search(r'[-]?[\d.]+$', s)
    return m.group(0) if m else ''


def serialize(subs):
    """Relative path data from rounded absolute points (no error build-up)."""
    q = 10 ** DECIMALS
    R = lambda p: (round(p[0] * q) / q, round(p[1] * q) / q)
    parts = []
    for s0, segs, closed in subs:
        cur = R(s0)
        start = cur
        parts.append('M' + join_nums(cur))
        last = None
        buf = []

        def flush():
            if buf:
                parts.append(last + join_nums(buf))
                buf.clear()

        for seg in segs:
            pts = [R(p) for p in seg[1:]]
            end = pts[-1]
            if seg[0] == 'L':
                if end == cur:
                    continue
                dx, dy = end[0] - cur[0], end[1] - cur[1]
                if dy == 0:
                    cmd, nums = 'h', [dx]
                elif dx == 0:
                    cmd, nums = 'v', [dy]
                else:
                    cmd, nums = 'l', [dx, dy]
            else:
                c1, c2 = pts[0], pts[1]
                if c1 == cur and c2 == end:
                    if end == cur:
                        continue
                    cmd, nums = 'l', [end[0] - cur[0], end[1] - cur[1]]
                else:
                    cmd = 'c'
                    nums = [c1[0] - cur[0], c1[1] - cur[1], c2[0] - cur[0], c2[1] - cur[1],
                            end[0] - cur[0], end[1] - cur[1]]
            if cmd != last:
                flush()
                last = cmd
            buf.extend(nums)
            cur = end
        flush()
        if closed:
            parts.append('z')
    return ''.join(parts)


def normalize(svg_text, rec):
    root = ET.fromstring(svg_text)
    paths = []
    collect(root, IDENTITY, paths, 'nonzero')
    if not paths:
        raise SystemExit(f'{rec["key"]}: no drawable paths')
    # Optional orientation fixes from the manifest.
    m = IDENTITY
    rot = rec.get('rotate', 0)
    if rot:
        r = math.radians(rot)
        m = mul((math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0), m)
    if rec.get('flip'):
        m = mul((-1, 0, 0, 1, 0, 0), m)
    if m != IDENTITY:
        paths = transform_paths(paths, m)
    x0, y0, x1, y1 = bbox(paths)
    s = SIZE / max(x1 - x0, y1 - y0)
    paths = transform_paths(paths, (s, 0, 0, s, -x0 * s, -y0 * s))
    markup = []
    for subs, rule in paths:
        d = serialize(subs)
        attr = ' fill-rule="evenodd"' if rule == 'evenodd' else ''
        markup.append(f'<path{attr} d="{d}"/>')
    # The box of what is actually written (after rounding).
    reparsed = []
    for frag in markup:
        mt = re.search(r' d="([^"]*)"', frag)
        reparsed.append((parse_path(mt.group(1)), 'nonzero'))
    bx0, by0, bx1, by1 = bbox(reparsed)
    box = [round(bx0, 2), round(by0, 2), round(bx1 - bx0, 2), round(by1 - by0, 2)]
    return ''.join(markup), box


# ---------------------------------------------------------------------------
# Manifest checks and outputs


def check(manifest):
    keys = set()
    for rec in manifest['silhouettes']:
        k = rec['key']
        assert re.fullmatch(r'[a-z_]+', k) and len(k) <= 30, f'bad key {k}'
        assert k not in keys, f'duplicate key {k}'
        keys.add(k)
        assert rec['group'] in GROUPS, f'{k}: bad group'
        assert rec['source'] in ('phylopic', 'mdi', 'drawn'), f'{k}: bad source'
        assert rec['shapes'] and all(s in SHAPES for s in rec['shapes']), f'{k}: bad shapes'
        assert rec['license'], f'{k}: missing license'
        if rec['source'] == 'phylopic':
            assert rec['license'] in LICENSES.values(), f'{k}: license {rec["license"]} not allowed'
            if rec['license'].startswith('CC BY'):
                assert rec.get('author'), f'{k}: CC BY needs an author'
        if rec.get('stretch'):
            assert rec.get('aspect', 0) > 0, f'{k}: stretched pictures need a real-world aspect'
        else:
            assert 'aspect' not in rec, f'{k}: aspect is only for stretched pictures'


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def write_dart(manifest, built):
    lines = [
        '// GENERATED by app/tool/silhouettes/build.py from app/tool/silhouettes/manifest.json.',
        '// Do not edit by hand; edit the manifest and run the script.',
        '',
        "part of 'image_catalog.dart';",
        '',
        '/// Every bundled silhouette, in manifest order (grouped by kind).',
        'const List<ImageAsset> silhouetteAssets = [',
    ]
    group = None
    for rec in manifest['silhouettes']:
        if rec['group'] != group:
            group = rec['group']
            lines.append(f'  // {group}')
        box = built[rec['key']]['box']
        aspect = rec['aspect'] if rec.get('stretch') else round(box[2] / box[3], 3)
        shapes = ', '.join(f'ItemShape.{s}' for s in rec['shapes'])
        stretch = ', stretch: true' if rec.get('stretch') else ''
        lines.append(
            f"  ImageAsset(key: {dart_str(rec['key'])}, label: {dart_str(rec['label'])}, "
            f'kind: ImageKind.silhouette, shapes: {{{shapes}}}, aspect: {aspect}{stretch}),')
    lines += ['];', '']
    with open(OUT_DART, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))


def write_js(built):
    body = json.dumps({k: built[k] for k in sorted(built)}, separators=(',', ':'), ensure_ascii=False)
    with open(OUT_JS, 'w', encoding='utf-8') as f:
        f.write('// GENERATED by app/tool/silhouettes/build.py from app/tool/silhouettes/manifest.json;\n')
        f.write('// do not edit by hand. Sources and licenses: img/CREDITS.md.\n')
        f.write('window.FactvizSilhouettes = ' + body + ';\n')


CREDITS_START = '## Silhouettes (`../silhouettes.js`)'
CREDITS_END = '## Map data'


def md(s):
    return s.replace('|', '\\|')


def write_credits(manifest):
    recs = manifest['silhouettes']
    out = [CREDITS_START, '',
           'Generated by `app/tool/silhouettes/build.py` from `app/tool/silhouettes/manifest.json`.',
           'Pictures are normalized (flattened, scaled) but otherwise unchanged; icon-style',
           'pictures marked "stretched" are drawn stretched to the object\'s real proportions.', '']
    phylo = [r for r in recs if r['source'] == 'phylopic']
    out += [f'From [PhyloPic](https://www.phylopic.org) ({len(phylo)}):', '',
            '| Key | PhyloPic image | Author | License |', '|---|---|---|---|']
    for r in sorted(phylo, key=lambda r: r['key']):
        out.append(f'| {r["key"]} | [{r["id"]}](https://www.phylopic.org/images/{r["id"]}) | '
                   f'{md(r.get("author") or "—")} | {r["license"]} |')
    mdi = [r for r in recs if r['source'] == 'mdi']
    out += ['', f'From [Material Design Icons](https://pictogrammers.com/library/mdi/) '
            f'{manifest["mdi_version"]} (Apache License 2.0, see `../vendor/LICENSE-mdi.txt`) ({len(mdi)}):', '',
            '| Key | MDI icon | Stretched to (w/h) |', '|---|---|---|']
    for r in sorted(mdi, key=lambda r: r['key']):
        out.append(f'| {r["key"]} | {r["id"]} | {r["aspect"] if r.get("stretch") else "—"} |')
    drawn = [r for r in recs if r['source'] == 'drawn']
    out += ['', f'Drawn for this project ({len(drawn)}; sources in `app/tool/silhouettes/drawn/`, '
            'same license as the app): ' + ', '.join(f'`{r["key"]}`' for r in sorted(drawn, key=lambda r: r['key']))
            + '.', '', '']
    with open(CREDITS, encoding='utf-8') as f:
        text = f.read()
    a = text.index(CREDITS_START)
    b = text.index(CREDITS_END)
    with open(CREDITS, 'w', encoding='utf-8') as f:
        f.write(text[:a] + '\n'.join(out) + text[b:])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--refresh', action='store_true', help='re-download every source')
    ap.add_argument('--only', nargs='*', help='only rebuild these keys (others are still required in the cache)')
    args = ap.parse_args()
    with open(MANIFEST, encoding='utf-8') as f:
        manifest = json.load(f)
    check(manifest)
    built = {}
    for rec in manifest['silhouettes']:
        refresh = args.refresh and (not args.only or rec['key'] in args.only)
        if rec['source'] == 'phylopic':
            svg = phylopic_source(rec, refresh)
        elif rec['source'] == 'mdi':
            svg = mdi_source(rec, manifest['mdi_version'], refresh)
        else:
            svg = drawn_source(rec)
        markup, box = normalize(svg, rec)
        built[rec['key']] = {'markup': markup, 'box': box}
    write_js(built)
    write_dart(manifest, built)
    write_credits(manifest)
    size = os.path.getsize(OUT_JS)
    by = {}
    for r in manifest['silhouettes']:
        by[r['group']] = by.get(r['group'], 0) + 1
    print(f'{len(built)} silhouettes ({", ".join(f"{g} {n}" for g, n in by.items())}); '
          f'silhouettes.js {size / 1024:.0f} KiB')
    big = sorted(built, key=lambda k: -len(built[k]['markup']))[:5]
    print('largest: ' + ', '.join(f'{k} {len(built[k]["markup"]) / 1024:.0f} KiB' for k in big))


if __name__ == '__main__':
    sys.exit(main())
