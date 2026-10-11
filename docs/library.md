# Writing library entries

The app ships a library of ready-made visualizations in
`app/assets/library/<category>.json`. Each entry is a facts JSON plus a plan
JSON, exactly what the two model layers would return, and goes through the
same validators and `PlanResolver` as a live answer. Check a file with:

```sh
cd packages/factviz_core
dart run tool/check_library.dart ../../app/assets/library/space.json
```

## File format

```json
{
  "category": "space",
  "title": "Space",
  "entries": [
    {
      "id": "planet_sizes",
      "facts": { ...FactsResult... },
      "plan":  { ...Plan... }
    }
  ]
}
```

`id`: unique slug `[a-z0-9_]`, max 60 chars.

## Facts (FactsResult)

```json
{
  "query": "How big are the planets?",          // ≤ 300 chars, phrased like a user question
  "topic": "Planet sizes",                       // ≤ 80
  "confidence": "high",                          // high | medium | low
  "confidenceNote": "…",                         // required only when low
  "explanation": "2–4 plain sentences, ≤ 600 chars.",
  "facts": [ …at most 30… ]
}
```

The explanation must not contain numbers that are not in the facts. Prefer
no numbers at all in it.

Every fact: `kind`, `id` (slug `[a-z0-9_]` ≤ 40, unique), `label` (≤ 80),
`sourceNote` (≤ 160, names the kind of source, e.g. "NASA planetary fact
sheet", "UN World Population Prospects 2024", "Guinness World Records";
no URLs).

| kind | fields |
|---|---|
| `quantity` | `value` (number ≥ 0), `unit` (below), `approximate` (true for typical / rounded values), optional `year` (int, the year the value applies to; negative = BCE) |
| `event` | `year` (int, negative = BCE, down to -14000000000), optional `month` 1–12, `day` 1–31 (needs month), `description` ≤ 200 |
| `step` | `order` (1..n, contiguous across the file), `title` ≤ 60, `description` ≤ 240 |
| `place` | `lat` (-90..90), `lon` (-180..180) |

Units: length `nm um mm cm m km ft mi au ly pc` · mass `mg g kg t lb` ·
duration `s min h day yr` · speed `m/s km/h mph` · area `m2 km2` · volume
`mL L m3` · money `USD EUR` (currencies never mix) · `count` · `ratio` ·
`percent` (0–100).

Values must be ≥ 0. Two facts can only share a chart if they share a
dimension (all money in one chart must be the same currency).

## Plan

Common: `template`, `title` (≤ 80, no numbers), optional `caption` (≤ 160).
A plan may not reference the same fact twice (except exponential_growth).
`displayName` ≤ 40. Pictures (`image`) must come from this catalog:

- photos (round items): `sun mercury venus earth moon mars jupiter saturn uranus neptune pluto`
- silhouettes: `blue_whale sperm_whale t_rex school_bus car` (lengths),
  `elephant dog` (lengths or heights), `person eiffel_tower skyscraper rocket` (heights)

| template | draws | plan fields | rules |
|---|---|---|---|
| `scale_zoom` | log-space camera zooming out from smallest to largest, to scale | `mode` size\|distance, `items` 2–8 `{factId, displayName, shape circle\|bar\|tower, image?}` | length/area/volume, all > 0 |
| `timeline` | scrollable timeline | `eventFactIds` 2–30, `axis` linear\|log_years_ago | event facts |
| `exponential_growth` | growth curve, linear/log toggle | `initialFactId`, `factorFactId` (unit ratio, >1, ≤1000), `stepsFactId` (unit count, 1–200), `targetFactId?`, `stepLabel` (singular noun), `defaultScale` | target same dimension as initial |
| `comparison_bars` | bars that grow | `bars` 2–8 `{factId, displayName, image?}`, `orientation` horizontal\|vertical | same dimension |
| `process_steps` | cycle or step list | `stepFactIds` 2–12, `autoplayMs` 1500–8000, `loop` | step facts |
| `pictogram` | grid of icons: how many small things make one big thing | `unitFactId`, `totalFactId`, `unitName` (plural), `totalName`, `image?` | same dimension, total/unit from 1 to 10,000 |
| `donut` | ring of shares | `items` 2–8, `totalFactId?` | same dimension; parts ≤ total; remainder drawn as "Other". Percent parts without a total are shares of 100% |
| `stacked_bar` | one bar split into shares | same as donut | same as donut |
| `waffle` | 10×10 grid per item, filled to the percentage | `items` 1–4 | unit `percent` |
| `treemap` | nested rectangles by size | `items` 3–30 | same dimension, all > 0 |
| `bubble_pack` | packed circles by size | `items` 3–40 | same dimension, all > 0 |
| `lollipop` | ranked dot-and-stem chart | `items` 3–25, `scale?` linear\|log | same dimension; sorted largest first |
| `number_line` | items placed on one axis | `items` 2–15, `scale?` linear\|log | same dimension; log needs > 0 |
| `slope` | before → after lines | `rows` 1–10 `{label, aFactId (before), bFactId (after)}`, `aName?`, `bName?` (column labels) | same dimension across rows; if both have `year`, a's year ≤ b's |
| `range_bars` | low–high span per row | `rows` 2–12 `{label, aFactId (low), bFactId (high)}` | same dimension; low ≤ high |
| `versus` | two subjects, row-by-row head to head | `rows` 2–8 `{label, aFactId, bFactId}`, `aName`, `bName` (required), `aImage?`, `bImage?` | each row's two facts share a dimension (rows can differ) |
| `rate_counter` | live counter ticking since the page opened | `rows` 1–4 `{label, aFactId (amount), bFactId (period)}` | amount: count/money/mass/volume/length/area; period: a duration > 0 (e.g. 1 yr) |
| `line_series` | lines over years | `series` 1–4 `{displayName, factIds 3–60}`, `scale?` | quantity facts that all have a `year`, same dimension, no repeated year within a series |
| `cosmic_clock` | a long history squeezed into 24 hours; now = midnight | `eventFactIds` 3–15 | event facts, all in the past, oldest at least a century ago |
| `map_points` | dots on a world map, optionally sized by value | `points` 1–30 `{placeFactId, displayName, valueFactId?}` | place facts; give every point a value or none |
| `none` | plain fact card | `reason` ≤ 200 | |

## Accuracy

Use well-established figures from authoritative sources (space agencies,
UN, World Bank, WHO, national statistics offices, peer-reviewed reference
values, Guinness World Records). Mark typical or rounded values
`approximate: true`. Give time-dependent values a `year`. When a figure is
disputed or only estimated, say so in the source note and use
`confidence: "medium"`.
