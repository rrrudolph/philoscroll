"""Photo backgrounds for the worn-scroll prototypes.

Light: the parchment scan the user sent, with the stock banner and white margin removed.
Dark: the Philokalia icon's ground, quilted so the cross is not in the frame.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent
TEX = ROOT / "textures"
ICON = Path(r"C:\Users\PC\Downloads\philokalia_app_icon_1024.png")
LIGHT_SRC = TEX / "light-try-0"


def contrast(fg, bg):
    def lum(c):
        def ch(v):
            v = float(v) / 255.0
            return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

        r, g, b = c
        return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)

    a, b = lum(fg), lum(bg)
    lighter, darker = max(a, b), min(a, b)
    return (lighter + 0.05) / (darker + 0.05)


def report(img, fg, label):
    arr = np.asarray(img).astype(np.float64)
    h, w = arr.shape[:2]
    center = arr[int(h * 0.3) : int(h * 0.7), int(w * 0.15) : int(w * 0.85)]
    luma = center @ np.array([0.2126, 0.7152, 0.0722])
    flat = center.reshape(-1, 3)
    order = np.argsort(luma.reshape(-1))
    n = max(1, len(order) // 12)
    for name, bg in (
        ("mid", flat.mean(axis=0)),
        ("dark", flat[order[:n]].mean(axis=0)),
        ("light", flat[order[-n:]].mean(axis=0)),
    ):
        print(f"  {label} {name}: {contrast(fg, bg):.2f} on {bg.round(0).astype(int).tolist()}")


def fill_holes(image, hole):
    """Spread the nearest kept pixel into holes. Holes are the white margin."""
    out = image.copy()
    hole = hole.copy()
    h, w = hole.shape
    for _ in range(max(h, w)):
        if not hole.any():
            break
        filled = False
        for shift, axis, edge in (
            (1, 0, 0),
            (-1, 0, h - 1),
            (1, 1, 0),
            (-1, 1, w - 1),
        ):
            src = np.roll(out, shift, axis=axis)
            src_hole = np.roll(hole, shift, axis=axis)
            if axis == 0:
                src_hole[edge, :] = True
            else:
                src_hole[:, edge] = True
            take = hole & ~src_hole
            if take.any():
                out[take] = src[take]
                hole[take] = False
                filled = True
        if not filled:
            break
    return out


def prepare_light():
    image = Image.open(LIGHT_SRC).convert("RGB")
    arr = np.asarray(image)
    # The stock banner is the black bar at the bottom.
    arr = arr[:632]
    lum = arr.mean(axis=2)
    chroma = arr.max(axis=2) - arr.min(axis=2)
    # Real paper is brown. The margin and the pale fringe around the tears are not.
    paper = (lum < 188) | ((chroma > 28) & (lum < 215))
    outside = np.zeros(paper.shape, dtype=bool)
    outside[0, :] = ~paper[0, :]
    outside[-1, :] = ~paper[-1, :]
    outside[:, 0] |= ~paper[:, 0]
    outside[:, -1] |= ~paper[:, -1]
    from collections import deque

    h, w = paper.shape
    q = deque()
    ys, xs = np.where(outside)
    for y, x in zip(ys.tolist(), xs.tolist()):
        q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if ny < 0 or nx < 0 or ny >= h or nx >= w or outside[ny, nx] or paper[ny, nx]:
                continue
            outside[ny, nx] = True
            q.append((ny, nx))
    # Eat the light fringe so the fill copies brown paper, not the anti-aliased rim.
    fringe = np.asarray(
        Image.fromarray((outside.astype(np.uint8) * 255), "L").filter(ImageFilter.MaxFilter(7))
    ) > 0
    filled = fill_holes(arr, fringe)
    out = Image.fromarray(filled, "RGB")
    dest = TEX / "light-photo.jpg"
    out.save(dest, quality=92, subsampling=0)
    print("light", out.size)
    report(out, (31, 41, 55), "text #1F2937")
    report(out, (75, 85, 99), "muted #4B5563")
    return out


def icon_ground():
    image = Image.open(ICON).convert("RGB")
    arr = np.asarray(image)
    lum = 0.2126 * arr[:, :, 0] + 0.7152 * arr[:, :, 1] + 0.0722 * arr[:, :, 2]
    blur = np.asarray(Image.fromarray(lum.astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(18)))
    cross = blur > 78
    # Keep the glow around the cross out of the source patches.
    cross = np.asarray(Image.fromarray(cross.astype(np.uint8) * 255, "L").filter(ImageFilter.MaxFilter(31))) > 0
    valid = ~cross
    # Drop a rim so a patch never sits on the cut.
    rim = np.asarray(Image.fromarray(valid.astype(np.uint8) * 255, "L").filter(ImageFilter.MinFilter(9))) > 0

    patch = 84
    h, w = rim.shape
    ys, xs = np.where(rim)
    # A patch is valid when its top-left is far enough from the cross that the whole patch fits.
    # Shrink the candidate set to top-lefts whose patch is fully inside `rim`.
    candidates = []
    step = 18
    for y in range(0, h - patch, step):
        for x in range(0, w - patch, step):
            if rim[y : y + patch, x : x + patch].all():
                candidates.append((y, x))
    if len(candidates) < 8:
        raise SystemExit(f"only {len(candidates)} clean patches")
    print("clean patches", len(candidates))

    rng = np.random.default_rng(3)
    out_h, out_w = 1600, 900
    acc = np.zeros((out_h, out_w, 3), np.float32)
    weight = np.zeros((out_h, out_w), np.float32)
    # Wider patches, heavy overlap, and matched brightness. A tight grid of the
    # icon's vignette showed up as squares.
    patch = 168
    candidates = []
    step = 24
    for y in range(0, h - patch, step):
        for x in range(0, w - patch, step):
            if rim[y : y + patch, x : x + patch].all():
                candidates.append((y, x))
    if len(candidates) < 4:
        raise SystemExit(f"only {len(candidates)} clean patches at {patch}px")
    print("clean patches", len(candidates))
    tone = arr[rim].mean(axis=0).astype(np.float32)
    t = np.linspace(0, np.pi, patch, dtype=np.float32)
    win = np.sin(t)
    window = win[:, None] * win[None, :]
    stride = patch // 4
    for y0 in range(-stride, out_h, stride):
        for x0 in range(-stride, out_w, stride):
            sy, sx = candidates[int(rng.integers(0, len(candidates)))]
            tile = arr[sy : sy + patch, sx : sx + patch].astype(np.float32)
            tile += tone - tile.mean(axis=(0, 1))
            if rng.random() < 0.5:
                tile = tile[:, ::-1]
            if rng.random() < 0.5:
                tile = tile[::-1]
            y1, x1 = max(0, y0), max(0, x0)
            y2, x2 = min(out_h, y0 + patch), min(out_w, x0 + patch)
            ty1, tx1 = y1 - y0, x1 - x0
            ty2, tx2 = ty1 + (y2 - y1), tx1 + (x2 - x1)
            acc[y1:y2, x1:x2] += tile[ty1:ty2, tx1:tx2] * window[ty1:ty2, tx1:tx2, None]
            weight[y1:y2, x1:x2] += window[ty1:ty2, tx1:tx2]
    # Cover the bottom/right remainder by the last stride landing short of the edge.
    quilt = (acc / np.maximum(weight, 1e-6)[..., None]).astype(np.uint8)
    # The stride loop misses a strip if out size is not aligned. Fill from the overlapping region.
    if weight.min() == 0:
        missing = weight == 0
        print("uncovered", int(missing.sum()))
    out = Image.fromarray(quilt, "RGB")
    dest = TEX / "dark-icon.jpg"
    out.save(dest, quality=92, subsampling=0)
    print("dark", out.size)
    report(out, (229, 231, 235), "text #E5E7EB")
    report(out, (154, 163, 178), "muted #9AA3B2")
    Image.fromarray(np.where(cross[..., None], np.array([180, 40, 40], np.uint8), arr)).save(TEX / "icon-mask-preview.jpg", quality=85)


def main():
    prepare_light()
    icon_ground()


if __name__ == "__main__":
    main()
