import 'package:flutter/widgets.dart';

import 'fit.dart';
import 'quote.dart';

const quoteFontFamily = 'Source Serif 4';
const authorFontFamily = 'Outfit';

TextStyle quoteStyle(double fontPx, Color color) {
  return TextStyle(
    fontFamily: quoteFontFamily,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400,
    fontSize: fontPx,
    height: QuoteMetrics.lineHeight,
    letterSpacing: fontPx * QuoteMetrics.letterSpacingEm,
    color: color,
    fontVariations: [
      const FontVariation('wght', 400),
      FontVariation('opsz', fontPx.clamp(8, 60)),
    ],
  );
}

TextStyle authorStyle(Color color) {
  const fontPx = QuoteMetrics.authorFontRem * 16;
  return TextStyle(
    fontFamily: authorFontFamily,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w500,
    fontSize: fontPx,
    height: QuoteMetrics.authorLineHeight,
    letterSpacing: fontPx * QuoteMetrics.authorLetterSpacingEm,
    color: color,
    fontVariations: [FontVariation('wght', 500)],
  );
}

double paintedHeight(String text, TextStyle style, double width, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    textScaler: scaler,
  )..layout(maxWidth: width);
  return painter.height;
}

double blockHeight(Quote quote, double fontPx, Frame frame, TextScaler scaler) {
  return paintedHeight(quote.text, quoteStyle(fontPx, const Color(0xFF000000)), frame.columnWidth, scaler) +
      frame.authorGap +
      paintedHeight(quote.author.toUpperCase(), authorStyle(const Color(0xFF000000)), frame.columnWidth, scaler);
}

double fittedQuoteFont({
  required Quote quote,
  required Frame frame,
  required double viewportWidth,
  TextScaler scaler = TextScaler.noScaling,
}) {
  var applied = preferredQuoteFontPx(viewportWidth);
  final size = fitQuoteFont(
    FitTarget(
      viewportWidth: viewportWidth,
      rootPx: 16,
      availableHeight: () => frame.availableHeight,
      apply: (fontPx) => applied = fontPx,
      contentHeight: () => blockHeight(quote, applied, frame, scaler),
    ),
  );
  // A large system text size can still overflow the 16px floor. Keep shrinking
  // until the block is on the screen.
  var fitted = size;
  final limit = frame.availableHeight - fitSlackPx;
  while (fitted > 8 && limit > 0 && blockHeight(quote, fitted, frame, scaler) > limit + 0.5) {
    fitted = ((fitted - 0.5) * 2).round() / 2;
  }
  return fitted;
}
