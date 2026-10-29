import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/app.dart';
import 'package:philoscroll/src/scroll_page.dart';

import 'support.dart';

/// iPhone logical size × [devicePixelRatio] → App Store PNG dimensions.
class _PhoneSpec {
  const _PhoneSpec({
    required this.logical,
    required this.devicePixelRatio,
    required this.physical,
    required this.label,
  });

  final Size logical;
  final double devicePixelRatio;
  final Size physical;
  final String label;

  /// Typical safe area (Dynamic Island / home indicator), logical pt.
  EdgeInsets get safePadding => const EdgeInsets.fromLTRB(0, 59, 0, 34);

  static const inch67 = _PhoneSpec(
    label: '6.7 inch',
    logical: Size(430, 932),
    devicePixelRatio: 3,
    physical: Size(1290, 2796),
  );

  static const inch61 = _PhoneSpec(
    label: '6.1 inch',
    logical: Size(393, 852),
    devicePixelRatio: 3,
    physical: Size(1179, 2556),
  );
}

/// App Store iPhone screenshot layout checks (portrait).
///
/// Pixel goldens differ between Windows and Linux CI, so we verify size, texture,
/// and quote content instead. Export PNGs from a device or simulator for ASC.
///
/// | Slot | PNG size |
/// |------|----------|
/// | 6.7" / Dynamic Island | 1290×2796 |
/// | 6.1" / 6.3" | 1179×2556 |
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

  Future<void> assertFrame(
    WidgetTester tester,
    _PhoneSpec phone, {
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

    expect(tester.takeException(), isNull);
    expect(tester.view.physicalSize, phone.physical);
    expect(find.byKey(const Key('scroll-texture')), findsOneWidget);
    expect(find.byKey(const Key('quote-text')), findsOneWidget);
    expect(find.byKey(const Key('quote-author')), findsOneWidget);

    final quote = tester.widget<Text>(find.byKey(const Key('quote-text')));
    expect(quote.data!.length, greaterThan(40));
    expect(quotes.any((q) => q.text == quote.data), isTrue);
  }

  for (final phone in [_PhoneSpec.inch67, _PhoneSpec.inch61]) {
    group('${phone.label} (${phone.physical.width.toInt()}×${phone.physical.height.toInt()})', () {
      testWidgets('first teaching', (tester) async {
        await assertFrame(tester, phone);
      });
      testWidgets('after one swipe', (tester) async {
        await assertFrame(tester, phone, swipes: 1);
      });
      testWidgets('after two swipes', (tester) async {
        await assertFrame(tester, phone, swipes: 2);
      });
    });
  }
}
