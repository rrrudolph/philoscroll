import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));

describe("copy-textures.mjs", () => {
  it("syncs mobile dark mode from darkslate, not dark-worn", () => {
    const script = readFileSync(join(here, "..", "scripts", "copy-textures.mjs"), "utf8");
    expect(script).toContain('join(root, "prototypes", "textures", "darkslate.jpg")');
    expect(script).not.toContain("dark-worn.jpg");
  });
});
