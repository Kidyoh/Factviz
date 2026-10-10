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
      maxTokens: 2000,
    );

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
- none: nothing above fits, or the facts are too thin. Give a short reason.

Rules:
1. Never write factual numbers. Reference facts only by their exact id. The only numbers you may write are layout settings (autoplayMs).
2. Every referenced id must exist in the facts and be the kind the template needs (quantity, event or step). Do not reference the same fact twice.
3. Do not mix dimensions (for example metres with kilograms, or USD with EUR) in one template.
4. title: short, no numbers. caption: optional, one short line. displayName: 1–3 words.
5. Prefer the template that shows the surprising part of the question. Example: "fold a paper to reach the Moon" → exponential_growth with the Earth–Moon distance as the target.
6. Only include the fields of the template you choose, plus template, title and optional caption.

JSON Schema:
${jsonEncode(planJsonSchema)}
''';
