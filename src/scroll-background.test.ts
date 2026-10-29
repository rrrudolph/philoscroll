import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { themes } from "./tokens";

const here = dirname(fileURLToPath(import.meta.url));

describe("scroll backgrounds", () => {
  it("uses parchment textures on the main app", () => {
    const css = readFileSync(join(here, "styles.css"), "utf8");
    expect(css).toContain('url("/textures/old-parchment.jpg")');
    expect(css).toContain('url("/textures/darkslate.avif")');
    expect(css).not.toContain("/parchment/textures/");
    expect(css).toMatch(/\[data-theme="light"\][\s\S]*--text:\s*#000000/);
    expect(css).toContain(`--text: ${themes.dark.text.toLowerCase()}`);
    expect(css).toContain("--quote:");
    expect(css).toContain(".quote-text");
    const darkVignette = css.slice(css.indexOf('[data-theme="dark"] .scroll-vignette'));
    expect(darkVignette).toMatch(/rgba\(0,\s*0,\s*0/);
    expect(darkVignette).not.toMatch(/0\.72\)/);
  });
});
