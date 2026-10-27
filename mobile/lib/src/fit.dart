import 'dart:math' as math;

class QuoteMetrics {
  const QuoteMetrics._();

  static const minPx = 16.0;
  static const lineHeight = 1.42;
  static const letterSpacingEm = 0.004;
  static const minRem = 1.2;
  static const maxRem = 1.65;
  static const preferredVw = 0.05;
  static const paddingMinRem = 1.15;
  static const paddingVh = 5.0;
  static const paddingMaxRem = 3.0;
  static const sideRem = 1.5;
  static const columnMaxRem = 34.0;
  static const authorGapMinRem = 1.0;
  static const authorGapVh = 2.5;
  static const authorGapMaxRem = 1.5;
  static const authorFontRem = 0.75;
  static const authorLineHeight = 1.35;
  static const authorLetterSpacingEm = 0.16;
}

const fitSlackPx = 8.0;

class FitTarget {
  const FitTarget({
    required this.viewportWidth,
    required this.rootPx,
    required this.availableHeight,
    required this.apply,
    required this.contentHeight,
  });

  final double viewportWidth;
  final double rootPx;
  final double Function() availableHeight;
  final void Function(double fontPx) apply;
  final double Function() contentHeight;
}

class Frame {
  const Frame({
    required this.columnWidth,
    required this.availableHeight,
    required this.padTop,
    required this.padBottom,
    required this.authorGap,
  });

  final double columnWidth;
  final double availableHeight;
  final double padTop;
  final double padBottom;
  final double authorGap;
}

double clampRange(double min, double preferred, double max) {
  return math.min(max, math.max(min, preferred));
}

double preferredQuoteFontPx(double viewportWidth, [double rootPx = 16]) {
  return clampRange(
    QuoteMetrics.minRem * rootPx,
    viewportWidth * QuoteMetrics.preferredVw,
    QuoteMetrics.maxRem * rootPx,
  );
}

/// Largest size in half-pixel steps that [fits] accepts, down to the readable minimum.
double fontSizeThatFits(double maxPx, double minPx, bool Function(double px) fits) {
  final min = math.min(minPx, maxPx);
  final max = math.max(minPx, maxPx);
  if (fits(max)) return (max * 2 + 1e-6).floor() / 2;
  if (!fits(min)) return min;
  var low = min;
  var high = max;
  var best = min;
  for (var step = 0; step < 12; step += 1) {
    if (high - low < 0.25) break;
    final mid = (low + high) / 2;
    if (fits(mid)) {
      best = mid;
      low = mid;
    } else {
      high = mid;
    }
  }
  var size = (best * 2 + 1e-6).floor() / 2;
  while (size > min && !fits(size)) {
    size = ((size - 0.5) * 2).round() / 2;
  }
  return size;
}

Frame frameFor({
  required double width,
  required double height,
  double safeTop = 0,
  double safeBottom = 0,
  double safeLeft = 0,
  double safeRight = 0,
  double rootPx = 16,
}) {
  final pad = clampRange(
    QuoteMetrics.paddingMinRem * rootPx,
    height * (QuoteMetrics.paddingVh / 100),
    QuoteMetrics.paddingMaxRem * rootPx,
  );
  final authorGap = clampRange(
    QuoteMetrics.authorGapMinRem * rootPx,
    height * (QuoteMetrics.authorGapVh / 100),
    QuoteMetrics.authorGapMaxRem * rootPx,
  );
  // The status bar sits on the page, so the top inset grows when the system
  // inset is taller than the designed padding.
  final padTop = math.max(pad, safeTop);
  final padBottom = pad + safeBottom;
  final articleWidth = math.min(
    600.0,
    math.max(0.0, width - QuoteMetrics.sideRem * 2 * rootPx - safeLeft - safeRight),
  );
  final column = math.min(QuoteMetrics.columnMaxRem * rootPx, articleWidth);
  return Frame(
    columnWidth: math.max(0.0, column),
    availableHeight: math.max(0.0, height - padTop - padBottom),
    padTop: padTop,
    padBottom: padBottom,
    authorGap: authorGap,
  );
}

/// How far the two teachings travel together: past the text, and never off the card.
double handoffTravel(double blockHeight, double cardHeight) {
  final card = cardHeight > 0 ? cardHeight : 320;
  final distance = blockHeight > 0 ? blockHeight + 64 : card * 0.34;
  return math.min(math.max(distance, 96), card).roundToDouble();
}

double fitQuoteFont(FitTarget target) {
  final available = target.availableHeight();
  final preferred = preferredQuoteFontPx(target.viewportWidth, target.rootPx);
  final limit = available - fitSlackPx;
  if (!(limit > 0)) return preferred;
  final size = fontSizeThatFits(preferred, QuoteMetrics.minPx, (px) {
    target.apply(px);
    return target.contentHeight() <= limit + 0.5;
  });
  target.apply(size);
  var fitted = size;
  while (fitted > QuoteMetrics.minPx && target.contentHeight() > limit + 0.5) {
    fitted = ((fitted - 0.5) * 2).round() / 2;
    target.apply(fitted);
  }
  return fitted;
}
