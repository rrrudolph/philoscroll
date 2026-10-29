"""Remove light anti-alias halos baked into the launcher icon export."""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / "assets" / "icon" / "app_icon.png"


def _luminance(rgb: np.ndarray) -> np.ndarray:
    return (
        0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
    )


def fringe_mask(rgb: np.ndarray) -> np.ndarray:
    lum = _luminance(rgb)
    med_lum = np.array(
        Image.fromarray(lum.astype(np.uint8)).filter(ImageFilter.MedianFilter(7)),
        dtype=np.float64,
    )
    diff = lum - med_lum
    # Light halos from a pre-rounded export, not intentional cross highlights.
    return (diff > 28) & (lum > 45) & (lum < 175)


def corner_halo_mask(rgb: np.ndarray) -> np.ndarray:
    """Catch thin grey fringes along the pre-rounded corner arcs."""
    h, w = rgb.shape[:2]
    lum = _luminance(rgb)
    med_lum = np.array(
        Image.fromarray(lum.astype(np.uint8)).filter(ImageFilter.MedianFilter(9)),
        dtype=np.float64,
    )
    diff = lum - med_lum
    ys = np.arange(h, dtype=np.float64)[:, None]
    xs = np.arange(w, dtype=np.float64)[None, :]
    inset = np.minimum(np.minimum(xs, ys), np.minimum(w - 1 - xs, h - 1 - ys))
    return (inset < 220) & (diff > 16) & (lum > 38) & (lum < 125)


def _inpaint(rgb: np.ndarray, mask: np.ndarray, radius: int) -> np.ndarray:
    repaired = rgb.copy()
    filt = ImageFilter.MedianFilter(radius if radius % 2 else radius + 1)
    for channel in range(3):
        med = np.array(
            Image.fromarray(rgb[:, :, channel].astype(np.uint8)).filter(filt),
            dtype=np.float64,
        )
        repaired[:, :, channel] = np.where(mask, med, repaired[:, :, channel])
    return repaired


def repair_icon(path: Path) -> int:
    im = Image.open(path).convert("RGBA")
    arr = np.array(im, dtype=np.float64)
    rgb = arr[:, :, :3]
    mask = fringe_mask(rgb) | corner_halo_mask(rgb)
    if not mask.any():
        return 0

    repaired = _inpaint(rgb, mask, 7)
    out = np.round(repaired).astype(np.uint8)
    alpha = arr[:, :, 3].astype(np.uint8)
    Image.fromarray(np.dstack([out, alpha]), mode="RGBA").save(path)
    return int(mask.sum())


def count_top_corner_fringe(rgb: np.ndarray) -> int:
    """Pixels in the top band that look like export halos, not cross gold."""
    h, w = rgb.shape[:2]
    lum = _luminance(rgb)
    mask = fringe_mask(rgb) | corner_halo_mask(rgb)
    top = mask[:12, :]
    center = slice(w // 2 - 160, w // 2 + 160)
    corners = np.zeros_like(top, dtype=bool)
    corners[:, :320] = True
    corners[:, w - 320 :] = True
    corners[:, center] = False
    return int(np.sum(top & corners & (lum[:12, :] < 120)))


if __name__ == "__main__":
    before = count_top_corner_fringe(
        np.array(Image.open(ICON).convert("RGBA"))[:, :, :3]
    )
    repaired = repair_icon(ICON)
    after = count_top_corner_fringe(
        np.array(Image.open(ICON).convert("RGBA"))[:, :, :3]
    )
    print(f"repaired {repaired} fringe pixels; top-corner halo {before} -> {after}")
