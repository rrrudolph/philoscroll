import { cp, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const textureDir = join(root, "dist", "textures");

await mkdir(textureDir, { recursive: true });
await cp(
  join(root, "prototypes", "textures", "old-parchment.jpg"),
  join(textureDir, "old-parchment.jpg"),
);
await cp(
  join(root, "prototypes", "textures", "darkslate.avif"),
  join(textureDir, "darkslate.avif"),
);
