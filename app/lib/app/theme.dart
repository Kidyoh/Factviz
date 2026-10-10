import 'package:flutter/material.dart';

/// Colours used by the render templates, tuned separately for light and
/// dark so charts stay legible in both.
@immutable
class VizPalette extends ThemeExtension<VizPalette> {
  const VizPalette({
    required this.series,
    required this.axis,
    required this.grid,
    required this.label,
    required this.mutedLabel,
    required this.target,
    required this.surface,
  });

  /// Categorical colours, assigned to items in order.
  final List<Color> series;
  final Color axis;
  final Color grid;
  final Color label;
  final Color mutedLabel;

  /// Highlight for goals and thresholds (e.g. "reaches the Moon").
  final Color target;

  /// Background behind the visualization canvas.
  final Color surface;

  Color seriesAt(int i) => series[i % series.length];

  static const light = VizPalette(
    series: [
      Color(0xFF3B5BDB),
      Color(0xFFE8590C),
      Color(0xFF2B8A3E),
      Color(0xFFC2255C),
      Color(0xFF1098AD),
      Color(0xFF7048E8),
      Color(0xFFB08800),
      Color(0xFF5C677D),
    ],
    axis: Color(0xFF495057),
    grid: Color(0x1F212529),
    label: Color(0xFF1B1E24),
    mutedLabel: Color(0xFF5F6670),
    target: Color(0xFFD9480F),
    surface: Color(0xFFF4F6FB),
  );

  static const dark = VizPalette(
    series: [
      Color(0xFF7C9CFF),
      Color(0xFFFF9F5A),
      Color(0xFF69DB7C),
      Color(0xFFFF7EB0),
      Color(0xFF4FD6EA),
      Color(0xFFB197FC),
      Color(0xFFFFD43B),
      Color(0xFFADB5BD),
    ],
    axis: Color(0xFFADB5BD),
    grid: Color(0x24FFFFFF),
    label: Color(0xFFF1F3F5),
    mutedLabel: Color(0xFFA5ADB8),
    target: Color(0xFFFFA94D),
    surface: Color(0xFF151A26),
  );

  @override
  VizPalette copyWith({
    List<Color>? series,
    Color? axis,
    Color? grid,
    Color? label,
    Color? mutedLabel,
    Color? target,
    Color? surface,
  }) =>
      VizPalette(
        series: series ?? this.series,
        axis: axis ?? this.axis,
        grid: grid ?? this.grid,
        label: label ?? this.label,
        mutedLabel: mutedLabel ?? this.mutedLabel,
        target: target ?? this.target,
        surface: surface ?? this.surface,
      );

  @override
  VizPalette lerp(VizPalette? other, double t) {
    if (other == null) return this;
    return VizPalette(
      series: [
        for (var i = 0; i < series.length; i++) Color.lerp(series[i], other.series[i], t)!,
      ],
      axis: Color.lerp(axis, other.axis, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      label: Color.lerp(label, other.label, t)!,
      mutedLabel: Color.lerp(mutedLabel, other.mutedLabel, t)!,
      target: Color.lerp(target, other.target, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
    );
  }
}

extension VizPaletteContext on BuildContext {
  VizPalette get viz => Theme.of(this).extension<VizPalette>()!;
}

const _seed = Color(0xFF3B5BDB);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: isDark ? const Color(0xFF0E121B) : const Color(0xFFFFFFFF),
    extensions: [isDark ? VizPalette.dark : VizPalette.light],
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
    ),
  );
}
