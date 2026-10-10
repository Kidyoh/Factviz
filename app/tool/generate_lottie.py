#!/usr/bin/env python3
"""Generates the app's Lottie animations (assets/lottie/*.json).

    python3 tool/generate_lottie.py

Hand-authored in code so they match the editorial palette exactly:
- loader.json: three bars rise and an exponential curve draws over them.
- logo.json:   a small and a large circle settle onto a baseline ("to scale").
"""
import json
import math
from pathlib import Path

INK = (0.090, 0.090, 0.090)
RULE = (0.855, 0.827, 0.773)
ACCENT = (0.784, 0.333, 0.239)
BLUE = (0.165, 0.435, 0.592)
OCHRE = (0.851, 0.643, 0.255)
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'lottie'


def static(v):
    return {'a': 0, 'k': v}


def keyframes(frames, ease_out=(0.2, 1), ease_in=(0.33, 0)):
    """frames: list of (t, value). Values are lists."""
    k = []
    for i, (t, v) in enumerate(frames):
        kf = {'t': t, 's': v if isinstance(v, list) else [v]}
        if i < len(frames) - 1:
            kf['o'] = {'x': [ease_in[0]], 'y': [ease_in[1]]}
            kf['i'] = {'x': [ease_out[0]], 'y': [ease_out[1]]}
        k.append(kf)
    return {'a': 1, 'k': k}


def transform(opacity=None, position=(0, 0), scale=None, anchor=(0, 0)):
    return {
        'o': opacity or static(100),
        'r': static(0),
        'p': static([position[0], position[1], 0]),
        'a': static([anchor[0], anchor[1], 0]),
        's': scale or static([100, 100, 100]),
    }


def group_tr():
    return {'ty': 'tr', 'p': static([0, 0]), 'a': static([0, 0]), 's': static([100, 100]),
            'r': static(0), 'o': static(100), 'sk': static(0), 'sa': static(0)}


def path(points, closed=False):
    z = [[0, 0] for _ in points]
    return {'ty': 'sh', 'ks': static({'i': z, 'o': z, 'v': [list(p) for p in points], 'c': closed})}


def stroke(color, width, cap=2):
    return {'ty': 'st', 'c': static(list(color) + [1]), 'o': static(100), 'w': static(width), 'lc': cap, 'lj': 2}


def fill(color):
    return {'ty': 'fl', 'c': static(list(color) + [1]), 'o': static(100), 'r': 1}


def trim(end_kf):
    return {'ty': 'tm', 's': static(0), 'e': end_kf, 'o': static(0), 'm': 1}


def layer(ind, name, shapes, op, ks=None):
    return {'ddd': 0, 'ind': ind, 'ty': 4, 'nm': name, 'sr': 1, 'ks': ks or transform(), 'ao': 0,
            'shapes': shapes, 'ip': 0, 'op': op, 'st': 0, 'bm': 0}


def lottie(name, w, h, op, layers):
    return {'v': '5.7.4', 'fr': 60, 'ip': 0, 'op': op, 'w': w, 'h': h, 'nm': name, 'ddd': 0,
            'assets': [], 'layers': layers}


def loader():
    w, h, op = 240, 150, 180
    base = 124
    fade = keyframes([(0, 100), (140, 100), (170, 0)])
    layers = []
    # Curve: y = base - a * (2^(x/k) - 1), drawn left to right.
    pts = []
    for i in range(41):
        x = 30 + i * 4.5
        y = base - 92 * (2 ** (i / 40 * 6) - 1) / 63
        pts.append((round(x, 2), round(y, 2)))
    layers.append(layer(1, 'curve', [{'ty': 'gr', 'it': [
        path(pts), stroke(INK, 3), trim(keyframes([(20, 0), (95, 100)])), group_tr()]}], op,
        transform(opacity=fade)))
    # Head dot pops when the curve finishes.
    dot = {'ty': 'gr', 'it': [
        {'ty': 'el', 'p': static([pts[-1][0], pts[-1][1]]), 's': static([11, 11])},
        fill(ACCENT), group_tr()]}
    layers.append(layer(2, 'dot', [dot], op, transform(
        opacity=fade, anchor=pts[-1], position=pts[-1],
        scale=keyframes([(0, [0, 0, 100]), (92, [0, 0, 100]), (104, [125, 125, 100]), (112, [100, 100, 100])]))))
    # Bars grow from the baseline, staggered.
    for j, (x, top, color) in enumerate([(62, 98, ACCENT), (104, 80, BLUE), (146, 56, OCHRE)]):
        start = 6 + j * 12
        layers.append(layer(3 + j, f'bar{j}', [{'ty': 'gr', 'it': [
            path([(x, base), (x, top)]), stroke(color, 18, cap=1), trim(keyframes([(start, 0), (start + 40, 100)])),
            group_tr()]}], op, transform(opacity=fade)))
    layers.append(layer(6, 'baseline', [{'ty': 'gr', 'it': [
        path([(20, base + 1), (220, base + 1)]), stroke(RULE, 2, cap=1), group_tr()]}], op, transform(opacity=fade)))
    return lottie('loader', w, h, op, layers)


def logo():
    w, h, op = 120, 120, 90
    base = 90
    layers = []
    for ind, (cx, r, color, delay) in enumerate([(44, 26, INK, 0), (86, 9, ACCENT, 14)]):
        cy = base - r
        layers.append(layer(ind + 1, f'circle{ind}', [{'ty': 'gr', 'it': [
            {'ty': 'el', 'p': static([cx, cy]), 's': static([2 * r, 2 * r])}, fill(color), group_tr()]}], op,
            transform(anchor=(cx, base), position=(cx, base),
                      scale=keyframes([(delay, [0, 0, 100]), (delay + 22, [108, 108, 100]), (delay + 32, [100, 100, 100])]))))
    layers.append(layer(3, 'baseline', [{'ty': 'gr', 'it': [
        path([(12, base), (108, base)]), stroke(INK, 3, cap=1), trim(keyframes([(0, 0), (24, 100)])),
        group_tr()]}], op))
    return lottie('logo', w, h, op, layers)


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    for name, doc in [('loader', loader()), ('logo', logo())]:
        (OUT / f'{name}.json').write_text(json.dumps(doc, separators=(',', ':')))
        print(OUT / f'{name}.json')
