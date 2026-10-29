import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/app.dart';
import 'package:philoscroll/src/scroll_background.dart';
import 'package:philoscroll/src/theme.dart';

import 'support.dart';

void main() {
  setUpAll(loadAppFonts);

  test('uses the same texture files as the web scroll', () {
    expect(ScrollBackground.lightTextureAsset, 'assets/textures/old-parchment.jpg');
    expect(ScrollBackground.darkTextureAsset, 'assets/textures/darkslate.jpg');
    expect(
      File('assets/textures/old-parchment.jpg').existsSync(),
      isTrue,
      reason: 'run npm run build or scripts/copy-textures.mjs to sync from prototypes',
    );
    expect(File('assets/textures/darkslate.jpg').existsSync(), isTrue);
  });

  test('dark mode texture matches prototypes darkslate export', () {
    final mobile = File('assets/textures/darkslate.jpg').readAsBytesSync();
    final prototype = File('../prototypes/textures/darkslate.jpg').readAsBytesSync();
    expect(mobile, prototype);
  });

  test('dark mode texture is not the old dark-worn placeholder', () {
    final worn = File('../prototypes/textures/dark-worn.jpg').readAsBytesSync();
    final mobile = File('assets/textures/darkslate.jpg').readAsBytesSync();
    expect(mobile, isNot(equals(worn)));
  });

  testWidgets('shows parchment in light mode and slate in dark mode', (tester) async {
    final quotes = loadTestQuotes();
    await loadAppFonts();
    await tester.pumpWidget(
      PhiloApp(quotes: quotes, random: () => 0.42, reduceMotion: true),
    );
    await tester.pumpAndSettle();

    final lightImage = tester.widget<Image>(find.byKey(const Key('scroll-texture')));
    expect((lightImage.image as AssetImage).assetName, ScrollBackground.lightTextureAsset);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();

    final darkImage = tester.widget<Image>(find.byKey(const Key('scroll-texture')));
    expect((darkImage.image as AssetImage).assetName, ScrollBackground.darkTextureAsset);
  });
}
