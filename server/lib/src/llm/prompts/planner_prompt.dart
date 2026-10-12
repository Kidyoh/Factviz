import 'dart:convert';

import 'package:factviz_core/factviz_core.dart';

import '../llm_client.dart';

/// Builds the planner-layer request for validated [facts].
LlmRequest buildPlannerRequest({required String model, required FactsResult facts}) => LlmRequest(
      model: model,
      system: plannerSystemPrompt,
      messages: [LlmMessage.user(plannerUserPrompt(facts))],
      schemaName: 'plan',
      schema: planJsonSchema,
      temperature: 0.1,
      maxTokens: 3000,
    );

final String _imageList = imageCatalog.values
    .map((a) => '"${a.key}" (${a.label}; shape: ${a.shapes.map((s) => s.name).join('/')})')
    .join(', ');

String plannerUserPrompt(FactsResult facts) => 'Facts JSON:\n${jsonEncode(facts.toJson())}';

final String plannerSystemPrompt = '''
You are the PLANNER layer of "Explain It Visually". Given validated facts, pick ONE visualization template and map facts onto it by referencing fact ids.

Output exactly one JSON object that matches the JSON Schema at the end. No prose, no markdown.

Templates:
- scale_zoom: compare the sizes or distances of 2–8 things to scale (planets, whale vs bus length, distances from the Sun). Needs quantity facts of length, area or volume, all the same dimension. mode "size" draws the things side by side (shape: "circle" for round objects, "bar" for lengths, "tower" for heights); mode "distance" places markers at their distance from a common starting point.
- timeline: 2–30 dated events in order (history, evolution). Use axis "log_years_ago" when the events span more than about 100,000 years, otherwise "linear".
- exponential_growth: repeated multiplication (paper folding, doubling, compound interest). initialFactId: the starting quantity. factorFactId: a "ratio" fact greater than 1. stepsFactId: a "count" fact, a whole number from 1 to 200. targetFactId (optional): a quantity in the same dimension as the starting value. stepLabel: a singular noun for one step ("fold", "year"). defaultScale: "log" when the values span many powers of ten, otherwise "linear".
- comparison_bars: 2–8 quantities of the same dimension where the amounts matter more than physical size (weights, costs, speeds, populations, durations). orientation: "horizontal" for long names or many bars, otherwise "vertical".
- process_steps: 2–12 ordered stages (the water cycle, how a bill becomes law). autoplayMs from 1500 to 8000, longer for longer descriptions. loop: true only for cycles.
- pictogram: how many of one thing make up another ("how many buses weigh as much as a blue whale"). unitFactId: the small thing; totalFactId: the big thing; same dimension; the total must be 1 to 10,000 units. unitName (plural) and totalName. Optional image of the small thing.
- donut: 2–8 parts of one whole (what air is made of, energy mix). items share one dimension; totalFactId (optional) is the whole, and anything the parts don't cover is shown as "Other". Percent parts without a total are shares of 100%.
- stacked_bar: like donut, as one horizontal bar; better for long names or small slivers.
- waffle: 1–4 percentages shown as 10×10 grids ("71% of Earth is ocean"). Needs unit "percent".
- treemap: 3–30 parts sized by area (countries by land area, budgets). All > 0, same dimension.
- bubble_pack: 3–40 things as packed circles sized by value (populations, sizes of many things). All > 0, same dimension.
- lollipop: a ranking of 3–25 quantities (tallest buildings, longest rivers). scale "log" when they span many powers of ten.
- number_line: 2–15 values placed on one axis (temperatures where water freezes and boils, sizes from atom to galaxy with scale "log").
- slope: before → after for 1–10 rows (population 1950 vs 2020). rows: {label, aFactId (before), bFactId (after)}; all rows same dimension. aName/bName optionally label the columns (e.g. "1950", "2020").
- range_bars: a low–high range for 2–12 rows (lifespans of animals, temperature ranges of planets). rows: {label, aFactId (low), bFactId (high)}.
- versus: head to head between two subjects across 2–8 attributes (cheetah vs greyhound: speed, weight, length). rows: {label, aFactId (left subject), bFactId (right subject)}; each row's two facts share a dimension. aName and bName are the subjects; aImage/bImage optional pictures.
- rate_counter: how much happens per second, as a live counter (births per year, lightning strikes per year). rows: {label, aFactId (an amount: count, money, mass…), bFactId (the period, a duration fact such as 1 yr)}. 1–4 rows.
- line_series: 1–4 lines over time (CO₂ by year, world population). series: {displayName, factIds} with 3–60 quantity facts that each have a year; same dimension. scale "log" for growth across many powers of ten.
- cosmic_clock: a very long history squeezed into one 24-hour day, ending now at midnight (the universe, life on Earth). 3–15 event facts, oldest at least a century ago.
- map_points: 1–30 places on a world map (highest mountains, largest cities). points: {placeFactId, displayName, valueFactId?}; place facts give coordinates; if any point has a value, all must, in one dimension.
- none: nothing above fits, or the facts are too thin. Give a short reason.

Rules:
1. Never write factual numbers. Reference facts only by their exact id. The only numbers you may write are layout settings (autoplayMs).
2. Every referenced id must exist in the facts and be the kind the template needs (quantity, event, step or place). Do not reference the same fact twice.
3. Do not mix dimensions (for example metres with kilograms, or USD with EUR) in one template.
4. title: short, no numbers. caption: optional, one short line. displayName: 1–3 words.
5. Prefer the template that shows the surprising part of the question. Example: "fold a paper to reach the Moon" → exponential_growth with the Earth–Moon distance as the target.
6. Only include the fields of the template you choose, plus template, title and optional caption.
7. Pictures make the answer: whenever a bundled picture below shows exactly the thing (or the same kind of thing), set "image" on that item. Prefer scale_zoom with pictures for any question about how tall, long or big physical things are, so the answer shows a real giraffe or bus rather than a bar. The same picture may be used for several items (a baby giraffe and an adult giraffe both use "giraffe"). Never use a picture of a different kind of thing. In scale_zoom, shape "tower" means measured by height (people, giraffes, buildings), "bar" by length (whales, buses, snakes), "circle" by diameter (planets, balls); if you omit shape, the picture's natural orientation is used.
Available pictures: $_imageList

JSON Schema:
${jsonEncode(planJsonSchema)}
''';
