import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philoscroll/src/fit.dart';
import 'package:philoscroll/src/measure.dart';
import 'package:philoscroll/src/motion.dart';
import 'package:philoscroll/src/quote.dart';

import 'support.dart';

void main() {
  test('keeps a margin so a line does not sit flush with the screen', () {
    const available = 500.0;
    var applied = 0.0;
    final size = fitQuoteFont(
      FitTarget(
        viewportWidth: 1280,
        rootPx: 16,
        availableHeight: () => available,
        apply: (px) => applied = px,
        contentHeight: () => applied >= 20 ? available - 4 : available - 20,
      ),
    );
    expect(size, lessThan(20));
    expect(applied, lessThan(20));
  });

  test('steps down until the measured block fits, and keeps a size that already fits', () {
    expect(fontSizeThatFits(27, 16, (px) => px <= 18.3), 18);
    expect(fontSizeThatFits(19.2, 16, (_) => true), 19);
    expect(fontSizeThatFits(19.2, 16, (_) => false), 16);
  });

  test('a forward handoff leaves through the top and brings the next line up from below', () {
    final path = handoffPath(dragY: -80, travel: 200, direction: 1);
    expect(path.arriveStart - path.leaveStart, 200);
    expect(path.leaveEnd, -200);
    expect(path.arriveEnd, 0);
    final back = handoffPath(dragY: 40, travel: 180, direction: -1);
    expect(back.leaveStart - back.arriveStart, 180);
    expect(back.leaveEnd, 180);
  });

  testWidgets('shrinks the longest teaching until it fits on a phone', (tester) async {
    await loadAppFonts();
    final quotes = loadTestQuotes();
    final longest = quotes.reduce((best, quote) => quote.text.length > best.text.length ? quote : best);
    const phones = [
      (width: 320.0, height: 568.0, safeBottom: 0.0),
      (width: 375.0, height: 667.0, safeBottom: 0.0),
      (width: 390.0, height: 844.0, safeBottom: 34.0),
    ];
    final normal = fontSizeThatFits(preferredQuoteFontPx(320), QuoteMetrics.minPx, (_) => true);

    double fitted(Quote quote, double width, double height, double safeBottom) {
      final frame = frameFor(width: width, height: height, safeBottom: safeBottom);
      return fittedQuoteFont(quote: quote, frame: frame, viewportWidth: width);
    }

    final smallPhone = fitted(longest, 320, 568, 0);
    expect(smallPhone, lessThan(normal));
    expect(smallPhone, greaterThanOrEqualTo(QuoteMetrics.minPx));

    for (final phone in phones) {
      for (final quote in quotes) {
        final frame = frameFor(width: phone.width, height: phone.height, safeBottom: phone.safeBottom);
        final size = fitted(quote, phone.width, phone.height, phone.safeBottom);
        final height = blockHeight(quote, size, frame, TextScaler.noScaling);
        final roomy = fontSizeThatFits(preferredQuoteFontPx(phone.width), QuoteMetrics.minPx, (_) => true);
        expect(height, lessThanOrEqualTo(frame.availableHeight + 0.5));
        expect(size, lessThanOrEqualTo(roomy));
        expect(size, greaterThanOrEqualTo(QuoteMetrics.minPx));
      }
    }

    const still = Quote(id: 'still', text: 'Be still.', author: 'Someone');
    expect(fitted(still, 320, 568, 0), normal);
    expect(smallPhone, lessThan(fitted(still, 320, 568, 0)));
  });
}
