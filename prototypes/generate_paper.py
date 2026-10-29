"""Worn-paper backgrounds.

Color clouds, foxing, and browned edges. No combed grain and no scratch lines —
those read as brushed metal, not a sheet.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parent / "textures"
W, H = 900, 1600


def value_noise(h, w, cell, rng):
    cell = max(2, int(cell))
    gh, gw = h // cell + 3, w // cell + 3
    grid = rng.random((gh, gw)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8), mode="L")
    img = img.resize((w + cell * 2, h + cell * 2), Image.Resampling.BICUBIC)
    arr = np.asarray(img).astype(np.float32) / 255.0
    y0 = int(rng.integers(0, cell))
    x0 = int(rng.integers(0, cell))
    return arr[y0 : y0 + h, x0 : x0 + w]


def fbm(h, w, rng, octaves, base_cell, persistence=0.55):
    acc = np.zeros((h, w), np.float32)
    amp = 1.0
    total = 0.0
    cell = base_cell
    for _ in range(octaves):
        acc += value_noise(h, w, cell, rng) * amp
        total += amp
        amp *= persistence
        cell = max(2, int(cell * 0.5))
    return acc / total


def smooth(arr, radius):
    img = Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8), "L")
    img = img.filter(ImageFilter.GaussianBlur(radius=radius))
    return np.asarray(img).astype(np.float32) / 255.0


def blobs(h, w, rng, n, radius):
    """Soft spots, warped so they aren't perfect circles."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    warp_y = (fbm(h, w, rng, 3, 90) - 0.5) * 70
    warp_x = (fbm(h, w, rng, 3, 90) - 0.5) * 70
    yy = yy + warp_y
    xx = xx + warp_x
    layer = np.zeros((h, w), np.float32)
    for _ in range(n):
        cy = float(rng.uniform(-40, h + 40))
        cx = float(rng.uniform(-40, w + 40))
        ry = float(rng.uniform(*radius))
        rx = ry * float(rng.uniform(0.65, 1.45))
        layer += np.exp(-(((yy - cy) / ry) ** 2 + ((xx - cx) / rx) ** 2)) * float(rng.uniform(0.4, 1))
    peak = float(layer.max())
    return layer / peak if peak else layer


def edge_wear(h, w, rng):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    yn = yy / (h - 1) * 2 - 1
    xn = xx / (w - 1) * 2 - 1
    rough = fbm(h, w, rng, 4, 150)
    radius = np.sqrt((xn * 0.86) ** 2 + (yn * 0.94) ** 2)
    radius = radius + (rough - 0.5) * 0.28
    # Stay out of the middle, where the quote sits. Corners and rims carry the wear.
    vig = np.clip((radius - 0.58) / 0.62, 0, 1) ** 1.15
    corners = (np.abs(xn) ** 2.4) * (np.abs(yn) ** 1.7)
    return np.clip(vig * 0.85 + corners * 0.7, 0, 1)


def ramp(t, colors):
    colors = np.array(colors, np.float32)
    t = np.clip(t, 0, 1) * (len(colors) - 1)
    i = np.clip(np.floor(t).astype(np.int32), 0, len(colors) - 2)
    f = (t - i)[..., None]
    return colors[i] * (1 - f) + colors[i + 1] * f


def tint(rgb, mask, color, amount):
    m = np.clip(mask * amount, 0, 1)[..., None]
    target = np.array(color, np.float32)
    return rgb * (1 - m) + target * m


def grain(h, w, rng):
    raw = rng.random((h, w)).astype(np.float32)
    fine = smooth(raw, 0.6)
    tooth = fbm(h, w, rng, 2, 5)
    return (fine - 0.5) * 0.65 + (tooth - 0.5) * 0.35


def save(img, name):
    path = OUT / name
    img.save(path, quality=93, subsampling=0)
    print(name, path.stat().st_size // 1024, "KB")


def contrast(fg, bg):
    def lum(c):
        def ch(v):
            v = v / 255.0
            return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

        r, g, b = [float(x) for x in c]
        return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)

    a, b = lum(fg), lum(bg)
    lighter, darker = max(a, b), min(a, b)
    return (lighter + 0.05) / (darker + 0.05)


def report(img, fg, label):
    arr = np.asarray(img).astype(np.float64)
    center = arr[int(H * 0.28) : int(H * 0.72), int(W * 0.12) : int(W * 0.88)]
    luma = center @ np.array([0.2126, 0.7152, 0.0722])
    flat = center.reshape(-1, 3)
    order = np.argsort(luma.reshape(-1))
    n = max(1, len(order) // 12)
    dark = flat[order[:n]].mean(axis=0)
    light = flat[order[-n:]].mean(axis=0)
    mid = flat.mean(axis=0)
    # Isotropy: combed grain shows up as a big gap between horizontal and vertical detail.
    full = arr @ np.array([0.2126, 0.7152, 0.0722])
    row = full.mean(axis=1)
    jump = float(np.max(np.abs(np.diff(row))))
    gy = np.mean(np.abs(np.diff(luma, axis=0)))
    gx = np.mean(np.abs(np.diff(luma, axis=1)))
    print(
        f"  {label}: mid {contrast(fg, mid):.2f}, "
        f"dark {contrast(fg, dark):.2f}, light {contrast(fg, light):.2f}, "
        f"grain x/y {gx / gy:.2f}, row jump {jump:.2f}"
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cream = [
        (150, 116, 74),
        (190, 162, 120),
        (214, 196, 166),
        (232, 220, 200),
        (246, 240, 228),
    ]
    aged = [
        (118, 82, 44),
        (156, 114, 64),
        (184, 146, 92),
        (206, 174, 122),
        (222, 196, 150),
    ]
    vellum = [
        (8, 7, 6),
        (24, 20, 16),
        (40, 34, 26),
        (72, 58, 40),
        (118, 96, 64),
    ]
    brown = [
        (16, 12, 8),
        (42, 32, 20),
        (68, 52, 34),
        (98, 76, 48),
        (132, 104, 66),
    ]
    jobs = [
        ("light-handled.jpg", 4, cream, 0.78, 0.34, (6, (26, 72), 10, (6, 16), 0.55), (132, 94, 52), (0, (1, 2), 0), (0, 0, 0), (158, 124, 82), (42, 36, 28)),
        ("light-aged.jpg", 11, aged, 0.66, 0.38, (10, (28, 76), 14, (6, 16), 0.42), (138, 102, 58), (0, (1, 2), 0), (0, 0, 0), (108, 76, 42), (48, 34, 20)),
        ("dark-vellum.jpg", 5, vellum, 0.40, 0.32, (5, (40, 120), 8, (8, 20), 0.45), (14, 11, 8), (7, (50, 140), 0.5), (132, 108, 74), (6, 5, 4), (236, 228, 214)),
        ("dark-worn.jpg", 9, brown, 0.46, 0.36, (6, (36, 100), 10, (8, 18), 0.4), (22, 16, 10), (8, (40, 130), 0.42), (150, 122, 78), (10, 8, 6), (243, 232, 208)),
    ]
    for name, seed, colors, center, spread, stain, stain_color, scuff, scuff_color, edge_color, ink in jobs:
        rng_seed = seed
        img, _ = build(rng_seed, colors, center, spread, stain, stain_color, scuff, scuff_color, edge_color)
        save(img, name)
        report(img, ink, name)


def build(seed, colors, center, spread, stain, stain_color, scuff, scuff_color, edge_color):
    rng = np.random.default_rng(seed)
    low = fbm(H, W, rng, 5, 280)
    mid = fbm(H, W, rng, 4, 80)
    field = center + (low - 0.5) * spread + (mid - 0.5) * spread * 0.55
    rgb = ramp(field, colors)

    fox = blobs(H, W, rng, stain[0], stain[1])
    bits = blobs(H, W, rng, stain[2], stain[3])
    tide = blobs(H, W, rng, 2, (110, 220))
    edge = edge_wear(H, W, rng)
    speckle = grain(H, W, rng)
    cockle = smooth(fbm(H, W, rng, 3, 340), 10)

    rgb = tint(rgb, fox, stain_color, stain[4])
    rgb = tint(rgb, bits, stain_color, stain[4] * 0.7)
    rgb = tint(rgb, tide, stain_color, 0.18)
    if scuff[0]:
        rub = blobs(H, W, rng, scuff[0], scuff[1])
        rgb = tint(rgb, rub, scuff_color, scuff[2])
    rgb = tint(rgb, edge, edge_color, 0.9)
    rgb = rgb + speckle[..., None] * 18

    gy, gx = np.gradient(cockle)
    light = -0.4 * gx - 0.7 * gy
    scale = float(np.percentile(np.abs(light), 99)) + 1e-6
    rgb = rgb * (1 + np.clip(light / scale, -1, 1) * 0.045)[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB"), None


if __name__ == "__main__":
    main()
