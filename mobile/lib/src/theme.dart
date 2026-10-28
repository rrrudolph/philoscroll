import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class PhiloPalette {
  const PhiloPalette({
    required this.brightness,
    required this.bg,
    required this.text,
    required this.muted,
    required this.accent,
    required this.line,
    required this.glow,
  });

  final Brightness brightness;
  final Color bg;
  final Color text;
  final Color muted;
  final Color accent;
  final Color line;
  final Color glow;

  static const light = PhiloPalette(
    brightness: Brightness.light,
    bg: Color(0xFFFDFBF7),
    text: Color(0xFF1F2937),
    muted: Color(0xFF4B5563),
    accent: Color(0xFF3E5140),
    line: Color(0xFF908778),
    glow: Color(0x243E5140),
  );

  static const dark = PhiloPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF121824),
    text: Color(0xFFE5E7EB),
    muted: Color(0xFF9AA3B2),
    accent: Color(0xFFB7C9A3),
    line: Color(0xFF6B768A),
    glow: Color(0x1AB7C9A3),
  );

  static PhiloPalette forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  Color get glowClear => glow.withAlpha(0);
}

class PhiloTheme extends InheritedWidget {
  const PhiloTheme({super.key, required this.palette, required super.child});

  final PhiloPalette palette;

  static PhiloPalette of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<PhiloTheme>();
    assert(theme != null, 'PhiloTheme is missing above this widget');
    return theme!.palette;
  }

  @override
  bool updateShouldNotify(PhiloTheme oldWidget) => oldWidget.palette != palette;
}

double relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.04045 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

double contrastRatio(Color foreground, Color background) {
  final first = relativeLuminance(foreground);
  final second = relativeLuminance(background);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
