// @vitest-environment node

import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import raw from "../data.json";
import {
  fitQuoteFont,
  fontSizeThatFits,
  preferredQuoteFontPx,
  quoteMetrics,
  readingBox,
  wrappedLineCount,
} from "./fit";
import { loadQuotes } from "./quotes";

const require = createRequire(import.meta.url);
const fontkit = require("fontkit") as {
  create: (buffer: Buffer) => {
    unitsPerEm: number;
    layout: (text: string) => { advanceWidth: number };
  };
};

const quotes = loadQuotes(raw);
const font = fontkit.create(readFileSync(fontFile()));

function fontFile(): string {
  const face = readFileSync(
    join(process.cwd(), "node_modules", "@fontsource", "source-serif-4", "latin-400-italic.css"),
    "utf8",
  );
  const match = /url\(\.\/files\/([^)]+latin-400-italic\.woff2)\)/.exec(face);
  if (!match?.[1]) throw new Error("missing Source Serif italic file");
  return join(process.cwd(), "node_modules", "@fontsource", "source-serif-4", "files", match[1]);
}

const widths = new Map<string, number>();

function widthOf(text: string, fontPx: number): number {
  const key = `${fontPx.toFixed(2)}\0${text}`;
  const cached = widths.get(key);
  if (cached !== undefined) return cached;
  const advance = font.layout(text).advanceWidth / font.unitsPerEm;
  const width = advance * fontPx + text.length * fontPx * quoteMetrics.letterSpacingEm;
  widths.set(key, width);
  return width;
}

function fittedSize(text: string, viewportWidth: number, viewportHeight: number, safeBottom = 0): number {
  const box = readingBox(viewportWidth, viewportHeight, safeBottom);
  let applied = 0;
  return fitQuoteFont({
    viewportWidth,
    rootPx: 16,
    availableHeight: () => box.height,
    apply: (fontPx) => {
      applied = fontPx;
    },
    contentHeight: () => {
      const lines = wrappedLineCount(text, box.width, (word) => widthOf(word, applied), widthOf(" ", applied));
      return lines * applied * quoteMetrics.lineHeight;
    },
  });
}

function blockHeight(text: string, fontPx: number, width: number): number {
  const lines = wrappedLineCount(text, width, (word) => widthOf(word, fontPx), widthOf(" ", fontPx));
  return lines * fontPx * quoteMetrics.lineHeight;
}

describe("quote fit", () => {
  it("keeps a margin so a line does not sit flush with the screen", () => {
    const available = 500;
    let applied = 0;
    const size = fitQuoteFont({
      viewportWidth: 1280,
      rootPx: 16,
      availableHeight: () => available,
      apply: (px) => {
        applied = px;
      },
      contentHeight: () => (applied >= 20 ? available - 4 : available - 20),
    });
    expect(size).toBeLessThan(20);
    expect(applied).toBeLessThan(20);
  });

  it("steps down until the measured block fits, and keeps a size that already fits", () => {
    expect(fontSizeThatFits(27, 16, (px) => px <= 18.3)).toBe(18);
    expect(fontSizeThatFits(19.2, 16, () => true)).toBe(19);
    expect(fontSizeThatFits(19.2, 16, () => false)).toBe(16);
  });

  it("shrinks the longest teaching until it fits on a phone", () => {
    const longest = quotes.reduce((best, quote) => (quote.text.length > best.text.length ? quote : best));
    const phones = [
      { width: 320, height: 568, safeBottom: 0 },
      { width: 375, height: 667, safeBottom: 0 },
      { width: 390, height: 844, safeBottom: 34 },
    ];
    const normal = fontSizeThatFits(preferredQuoteFontPx(320), quoteMetrics.minPx, () => true);
    const smallPhone = fittedSize(longest.text, 320, 568);
    expect(smallPhone).toBeLessThan(normal);
    expect(smallPhone).toBeGreaterThanOrEqual(quoteMetrics.minPx);

    for (const phone of phones) {
      for (const quote of quotes) {
        const size = fittedSize(quote.text, phone.width, phone.height, phone.safeBottom);
        const box = readingBox(phone.width, phone.height, phone.safeBottom);
        const height = blockHeight(quote.text, size, box.width);
        const roomy = fontSizeThatFits(preferredQuoteFontPx(phone.width), quoteMetrics.minPx, () => true);
        expect(height).toBeLessThanOrEqual(box.height + 0.5);
        expect(size).toBeLessThanOrEqual(roomy);
        expect(size).toBeGreaterThanOrEqual(quoteMetrics.minPx);
      }
    }

    const short = fittedSize("Be still.", 320, 568);
    expect(short).toBe(normal);
    expect(smallPhone).toBeLessThan(short);
  });
});
