import 'package:flutter/material.dart';

/// Editorial design tokens: paper, ink and one warm accent, like a
/// newspaper graphics desk. Shared with the D3 renderer (assets/viz/viz.css).
abstract final class Palette {
  static const Color paper = Color(0xFFF7F4EE);
  static const Color paperDeep = Color(0xFFEFEAE0);
  static const Color ink = Color(0xFF171717);
  static const Color ink2 = Color(0xFF4E4B47);
  static const Color ink3 = Color(0xFF8C877F);
  static const Color rule = Color(0xFFDAD3C5);
  static const Color rule2 = Color(0xFFEAE4D8);
  static const Color accent = Color(0xFFC8553D);
  static const Color blue = Color(0xFF2A6F97);
  static const Color warn = Color(0xFF9A5B00);
  static const Color warnBg = Color(0xFFF6E7C8);
}

const String serif = 'SourceSerif';
const String sans = 'LibreFranklin';

/// Text styles with names that describe their editorial role.
abstract final class Txt {
  static const TextStyle kicker = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: Palette.accent,
  );
  static const TextStyle headline = TextStyle(
    fontFamily: serif,
    fontSize: 30,
    height: 1.12,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: Palette.ink,
  );
  static const TextStyle dek = TextStyle(
    fontFamily: serif,
    fontSize: 17,
    height: 1.4,
    fontStyle: FontStyle.italic,
    color: Palette.ink2,
  );
  static const TextStyle body = TextStyle(fontFamily: serif, fontSize: 17, height: 1.55, color: Palette.ink);
  static const TextStyle label = TextStyle(fontFamily: sans, fontSize: 13, fontWeight: FontWeight.w600, color: Palette.ink);
  static const TextStyle caption = TextStyle(fontFamily: sans, fontSize: 12, height: 1.35, color: Palette.ink3);
  static const TextStyle figure = TextStyle(
    fontFamily: serif,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: Palette.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Palette.accent, brightness: Brightness.light).copyWith(
    primary: Palette.ink,
    onPrimary: Palette.paper,
    secondary: Palette.accent,
    surface: Palette.paper,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.ink2,
    outline: Palette.rule,
    outlineVariant: Palette.rule2,
    surfaceContainerLow: Palette.paperDeep,
    errorContainer: Palette.warnBg,
    onErrorContainer: Palette.warn,
  );
  final base = ThemeData(useMaterial3: true, fontFamily: sans).textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: sans,
    scaffoldBackgroundColor: Palette.paper,
    textTheme: base.copyWith(
      headlineMedium: Txt.headline,
      headlineSmall: Txt.headline.copyWith(fontSize: 24),
      titleLarge: const TextStyle(fontFamily: serif, fontSize: 20, fontWeight: FontWeight.w600, color: Palette.ink),
      bodyLarge: Txt.body,
      bodyMedium: const TextStyle(fontFamily: sans, fontSize: 14, height: 1.4, color: Palette.ink),
      bodySmall: Txt.caption,
      labelSmall: Txt.kicker,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Palette.ink,
      titleTextStyle: TextStyle(fontFamily: sans, fontSize: 13, fontWeight: FontWeight.w600, color: Palette.ink2),
    ),
    dividerTheme: const DividerThemeData(color: Palette.rule, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.ink,
        foregroundColor: Palette.paper,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        side: const BorderSide(color: Palette.ink),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Palette.accent, selectionColor: Color(0x33C8553D)),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Palette.paper, surfaceTintColor: Colors.transparent),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
