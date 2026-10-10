// Mock data for previewing templates in the Dev Gallery.
//
// This is the ONLY place in the app with hardcoded facts. Real results always
// come from the facts layer via the API. Mocks still go through the same
// validation and resolution as live data, so a broken mock fails loudly.

import 'package:factviz_core/factviz_core.dart';

class MockSample {
  const MockSample(this.name, this.visualization);

  final String name;
  final Visualization visualization;
}

QuantityFact _q(String id, String label, double value, String unit, String source, {bool approx = false}) =>
    QuantityFact(id: id, label: label, value: value, unit: units[unit]!, approximate: approx, sourceNote: source);

EventFact _e(String id, String label, int year, String source, {int? month, int? day, String? description}) =>
    EventFact(id: id, label: label, year: year, month: month, day: day, description: description, sourceNote: source);

StepFact _s(int order, String id, String title, String description, String source) =>
    StepFact(id: id, label: title, order: order, title: title, description: description, sourceNote: source);

FactsResult _facts(String query, String explanation, List<Fact> facts, {Confidence confidence = Confidence.high, String? note}) =>
    FactsResult(
      query: query,
      topic: query,
      confidence: confidence,
      confidenceNote: note,
      explanation: explanation,
      facts: facts,
    );

MockSample _sample(String name, FactsResult facts, Plan plan) =>
    MockSample(name, Visualization.build(facts, plan).valueOrThrow);

final List<MockSample> mockSamples = [
  _sample(
    'scale_zoom · lengths (bars)',
    _facts('Blue whale vs a bus', 'A blue whale is about twice as long as a school bus.', [
      _q('whale_length', 'Adult blue whale length', 25, 'm', 'NOAA Fisheries; typically 24–30 m', approx: true),
      _q('bus_length', 'School bus length', 12, 'm', 'Typical full-size US school bus', approx: true),
      _q('human_height', 'Adult human height', 1.7, 'm', 'Typical adult height', approx: true),
    ]),
    const ScaleZoomPlan(title: 'Blue whale vs a school bus', mode: ScaleMode.size, items: [
      ScaleItemRef(factId: 'human_height', displayName: 'Person', shape: ItemShape.tower),
      ScaleItemRef(factId: 'bus_length', displayName: 'School bus', shape: ItemShape.bar),
      ScaleItemRef(factId: 'whale_length', displayName: 'Blue whale', shape: ItemShape.bar),
    ]),
  ),
  _sample(
    'scale_zoom · atom to Earth (huge range)',
    _facts('From an atom to the Earth', 'Sizes in nature span more than seventeen powers of ten.', [
      _q('atom', 'Hydrogen atom diameter', 0.1, 'nm', 'Approximate atomic diameter', approx: true),
      _q('hair', 'Human hair width', 70, 'um', 'Typical hair, 17–180 µm', approx: true),
      _q('person', 'Adult human height', 1.7, 'm', 'Typical adult height', approx: true),
      _q('everest', 'Mount Everest height', 8.849, 'km', '2020 China–Nepal survey'),
      _q('earth', 'Earth diameter', 12742, 'km', 'NASA mean diameter'),
    ]),
    const ScaleZoomPlan(title: 'From an atom to the Earth', mode: ScaleMode.size, items: [
      ScaleItemRef(factId: 'atom', displayName: 'Atom'),
      ScaleItemRef(factId: 'hair', displayName: 'Hair width'),
      ScaleItemRef(factId: 'person', displayName: 'Person', shape: ItemShape.tower),
      ScaleItemRef(factId: 'everest', displayName: 'Everest', shape: ItemShape.tower),
      ScaleItemRef(factId: 'earth', displayName: 'Earth'),
    ]),
  ),
  _sample(
    'scale_zoom · distances',
    _facts('How far are the planets from the Sun', 'The outer planets are far more spread out than the inner ones.', [
      _q('mercury', 'Mercury distance from Sun', 0.387, 'au', 'NASA mean orbital distance'),
      _q('earth', 'Earth distance from Sun', 1, 'au', 'Definition of the astronomical unit'),
      _q('jupiter', 'Jupiter distance from Sun', 5.2, 'au', 'NASA mean orbital distance'),
      _q('neptune', 'Neptune distance from Sun', 30.07, 'au', 'NASA mean orbital distance'),
    ]),
    const ScaleZoomPlan(title: 'Distances from the Sun', mode: ScaleMode.distance, items: [
      ScaleItemRef(factId: 'mercury', displayName: 'Mercury'),
      ScaleItemRef(factId: 'earth', displayName: 'Earth'),
      ScaleItemRef(factId: 'jupiter', displayName: 'Jupiter'),
      ScaleItemRef(factId: 'neptune', displayName: 'Neptune'),
    ]),
  ),
  _sample(
    'timeline · deep time (log)',
    _facts('History of life on Earth', 'Most of Earth\'s history happened long before humans appeared.', [
      _e('earth_forms', 'Earth forms', -4540000000, 'USGS radiometric dating'),
      _e('first_life', 'Earliest evidence of life', -3700000000, 'Geological record, approximate'),
      _e('cambrian', 'Cambrian explosion', -538000000, 'International Commission on Stratigraphy'),
      _e('dinosaurs_end', 'Non-avian dinosaurs go extinct', -66000000, 'K–Pg boundary dating'),
      _e('homo_sapiens', 'Homo sapiens appears', -300000, 'Jebel Irhoud fossils, approximate'),
      _e('writing', 'Earliest writing', -3200, 'Mesopotamian cuneiform, approximate'),
    ]),
    const TimelinePlan(title: 'Life on Earth', axis: TimeAxis.logYearsAgo, eventFactIds: [
      'earth_forms', 'first_life', 'cambrian', 'dinosaurs_end', 'homo_sapiens', 'writing', //
    ]),
  ),
  _sample(
    'timeline · computing (linear)',
    _facts('History of computers', 'Computers shrank from rooms to pockets in about sixty years.', [
      _e('eniac', 'ENIAC unveiled', 1946, 'Smithsonian / University of Pennsylvania', month: 2, day: 14),
      _e('transistor', 'Transistor invented', 1947, 'Bell Labs', month: 12, day: 16),
      _e('ibm_pc', 'IBM PC released', 1981, 'IBM archives', month: 8, day: 12),
      _e('www', 'World Wide Web goes public', 1991, 'CERN', month: 8, day: 6),
      _e('iphone', 'iPhone announced', 2007, 'Apple press release', month: 1, day: 9),
    ]),
    const TimelinePlan(title: 'Milestones in computing', axis: TimeAxis.linear, eventFactIds: [
      'eniac', 'transistor', 'ibm_pc', 'www', 'iphone', //
    ]),
  ),
  _sample(
    'exponential_growth · paper to the Moon',
    _facts('Fold a paper 42 times to reach the Moon', 'Each fold doubles the thickness.', [
      _q('paper', 'Thickness of a sheet of paper', 0.1, 'mm', 'Typical office paper', approx: true),
      _q('factor', 'Thickness multiplier per fold', 2, 'ratio', 'Each fold doubles the layers'),
      _q('folds', 'Number of folds', 42, 'count', 'From your question'),
      _q('moon', 'Average Earth–Moon distance', 384400, 'km', 'NASA mean distance', approx: true),
    ]),
    const ExponentialGrowthPlan(
      title: 'Folding paper to the Moon',
      initialFactId: 'paper',
      factorFactId: 'factor',
      stepsFactId: 'folds',
      targetFactId: 'moon',
      stepLabel: 'fold',
      defaultScale: AxisScale.linear,
    ),
  ),
  _sample(
    'exponential_growth · compound interest',
    _facts('\$1,000 at 7% a year for 30 years', 'Interest earns interest, so growth speeds up over time.', [
      _q('principal', 'Starting amount', 1000, 'USD', 'From your question'),
      _q('rate', 'Growth per year at 7%', 1.07, 'ratio', 'From your question (7% annual return)'),
      _q('years', 'Years invested', 30, 'count', 'From your question'),
    ]),
    const ExponentialGrowthPlan(
      title: 'Compound interest',
      initialFactId: 'principal',
      factorFactId: 'rate',
      stepsFactId: 'years',
      stepLabel: 'year',
      defaultScale: AxisScale.linear,
    ),
  ),
  _sample(
    'comparison_bars · weights (horizontal)',
    _facts('Blue whale vs a school bus by weight', 'A blue whale outweighs many buses.', [
      _q('whale', 'Adult blue whale mass', 150, 't', 'NOAA Fisheries; 100–150 t', approx: true),
      _q('bus', 'School bus mass', 11, 't', 'Typical US full-size bus', approx: true),
      _q('elephant', 'African elephant mass', 6, 't', 'Smithsonian National Zoo', approx: true),
    ], confidence: Confidence.low, note: 'Whale weights vary widely between individuals.'),
    const ComparisonBarsPlan(title: 'Blue whale vs a school bus', orientation: BarOrientation.horizontal, bars: [
      BarRef(factId: 'whale', displayName: 'Blue whale'),
      BarRef(factId: 'bus', displayName: 'School bus'),
      BarRef(factId: 'elephant', displayName: 'African elephant'),
    ]),
  ),
  _sample(
    'comparison_bars · heights (vertical)',
    _facts('Tallest structures', 'The Burj Khalifa is more than twice as tall as the Eiffel Tower.', [
      _q('burj', 'Burj Khalifa height', 828, 'm', 'Council on Tall Buildings and Urban Habitat'),
      _q('shanghai', 'Shanghai Tower height', 632, 'm', 'Council on Tall Buildings and Urban Habitat'),
      _q('eiffel', 'Eiffel Tower height', 330, 'm', 'Société d\'Exploitation de la Tour Eiffel'),
      _q('liberty', 'Statue of Liberty (with pedestal)', 93, 'm', 'US National Park Service'),
    ]),
    const ComparisonBarsPlan(title: 'How tall are they?', orientation: BarOrientation.vertical, bars: [
      BarRef(factId: 'burj', displayName: 'Burj Khalifa'),
      BarRef(factId: 'shanghai', displayName: 'Shanghai Tower'),
      BarRef(factId: 'eiffel', displayName: 'Eiffel Tower'),
      BarRef(factId: 'liberty', displayName: 'Statue of Liberty'),
    ]),
  ),
  _sample(
    'process_steps · water cycle (loop)',
    _facts('How the water cycle works', 'Water keeps moving between the land, sea and sky.', [
      _s(1, 'evaporation', 'Evaporation', 'The Sun heats water, turning it into vapor that rises.', 'USGS Water Science School'),
      _s(2, 'condensation', 'Condensation', 'Vapor cools into droplets that form clouds.', 'USGS Water Science School'),
      _s(3, 'precipitation', 'Precipitation', 'Droplets fall as rain, snow, sleet or hail.', 'USGS Water Science School'),
      _s(4, 'collection', 'Collection', 'Water gathers in rivers, lakes, oceans and underground.', 'USGS Water Science School'),
    ]),
    const ProcessStepsPlan(
      title: 'The water cycle',
      stepFactIds: ['evaporation', 'condensation', 'precipitation', 'collection'],
      autoplayMs: 3000,
      loop: true,
    ),
  ),
  _sample(
    'process_steps · how a bill becomes law',
    _facts('How a bill becomes law in the US', 'A bill must pass both chambers of Congress and be signed by the President.', [
      _s(1, 'introduce', 'Introduction', 'A member of Congress introduces the bill in the House or Senate.', 'US House of Representatives'),
      _s(2, 'committee', 'Committee', 'A committee studies, amends and votes on the bill.', 'US House of Representatives'),
      _s(3, 'floor', 'Floor vote', 'The full chamber debates and votes on the bill.', 'US House of Representatives'),
      _s(4, 'other_chamber', 'Other chamber', 'The other chamber repeats the process and must pass the same text.', 'US Senate'),
      _s(5, 'president', 'President', 'The President signs the bill into law or vetoes it.', 'US House of Representatives'),
    ]),
    const ProcessStepsPlan(
      title: 'How a bill becomes law',
      stepFactIds: ['introduce', 'committee', 'floor', 'other_chamber', 'president'],
      autoplayMs: 3500,
      loop: false,
    ),
  ),
  _sample(
    'none · fact card fallback',
    _facts('What is the best pizza topping?', 'There is no factual answer; it is a matter of taste.', const [],
        confidence: Confidence.low, note: 'This is an opinion, not a measurable fact.'),
    const NonePlan(title: 'Best pizza topping', reason: 'This is a matter of taste, so there is nothing to measure.'),
  ),
];
