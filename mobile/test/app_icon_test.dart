import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _loadAppIcon() async {
  final bytes = File('assets/icon/app_icon.png').readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

double _lum(int r, int g, int b) => 0.299 * r + 0.587 * g + 0.114 * b;

void main() {
  test('launcher icon has no pale halo along the top corners', () async {
    final image = await _loadAppIcon();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);

    final w = image.width;
    final data = bytes!.buffer.asUint8List();
    var haloPixels = 0;

    for (var y = 0; y < 12; y++) {
      for (final xRange in <(int, int)>[(0, 120), (w - 120, w)]) {
        for (var x = xRange.$1; x < xRange.$2; x++) {
          final i = (y * w + x) * 4;
          final r = data[i];
          final g = data[i + 1];
          final b = data[i + 2];
          if (_lum(r, g, b) > 80) {
            haloPixels++;
          }
        }
      }
    }

    expect(
      haloPixels,
      0,
      reason: 'pale export halos should not sit on the top corner bands',
    );
  });

  test('launcher icon outer border has no near-white pixels', () async {
    final image = await _loadAppIcon();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);

    final w = image.width;
    final h = image.height;
    final data = bytes!.buffer.asUint8List();

    bool nearWhite(int x, int y) {
      final i = (y * w + x) * 4;
      final r = data[i];
      final g = data[i + 1];
      final b = data[i + 2];
      return r > 230 && g > 230 && b > 225;
    }

    for (var x = 0; x < w; x++) {
      expect(nearWhite(x, 0), isFalse, reason: 'top edge at x=$x');
      expect(nearWhite(x, h - 1), isFalse, reason: 'bottom edge at x=$x');
    }
    for (var y = 0; y < h; y++) {
      expect(nearWhite(0, y), isFalse, reason: 'left edge at y=$y');
      expect(nearWhite(w - 1, y), isFalse, reason: 'right edge at y=$y');
    }
  });
}
