// @vitest-environment node

import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { quoteMetrics } from "./fit";

const require = createRequire(import.meta.url);
const fontkit = require("fontkit") as {
  create: (buffer: Buffer) => {
    italicAngle: number;
    familyName: string;
    "OS/2": { usWeightClass: number };
  };
};

function declared(css: string, selector: string, property: string): string {
  const block = new RegExp(`${selector.replace(".", "\\.")}\\s*\\{([^}]+)\\}`).exec(css);
  const value = block?.[1] ? new RegExp(`${property}\\s*:\\s*([^;]+);`).exec(block[1]) : null;
  if (!value?.[1]) throw new Error(`missing ${selector} ${property}`);
  return value[1].trim();
}

describe("italic", () => {
  it("loads a regular-weight text italic, not a heavier display italic", () => {
    const main = readFileSync(join(process.cwd(), "src", "main.ts"), "utf8");
    expect(main).toContain("@fontsource/source-serif-4/latin-400-italic.css");
    const face = readFileSync(
      join(process.cwd(), "node_modules", "@fontsource", "source-serif-4", "latin-400-italic.css"),
      "utf8",
    );
    const file = /url\(\.\/files\/([^)]+latin-400-italic\.woff2)\)/.exec(face);
    if (!file?.[1]) throw new Error("missing italic font file");
    const font = fontkit.create(
      readFileSync(join(process.cwd(), "node_modules", "@fontsource", "source-serif-4", "files", file[1])),
    );
    expect(font.familyName.toLowerCase()).toContain("source serif 4");
    expect(font["OS/2"].usWeightClass).toBe(400);
    expect(font["OS/2"].usWeightClass).toBeLessThan(500);
    expect(font.italicAngle).toBeLessThanOrEqual(-6);
    expect(font.italicAngle).toBeGreaterThanOrEqual(-12);

    const css = readFileSync(join(process.cwd(), "src", "styles.css"), "utf8");
    expect(declared(css, ".quote-text", "font-weight")).toBe("400");
    expect(declared(css, ".quote-text", "font-style")).toBe("italic");
    expect(declared(css, ".quote-text", "font-synthesis")).toBe("none");
    expect(declared(css, ".quote-text", "font-family")).toContain("var(--serif)");
    expect(css).toContain('"Source Serif 4"');
    expect(parseFloat(declared(css, ".quote-text", "letter-spacing"))).toBeGreaterThanOrEqual(0);
    expect(declared(css, ".quote-text", "line-height")).toBe(String(quoteMetrics.lineHeight));
    expect(declared(css, ".quote-text", "font-size")).toBe(
      `clamp(${quoteMetrics.minRem}rem, ${quoteMetrics.preferredVw * 100}vw, ${quoteMetrics.maxRem}rem)`,
    );
    const pad = `clamp(${quoteMetrics.paddingMinRem}rem, ${quoteMetrics.paddingVh}dvh, ${quoteMetrics.paddingMaxRem}rem)`;
    expect(declared(css, ".quote", "padding")).toContain(pad);
    expect(declared(css, ".quote-author", "margin")).toContain(
      `clamp(${quoteMetrics.authorGapMinRem}rem, ${quoteMetrics.authorGapVh}dvh, ${quoteMetrics.authorGapMaxRem}rem)`,
    );
    expect(declared(css, "blockquote", "max-width")).toBe(`${quoteMetrics.columnMaxRem}rem`);
  });
});
