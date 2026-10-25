import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { theme } from "./tokens";

function relativeLuminance(hex: string): number {
  const channels = [0, 2, 4].map((start) => {
    const value = parseInt(hex.slice(start + 1, start + 3), 16) / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

function contrastRatio(foreground: string, background: string): number {
  const first = relativeLuminance(foreground);
  const second = relativeLuminance(background);
  const [lighter, darker] = first > second ? [first, second] : [second, first];
  return (lighter + 0.05) / (darker + 0.05);
}

function rootThemeBlock(css: string): string {
  const match = css.match(/:root\s*\{([^}]+)\}/);
  if (!match?.[1]) throw new Error("missing :root colors");
  return match[1];
}

describe("theme contrast", () => {
  it("measures black on white at the WCAG maximum", () => {
    expect(contrastRatio("#000000", "#FFFFFF")).toBeCloseTo(21, 5);
    expect(contrastRatio("#FFFFFF", "#000000")).toBeCloseTo(21, 5);
  });

  it("keeps text, accents, and control borders readable on the dark theme", () => {
    expect(contrastRatio(theme.text, theme.bg)).toBeGreaterThanOrEqual(4.5);
    expect(contrastRatio(theme.muted, theme.bg)).toBeGreaterThanOrEqual(4.5);
    expect(contrastRatio(theme.accent, theme.bg)).toBeGreaterThanOrEqual(4.5);
    expect(contrastRatio(theme.line, theme.bg)).toBeGreaterThanOrEqual(3);
  });

  it("uses those same colors in the stylesheet and the first paint", () => {
    const css = readFileSync(join(process.cwd(), "src", "styles.css"), "utf8");
    const html = readFileSync(join(process.cwd(), "index.html"), "utf8");
    const block = rootThemeBlock(css);
    for (const [key, value] of Object.entries(theme)) {
      expect(block).toContain(`--${key}: ${value};`);
    }
    expect(html).not.toContain("prefers-color-scheme");
    expect(html).toContain(theme.bg);
    expect(html).toContain(theme.text);
    expect(html).toContain('setAttribute("data-theme", "dark")');
  });
});
