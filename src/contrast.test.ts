import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { themes, type ThemeName } from "./tokens";

function relativeLuminance(color: string): number {
  const [red, green, blue] = channels(color).map((value) => {
    const channel = value / 255;
    return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * red! + 0.7152 * green! + 0.0722 * blue!;
}

function contrastRatio(foreground: string, background: string): number {
  const first = relativeLuminance(foreground);
  const second = relativeLuminance(background);
  const [lighter, darker] = first > second ? [first, second] : [second, first];
  return (lighter + 0.05) / (darker + 0.05);
}

function declared(block: string, name: string): string {
  const match = block.match(new RegExp(`--${name}:\\s*([^;]+);`));
  const value = match?.[1]?.trim();
  if (!value) throw new Error(`missing --${name}`);
  return value;
}

function themeBlock(css: string, selector: string): string {
  const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = css.match(new RegExp(`${escaped}\\s*\\{([^}]+)\\}`));
  const block = match?.[1];
  if (!block) throw new Error(`missing ${selector}`);
  return block;
}

function channels(color: string): [number, number, number] {
  const hex = color.trim().match(/^#([0-9a-f]{6})$/i);
  if (hex?.[1]) {
    return [
      parseInt(hex[1].slice(0, 2), 16),
      parseInt(hex[1].slice(2, 4), 16),
      parseInt(hex[1].slice(4, 6), 16),
    ];
  }
  const rgb = color.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/i);
  if (!rgb?.[1] || !rgb[2] || !rgb[3]) throw new Error(`unreadable color ${color}`);
  return [Number(rgb[1]), Number(rgb[2]), Number(rgb[3])];
}

function sameColor(actual: string, expected: string): boolean {
  const left = channels(actual);
  const right = channels(expected);
  return left.every((channel, index) => Math.abs(channel - right[index]!) < 0.5);
}

function paintFirstFrame(html: string, prefersDark: boolean): void {
  const style = html.match(/<style>([\s\S]*?)<\/style>/)?.[1];
  const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
  if (!style || !script) throw new Error("missing first paint");
  document.head.replaceChildren();
  document.body.replaceChildren();
  document.documentElement.removeAttribute("data-theme");
  const styleEl = document.createElement("style");
  styleEl.textContent = style;
  document.head.append(styleEl);
  const meta = document.createElement("meta");
  meta.name = "theme-color";
  meta.content = "#000000";
  document.head.append(meta);
  const previous = window.matchMedia;
  window.matchMedia = ((query: string) =>
    ({
      matches: query === "(prefers-color-scheme: dark)" ? prefersDark : false,
      media: query,
      addEventListener() {},
      removeEventListener() {},
      addListener() {},
      removeListener() {},
      dispatchEvent() {
        return false;
      },
      onchange: null,
    }) as MediaQueryList) as typeof window.matchMedia;
  try {
    new Function(script)();
  } finally {
    window.matchMedia = previous;
  }
}

describe("theme contrast", () => {
  it("measures black on white at the WCAG maximum", () => {
    expect(contrastRatio("#000000", "#FFFFFF")).toBeCloseTo(21, 5);
    expect(contrastRatio("#FFFFFF", "#000000")).toBeCloseTo(21, 5);
  });

  it("keeps both appearances readable", () => {
    const css = readFileSync(join(process.cwd(), "src", "styles.css"), "utf8");
    const selectors: Record<ThemeName, string> = {
      light: '[data-theme="light"]',
      dark: '[data-theme="dark"]',
    };
    for (const name of ["light", "dark"] as const) {
      const palette = themes[name];
      const block = themeBlock(css, selectors[name]);
      for (const [key, value] of Object.entries(palette)) {
        expect(declared(block, key)).toBe(value);
      }
      expect(contrastRatio(declared(block, "text"), declared(block, "bg"))).toBeGreaterThanOrEqual(4.5);
      expect(contrastRatio(declared(block, "muted"), declared(block, "bg"))).toBeGreaterThanOrEqual(4.5);
      expect(contrastRatio(declared(block, "accent"), declared(block, "bg"))).toBeGreaterThanOrEqual(4.5);
      expect(contrastRatio(declared(block, "line"), declared(block, "bg"))).toBeGreaterThanOrEqual(3);
    }
  });

  it("paints the phone appearance before the app loads", () => {
    const html = readFileSync(join(process.cwd(), "index.html"), "utf8");
    expect(html).toContain('matchMedia("(prefers-color-scheme: dark)")');
    for (const prefersDark of [false, true]) {
      paintFirstFrame(html, prefersDark);
      const palette = prefersDark ? themes.dark : themes.light;
      const page = document.documentElement;
      expect(page.dataset.theme).toBe(prefersDark ? "dark" : "light");
      expect(document.querySelector('meta[name="theme-color"]')?.getAttribute("content")).toBe(palette.bg);
      const background = getComputedStyle(page).backgroundColor;
      const foreground = getComputedStyle(page).color;
      expect(sameColor(background, palette.bg)).toBe(true);
      expect(sameColor(foreground, palette.text)).toBe(true);
      expect(contrastRatio(foreground, background)).toBeGreaterThanOrEqual(4.5);
    }
  });
});
