import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/src/theme.dart';

void main() {
  test('measures black on white at the WCAG maximum', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 1e-5));
    expect(contrastRatio(const Color(0xFFFFFFFF), const Color(0xFF000000)), closeTo(21, 1e-5));
  });

  test('keeps text, accents, and control borders readable in both appearances', () {
    for (final palette in [PhiloPalette.light, PhiloPalette.dark]) {
      expect(contrastRatio(palette.text, palette.bg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(palette.muted, palette.bg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(palette.accent, palette.bg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(palette.line, palette.bg), greaterThanOrEqualTo(3));
    }
  });
}
