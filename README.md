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
 3. Render layer: PlanResolver (on device again) → TemplateProps → template widget
```

- **Facts layer**: strict JSON with values, units, and a short source note per
  number. When the model is unsure it returns `confidence: "low"` with a note,
  and the app shows a warning badge.
- **Planner layer**: picks one of `scale_zoom`, `timeline`,
  `exponential_growth`, `comparison_bars`, `process_steps` or `none`, and
  **refers to facts only by id**. It cannot introduce numbers.
- **Render layer**: `PlanResolver` turns plan + facts into typed props
  (unit conversion, dimension checks, sorting). Every number on screen comes
  from a fact.

Both LLM outputs are validated by `factviz_core`, a pure-Dart package shared
by the server and the app. On a validation failure the server retries once,
feeding the errors back to the model. If that also fails, the app shows
*"Couldn't visualize this one, try rephrasing."*

## Repository layout

```
packages/factviz_core/   schemas, validation, units, PlanResolver, ShareCodec, JSON Schemas
server/                  shelf API: OpenRouter client, prompts, validated calls, routes
app/                     Flutter app (Android; iOS later)
  lib/templates/         one folder per template + mock_data.dart (Dev Gallery only)
  lib/ui/                shared widgets (search, stages, key numbers, badges, errors)
  lib/screens/           home, result, dev gallery
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

```sh
cd app
flutter run                                              # emulator → http://10.0.2.2:8080
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

Debug builds allow plain HTTP to a local server; release builds need HTTPS.
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
(cd app && flutter test)                  # templates, flows, 5 queries end to end
```

The **five fixed queries** in `fixtures/queries/` (planets → `scale_zoom`,
spaceflight → `timeline`, paper folding → `exponential_growth`, whale vs bus →
`comparison_bars`, water cycle → `process_steps`) run through the server routes
and the full app flow using recorded model output. To run them against the real
model:

```sh
cd server && OPENROUTER_API_KEY=... dart test -t live --run-skipped
```

## Design

The app has a dark-only "deep space" look: a drifting, twinkling starfield
with nebula glow, frosted-glass cards, Space Grotesk headings and Inter body
text (both bundled, SIL OFL; licenses in `app/assets/fonts`). The templates
draw lit spheres, glowing bars and lines, light trails, and a spark burst when
exponential growth reaches its target. Shared painting helpers live in
`app/lib/templates/common/viz_paint.dart`; the cosmic widgets are in
`app/lib/ui/cosmic/`.

The launcher icon, adaptive-icon foreground and splash images are rendered
from the same `OrbitMarkPainter` as the in-app logo:

```sh
cd app && flutter test tool/generate_icons_test.dart
```

## Accessibility and motion

Templates read `MediaQuery.disableAnimations`. With reduced motion they show
their final frame immediately, process steps don't autoplay, and the
starfield and logo hold still. Charts expose
semantic summaries, and labels scale with the system text size up to a limit.

## Adding iOS later

The code is platform-agnostic. Run `flutter create --platforms=ios .` in `app/`,
then register the `factviz` URL scheme in `Info.plist` (`CFBundleURLTypes`) so
share links open the app.
