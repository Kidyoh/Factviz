# Explain It Visually

Type any concept and get an animated, to-scale visualization with real facts:
"how far is the Moon", "fold a paper 42 times to reach the Moon", "blue whale vs a bus".

The AI never draws or writes UI code. It returns **facts** and then **picks a
template**; hand-built Flutter widgets do all the drawing.

## Architecture

```
 Flutter app (Android)                 shelf server (holds the LLM key)
 ─────────────────────                 ──────────────────────────────────
 Search ──POST /api/facts──────────▶  1. Facts layer   (OpenRouter → Gemini)
        ◀──────── FactsResult ──────     validate → retry once → 422
        ──POST /api/plan───────────▶  2. Planner layer (OpenRouter → Gemini)
        ◀──────── Plan ─────────────     validate + resolve → retry once → 422
 3. Render layer: PlanResolver (on device again) → render JSON → D3 in a WebView
```

- **Facts layer**: strict JSON with values, units, and a short source note per
  number. When the model is unsure it returns `confidence: "low"` with a note,
  and the app shows a warning badge.
- **Planner layer**: picks one of 20 chart templates (or `none`) and
  **refers to facts only by id**. It cannot introduce numbers.
- **Render layer**: `PlanResolver` turns plan + facts into typed props
  (unit conversion, dimension checks, sorting), and `renderJson` turns
  those into the JSON contract for the renderer, including display strings
  and annotations. The templates are hand-written **D3 v7** charts in
  `app/assets/viz/`, bundled offline and hosted in a WebView. Every number
  on screen comes from a fact; the JavaScript never formats or invents a
  figure.

Both LLM outputs are validated by `factviz_core`, a pure-Dart package shared
by the server and the app. On a validation failure the server retries once,
feeding the errors back to the model. If that also fails, the app shows
*"Couldn't visualize this one, try rephrasing."*

## Chart templates

| Template | Shows | Template | Shows |
|---|---|---|---|
| `scale_zoom` | sizes or distances to scale, log camera | `lollipop` | a ranking |
| `timeline` | dated events | `number_line` | values on one axis (linear or log) |
| `exponential_growth` | repeated multiplication | `slope` | before → after |
| `comparison_bars` | amounts side by side | `range_bars` | low–high spans |
| `process_steps` | ordered stages or a cycle | `versus` | two subjects, attribute by attribute |
| `pictogram` | how many of one thing make another | `rate_counter` | a live counter of what happens per second |
| `donut` | shares of a whole | `line_series` | values over the years, with scrubbing |
| `stacked_bar` | one bar split into parts | `cosmic_clock` | a long history squeezed into 24 hours |
| `waffle` | percentages as 10×10 grids | `map_points` | places on a world map, sized by value |
| `treemap` | parts by area | `bubble_pack` | many things as packed circles |

Facts can be quantities (optionally with a `year`), dated events, process
steps or places (`lat`/`lon`). The rules for each template (which facts,
which dimensions, limits) live in `PlanResolver` and are listed in
[`docs/library.md`](docs/library.md).

## Library

The app ships **110 ready-made visualizations** in ten categories
(`app/assets/library/*.json`), browsable and searchable from the home screen
without an API key. Each entry is a facts JSON plus a plan JSON, with a
source note for every figure, and is loaded through exactly the same
validators and resolver as a live answer; an invalid category is left out
rather than shown. Check or add entries with:

```sh
cd packages/factviz_core
dart run tool/check_library.dart ../../app/assets/library/*.json
```

## Repository layout

```
packages/factviz_core/   schemas, validation, units, PlanResolver, ShareCodec, JSON Schemas
server/                  shelf API: OpenRouter client, prompts, validated calls, routes
app/                     Flutter app (Android; iOS later)
  assets/viz/            D3 renderer: index.html, viz.js (original 5 templates),
                         viz_extra.js (15 more), viz.css, silhouettes.js, img/ (NASA photos),
                         vendor/ (d3, d3-annotation, topojson-client, world-atlas land)
  assets/library/        110 bundled visualizations (facts + plan JSON) and index.json
  assets/lottie/         loader and logo animations (from tool/generate_lottie.py)
  lib/viz/               WebView host for the renderer
  lib/templates/         mock_data.dart (Dev Gallery only)
  lib/ui/                shared widgets (search, stages, key numbers, badges, errors)
  lib/screens/           home, result, library, settings, dev gallery
  viz_test/              renderer tests and screenshots (Node + headless Chromium)
fixtures/queries/        the five fixed test queries (one per template)
```

This is a Dart pub workspace: run `flutter pub get` once at the repository root.

## Running

### 1. Server

```sh
cd server
cp .env.example .env            # add your OPENROUTER_API_KEY
set -a; source .env; set +a
dart run bin/server.dart        # http://localhost:8080
```

| Variable | Default | |
|---|---|---|
| `OPENROUTER_API_KEY` (or `LLM_API_KEY`) | required | Never sent to the app |
| `LLM_PROVIDER` | `openrouter` | or `openai_compatible` with `LLM_BASE_URL` |
| `LLM_MODEL` | `google/gemini-3.8-flash` | Any model with structured outputs |
| `LLM_FACTS_MODEL`, `LLM_PLANNER_MODEL` | `LLM_MODEL` | Per-layer overrides |
| `RATE_LIMIT_PER_MINUTE` | `20` | Per client IP, `0` disables |
| `TRUST_PROXY` | `false` | Use `X-Forwarded-For` behind a load balancer |

Container image (build from the repository root):

```sh
docker build -f server/Dockerfile -t factviz-server .
docker run -p 8080:8080 -e OPENROUTER_API_KEY=... factviz-server
```

### 2. App

By default the app runs the facts → planner pipeline **on the phone** with the
user's own OpenRouter key: tap the key icon on the home screen, paste a key
from openrouter.ai/keys, and it is stored in Android's encrypted storage and
sent only to OpenRouter. The on-device mode runs the same `ExplainPipeline`
code as the server (`package:factviz_server/pipeline.dart`), so prompts,
validation and the retry policy are identical.

To use a shared server instead (keys stay off phones), build with
`--dart-define=API_BASE_URL=https://your-server`; the key screen then
disappears.


```sh
cd app
flutter run                                              # emulator → http://10.0.2.2:8080
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

Debug builds allow plain HTTP to a local server; release builds need HTTPS.

To preview the charts on a phone without a server, build with the template
gallery enabled:

```sh
flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=SHOW_GALLERY=true
```
In debug builds the home screen has a **template gallery** button (top
right), which previews every template with mock data, with replay and
reduced-motion toggles.

## Sharing

The Share button sends `factviz://app/v/<payload>`. The payload is the
validated facts + plan, gzipped and base64url-encoded. Opening the link
re-renders the visualization **without an LLM call**, and the payload goes
through the same validation and resolution as a fresh result, so a tampered
link cannot render bad data. Some messaging apps don't make custom schemes
clickable; https App Links can be added once there is a domain.

## Tests

```sh
(cd packages/factviz_core && dart test)   # schemas, resolver mapping, units, share codec
(cd server && dart test)                  # prompts, retry loop, client, routes, 5 queries
(cd app && flutter test)                  # screens, flows, 5 queries end to end
(cd app/viz_test && npm install && npm test)   # D3 renderer in headless Chromium
```

`flutter test` uses a stand-in for the WebView. The renderer itself is tested
in Chromium against render JSON exported from the app
(`flutter test viz_test/export_fixtures_test.dart`). `node viz_test/shots.mjs`
saves a screenshot of every fixture to `viz_test/out/`, and
`node viz_test/shots_dir.mjs <dir> <out>` does the same for any folder of render
JSON (for example the library, exported with `check_library.dart --export=<dir>`).

The **five fixed queries** in `fixtures/queries/` (planets → `scale_zoom`,
spaceflight → `timeline`, paper folding → `exponential_growth`, whale vs bus →
`comparison_bars`, water cycle → `process_steps`) run through the server routes
and the full app flow using recorded model output. To run them against the real
model:

```sh
cd server && OPENROUTER_API_KEY=... dart test -t live --run-skipped
```

## Design

The look is borrowed from data journalism (The Pudding, NYT Upshot, Our World
in Data): warm paper, ink, one warm accent, Source Serif 4 headlines and
annotations, Libre Franklin labels (both SIL OFL, in `app/assets/fonts`, and
shared by Flutter and the WebView).

- **D3 templates** (`app/assets/viz/viz.js`, `viz_extra.js`): a log-space
  camera that zooms out across sizes or distances; a scrollable timeline with
  lane-packed labels; a growth curve that morphs between linear and log
  scales; bars that grow and count up; a cycle diagram or step list that
  autoplays; donuts, waffles, treemaps and packed bubbles you can tap for
  detail; a 24-hour clock whose hand sweeps through history; a Natural Earth
  map (world-atlas, Natural Earth data) that frames regional points; line
  charts you can scrub; and a counter that ticks while you watch.
- **Annotations**: `factviz_core` derives callouts from the facts ("Jupiter
  is 29× as wide as Mercury", "Fold 36: still only 6,872 km") and the
  renderer places them with
  [d3-svg-annotation](https://d3-annotation.susielu.com), choosing a spot
  that avoids labels and marks.
- **Real imagery**: NASA photographs of the planets, Sun, Moon and Pluto, and
  silhouettes from PhyloPic and Material Design Icons. The planner can only
  pick from this fixed catalog (`imageCatalog`), and each picture declares
  which shapes it may stand in for. Credits: `app/assets/viz/img/CREDITS.md`.
- **Motion**: Lottie for the loader and logo (generated by
  `app/tool/generate_lottie.py`), and `flutter_animate` for screen and list
  transitions.

The launcher icon and splash images are rendered from `LogoPainter`:

```sh
cd app && flutter test tool/generate_icons_test.dart
```

## Accessibility and motion

The renderer is told about `MediaQuery.disableAnimations` and also honours
`prefers-reduced-motion`. With reduced motion, charts open on their final
frame and process steps don't autoplay. Every chart has an `aria-label`
summary, and timeline events, cycle nodes and controls are labelled buttons. Charts expose
semantic summaries, and labels scale with the system text size up to a limit.

## Adding iOS later

The code is platform-agnostic. Run `flutter create --platforms=ios .` in `app/`,
then register the `factviz` URL scheme in `Info.plist` (`CFBundleURLTypes`) so
share links open the app.
