export const quoteMetrics = {
  minPx: 16,
  lineHeight: 1.42,
  letterSpacingEm: 0.004,
  minRem: 1.2,
  maxRem: 1.65,
  preferredVw: 0.05,
  paddingMinRem: 1.15,
  paddingVh: 5,
  paddingMaxRem: 3,
  sideRem: 1.5,
  columnMaxRem: 34,
  authorGapMinRem: 1,
  authorGapVh: 2.5,
  authorGapMaxRem: 1.5,
  authorFontRem: 0.75,
  authorLineHeight: 1.35,
} as const;

export type FitTarget = {
  viewportWidth: number;
  rootPx: number;
  availableHeight: () => number;
  apply: (fontPx: number) => void;
  contentHeight: () => number;
};

function clamp(min: number, preferred: number, max: number): number {
  return Math.min(max, Math.max(min, preferred));
}

export function preferredQuoteFontPx(viewportWidth: number, rootPx = 16): number {
  return clamp(
    quoteMetrics.minRem * rootPx,
    viewportWidth * quoteMetrics.preferredVw,
    quoteMetrics.maxRem * rootPx,
  );
}

/** Largest size in half-pixel steps that `fits` accepts, down to the readable minimum. */
export function fontSizeThatFits(maxPx: number, minPx: number, fits: (px: number) => boolean): number {
  const min = Math.min(minPx, maxPx);
  const max = Math.max(minPx, maxPx);
  if (fits(max)) return Math.floor(max * 2 + 1e-6) / 2;
  if (!fits(min)) return min;
  let low = min;
  let high = max;
  let best = min;
  for (let step = 0; step < 12; step += 1) {
    if (high - low < 0.25) break;
    const mid = (low + high) / 2;
    if (fits(mid)) {
      best = mid;
      low = mid;
    } else {
      high = mid;
    }
  }
  let size = Math.floor(best * 2 + 1e-6) / 2;
  while (size > min && !fits(size)) size = Math.round((size - 0.5) * 2) / 2;
  return size;
}

export function readingBox(
  viewportWidth: number,
  viewportHeight: number,
  safeBottom = 0,
  rootPx = 16,
): { width: number; height: number } {
  const pad = clamp(
    quoteMetrics.paddingMinRem * rootPx,
    viewportHeight * (quoteMetrics.paddingVh / 100),
    quoteMetrics.paddingMaxRem * rootPx,
  );
  const authorGap = clamp(
    quoteMetrics.authorGapMinRem * rootPx,
    viewportHeight * (quoteMetrics.authorGapVh / 100),
    quoteMetrics.authorGapMaxRem * rootPx,
  );
  const authorHeight = quoteMetrics.authorFontRem * rootPx * quoteMetrics.authorLineHeight;
  const width = Math.min(
    quoteMetrics.columnMaxRem * rootPx,
    viewportWidth - quoteMetrics.sideRem * 2 * rootPx,
  );
  const height = viewportHeight - pad * 2 - safeBottom - authorGap - authorHeight;
  return { width: Math.max(0, width), height: Math.max(0, height) };
}

export function wrappedLineCount(
  text: string,
  widthPx: number,
  wordWidth: (word: string) => number,
  spaceWidth: number,
): number {
  const words = text.trim().split(/\s+/).filter((word) => word.length > 0);
  if (words.length === 0 || !(widthPx > 0)) return 0;
  let lines = 1;
  let col = 0;
  for (const word of words) {
    const width = wordWidth(word);
    if (col === 0) {
      col = width;
      continue;
    }
    if (col + spaceWidth + width > widthPx) {
      lines += 1;
      col = width;
    } else {
      col += spaceWidth + width;
    }
  }
  return lines;
}

/** Room kept inside the screen so a line never sits flush against the edge. */
const FIT_SLACK_PX = 8;

export function fitQuoteFont(target: FitTarget): number {
  const available = target.availableHeight();
  const preferred = preferredQuoteFontPx(target.viewportWidth, target.rootPx);
  const limit = available - FIT_SLACK_PX;
  if (!(limit > 0)) return preferred;
  const size = fontSizeThatFits(preferred, quoteMetrics.minPx, (px) => {
    target.apply(px);
    return target.contentHeight() <= limit + 0.5;
  });
  target.apply(size);
  let fitted = size;
  while (fitted > quoteMetrics.minPx && target.contentHeight() > limit + 0.5) {
    fitted = Math.round((fitted - 0.5) * 2) / 2;
    target.apply(fitted);
  }
  return fitted;
}
