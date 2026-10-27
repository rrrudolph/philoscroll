import 'dart:math' as math;
import 'dart:ui';

class PhiloColors {
  const PhiloColors._();

  static const bg = Color(0xFF121824);
  static const text = Color(0xFFE5E7EB);
  static const muted = Color(0xFF9AA3B2);
  static const accent = Color(0xFFB7C9A3);
  static const line = Color(0xFF6B768A);
  static const glow = Color(0x1AB7C9A3);
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
