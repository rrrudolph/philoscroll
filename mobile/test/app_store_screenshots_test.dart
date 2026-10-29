import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/app.dart';
import 'package:philoscroll/src/quote.dart';
import 'package:philoscroll/src/scroll_page.dart';

import 'support.dart';

/// iPhone logical size × [devicePixelRatio] → App Store PNG dimensions.
class _PhoneSpec {
  const _PhoneSpec({
    required this.logical,
    required this.devicePixelRatio,
    required this.physical,
  });

  final Size logical;
  final double devicePixelRatio;
  final Size physical;

  /// Typical safe area (Dynamic Island / home indicator), logical pt.
  EdgeInsets get safePadding => const EdgeInsets.fromLTRB(0, 59, 0, 34);

  static const inch67 = _PhoneSpec(
    logical: Size(430, 932),
    devicePixelRatio: 3,
    physical: Size(1290, 2796),
  );

  static const inch61 = _PhoneSpec(
    logical: Size(393, 852),
    devicePixelRatio: 3,
    physical: Size(1179, 2556),
  );
}

/// App Store iPhone screenshots (portrait).
///
/// | Prefix | PNG size | ASC slot |
/// |--------|----------|----------|
/// | `app_store_6_7_*` | 1290×2796 | 6.7" / Dynamic Island (medium) |
/// | `app_store_6_1_*` | 1179×2556 | 6.1" / 6.3" |
///
/// Run: `flutter test test/app_store_screenshots_test.dart --update-goldens`
void main() {
  final quotes = loadTestQuotes();

  setUpAll(loadAppFonts);

  Future<void> pump(WidgetTester tester, _PhoneSpec phone) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: phone.logical,
          devicePixelRatio: phone.devicePixelRatio,
          padding: phone.safePadding,
          viewPadding: phone.safePadding,
          platformBrightness: Brightness.light,
        ),
        child: PhiloApp(
          quotes: quotes,
          random: () => 0.42,
          reduceMotion: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> swipeUp(WidgetTester tester) async {
    final start = tester.getCenter(find.byType(ScrollPage));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 180));
    await gesture.moveBy(const Offset(0, -120));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester tester,
    _PhoneSpec phone,
    String golden, {
    int swipes = 0,
  }) async {
    tester.view.physicalSize = phone.physical;
    tester.view.devicePixelRatio = phone.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pump(tester, phone);
    for (var i = 0; i < swipes; i++) {
      await swipeUp(tester);
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$golden'));
  }

  group('6.7 inch (1290×2796)', () {
    testWidgets('screenshot 1', (tester) async {
      await capture(tester, _PhoneSpec.inch67, 'app_store_6_7_01.png');
    });
    testWidgets('screenshot 2', (tester) async {
      await capture(tester, _PhoneSpec.inch67, 'app_store_6_7_02.png', swipes: 1);
    });
    testWidgets('screenshot 3', (tester) async {
      await capture(tester, _PhoneSpec.inch67, 'app_store_6_7_03.png', swipes: 2);
    });
  });

  group('6.1 inch (1179×2556)', () {
    testWidgets('screenshot 1', (tester) async {
      await capture(tester, _PhoneSpec.inch61, 'app_store_6_1_01.png');
    });
    testWidgets('screenshot 2', (tester) async {
      await capture(tester, _PhoneSpec.inch61, 'app_store_6_1_02.png', swipes: 1);
    });
    testWidgets('screenshot 3', (tester) async {
      await capture(tester, _PhoneSpec.inch61, 'app_store_6_1_03.png', swipes: 2);
    });
  });
}
