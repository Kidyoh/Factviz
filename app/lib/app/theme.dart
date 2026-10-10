import 'package:flutter/material.dart';

/// Core colours of the cinematic "deep space" look.
abstract final class Cosmos {
  static const Color void0 = Color(0xFF04060E);
  static const Color void1 = Color(0xFF090E22);
  static const Color void2 = Color(0xFF111A3A);

  static const Color text = Color(0xFFF3F5FF);
  static const Color textMuted = Color(0xFFA6AECB);
  static const Color textFaint = Color(0xFF6A7296);

  static const Color cyan = Color(0xFF5CE1FF);
  static const Color violet = Color(0xFF9C8CFF);
  static const Color pink = Color(0xFFFF7AC6);
  static const Color amber = Color(0xFFFFC46B);
  static const Color mint = Color(0xFF67F5C2);
  static const Color coral = Color(0xFFFF9F6B);

  /// Signature gradient for titles, active states and highlights.
  static const LinearGradient aurora = LinearGradient(colors: [cyan, violet, pink]);

  static const Color glassFill = Color(0x14FFFFFF);
  static const Color glassBorder = Color(0x2EFFFFFF);
}

/// Colours used by the render templates.
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
    required this.surfaceTop,
  });

  /// Luminous categorical colours, assigned to items in order.
  final List<Color> series;
  final Color axis;
  final Color grid;
  final Color label;
  final Color mutedLabel;

  /// Highlight for goals and thresholds (e.g. "reaches the Moon").
  final Color target;

  /// Canvas background, as a vertical gradient from [surfaceTop] to [surface].
  final Color surface;
  final Color surfaceTop;

  Color seriesAt(int i) => series[i % series.length];

  static const cosmic = VizPalette(
    series: [
      Cosmos.cyan,
      Cosmos.coral,
      Cosmos.violet,
      Cosmos.mint,
      Cosmos.pink,
      Cosmos.amber,
      Color(0xFF6BA8FF),
      Color(0xFFC9D1E8),
    ],
    axis: Color(0x8CC9D1F0),
    grid: Color(0x1AFFFFFF),
    label: Cosmos.text,
    mutedLabel: Cosmos.textMuted,
    target: Cosmos.amber,
    surface: Color(0xFF070B1C),
    surfaceTop: Color(0xFF101836),
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
    Color? surfaceTop,
  }) =>
      VizPalette(
        series: series ?? this.series,
        axis: axis ?? this.axis,
        grid: grid ?? this.grid,
        label: label ?? this.label,
        mutedLabel: mutedLabel ?? this.mutedLabel,
        target: target ?? this.target,
        surface: surface ?? this.surface,
        surfaceTop: surfaceTop ?? this.surfaceTop,
      );

  @override
  VizPalette lerp(VizPalette? other, double t) {
    if (other == null) return this;
    return VizPalette(
      series: [for (var i = 0; i < series.length; i++) Color.lerp(series[i], other.series[i], t)!],
      axis: Color.lerp(axis, other.axis, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      label: Color.lerp(label, other.label, t)!,
      mutedLabel: Color.lerp(mutedLabel, other.mutedLabel, t)!,
      target: Color.lerp(target, other.target, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceTop: Color.lerp(surfaceTop, other.surfaceTop, t)!,
    );
  }
}

extension VizPaletteContext on BuildContext {
  VizPalette get viz => Theme.of(this).extension<VizPalette>()!;
}

const String displayFont = 'SpaceGrotesk';
const String bodyFont = 'Inter';

/// The app is dark-only: the cinematic look depends on it.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Cosmos.violet,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Cosmos.cyan,
    onPrimary: Cosmos.void0,
    secondary: Cosmos.violet,
    tertiary: Cosmos.pink,
    surface: Cosmos.void1,
    onSurface: Cosmos.text,
    onSurfaceVariant: Cosmos.textMuted,
    outline: const Color(0x40FFFFFF),
    outlineVariant: const Color(0x1FFFFFFF),
    surfaceContainerLow: const Color(0xFF0D1330),
    surfaceContainer: const Color(0xFF121A3C),
    surfaceContainerHigh: const Color(0xFF182148),
    errorContainer: const Color(0x33FFC46B),
    onErrorContainer: Cosmos.amber,
  );

  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: bodyFont).textTheme;
  TextStyle? display(TextStyle? s, {double? spacing}) =>
      s?.copyWith(fontFamily: displayFont, fontWeight: FontWeight.w700, letterSpacing: spacing, color: Cosmos.text);
  final textTheme = base
      .copyWith(
        displayLarge: display(base.displayLarge, spacing: -1.5),
        displayMedium: display(base.displayMedium, spacing: -1.2),
        displaySmall: display(base.displaySmall, spacing: -1),
        headlineLarge: display(base.headlineLarge, spacing: -0.8),
        headlineMedium: display(base.headlineMedium, spacing: -0.6),
        headlineSmall: display(base.headlineSmall, spacing: -0.4),
        titleLarge: display(base.titleLarge, spacing: -0.2),
      )
      .apply(bodyColor: Cosmos.text, displayColor: Cosmos.text);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: bodyFont,
    textTheme: textTheme,
    scaffoldBackgroundColor: Cosmos.void0,
    extensions: const [VizPalette.cosmic],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Cosmos.text),
      iconTheme: const IconThemeData(color: Cosmos.text),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Cosmos.text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Cosmos.cyan,
        foregroundColor: Cosmos.void0,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontFamily: bodyFont),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Cosmos.text,
        side: const BorderSide(color: Cosmos.glassBorder),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: bodyFont),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Cosmos.cyan.withValues(alpha: 0.18) : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Cosmos.cyan : Cosmos.textMuted,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: Cosmos.glassBorder)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Cosmos.cyan,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
      thumbColor: Colors.white,
      overlayColor: Cosmos.cyan.withValues(alpha: 0.16),
      trackHeight: 3,
      valueIndicatorColor: Cosmos.void2,
      valueIndicatorTextStyle: const TextStyle(color: Cosmos.text, fontFamily: bodyFont),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Cosmos.cyan,
      linearTrackColor: Colors.white.withValues(alpha: 0.08),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Cosmos.glassFill,
      selectedColor: Cosmos.cyan.withValues(alpha: 0.18),
      side: const BorderSide(color: Cosmos.glassBorder),
      labelStyle: const TextStyle(color: Cosmos.text, fontFamily: bodyFont, fontWeight: FontWeight.w500),
      shape: const StadiumBorder(),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF0E1432),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0x55FFFFFF),
    ),
    dividerTheme: const DividerThemeData(color: Color(0x14FFFFFF), thickness: 1),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Cosmos.cyan,
      selectionColor: Cosmos.cyan.withValues(alpha: 0.3),
      selectionHandleColor: Cosmos.cyan,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Cosmos.glassFill,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Cosmos.glassBorder),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
