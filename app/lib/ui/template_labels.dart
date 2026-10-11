import 'package:factviz_core/factviz_core.dart';

/// Short reader-facing names for chart types, used as kickers.
String templateLabel(TemplateId t) => switch (t) {
      TemplateId.scaleZoom => 'To scale',
      TemplateId.timeline => 'Timeline',
      TemplateId.exponentialGrowth => 'Growth',
      TemplateId.comparisonBars => 'Comparison',
      TemplateId.processSteps => 'Process',
      TemplateId.pictogram => 'Pictogram',
      TemplateId.donut => 'Shares',
      TemplateId.stackedBar => 'Breakdown',
      TemplateId.waffle => 'Out of 100',
      TemplateId.treemap => 'Treemap',
      TemplateId.bubblePack => 'Bubbles',
      TemplateId.lollipop => 'Ranking',
      TemplateId.numberLine => 'On one scale',
      TemplateId.slope => 'Then and now',
      TemplateId.rangeBars => 'Ranges',
      TemplateId.versus => 'Head to head',
      TemplateId.rateCounter => 'Live counter',
      TemplateId.lineSeries => 'Over time',
      TemplateId.cosmicClock => 'In one day',
      TemplateId.mapPoints => 'Map',
      TemplateId.none => 'Facts',
    };
