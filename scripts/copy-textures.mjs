import { cp, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const textureDir = join(root, "dist", "textures");
const mobileTextureDir = join(root, "mobile", "assets", "textures");

await mkdir(textureDir, { recursive: true });
await mkdir(mobileTextureDir, { recursive: true });
const sources = [
  ["old-parchment.jpg", "old-parchment.jpg"],
  ["darkslate.avif", "darkslate.avif"],
] as const;
for (const [name] of sources) {
  const from = join(root, "prototypes", "textures", name);
  await cp(from, join(textureDir, name));
  await cp(from, join(mobileTextureDir, name));
}
