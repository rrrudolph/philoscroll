export const SWIPE_COMMIT_PX = 56;
export const SWIPE_FADE_PX = 120;
const FLICK_PX_PER_MS = 0.65;
const FLICK_MIN_PX = 18;
const FLICK_MIN_MS = 16;

/** 1 at rest, 0 once the finger has traveled `SWIPE_FADE_PX`. */
export function swipeOpacity(offsetPx: number, fadePx = SWIPE_FADE_PX): number {
  if (!(fadePx > 0)) return 1;
  return 1 - Math.min(1, Math.abs(offsetPx) / fadePx);
}

/** Finger delta, or a short rubber-band when that direction has no teaching. */
export function dragOffset(deltaY: number, canFollow: boolean): number {
  if (canFollow) return deltaY;
  const sign = Math.sign(deltaY);
  return sign * Math.atan(Math.abs(deltaY) / 180) * 72;
}

/** 1 is the next teaching, -1 is the previous one. */
export function swipeDirection(deltaY: number, elapsedMs: number, canFollow: boolean): 1 | -1 | null {
  if (!canFollow || deltaY === 0) return null;
  const distance = Math.abs(deltaY);
  const flung =
    elapsedMs >= FLICK_MIN_MS && distance >= FLICK_MIN_PX && distance / elapsedMs >= FLICK_PX_PER_MS;
  if (distance < SWIPE_COMMIT_PX && !flung) return null;
  return deltaY < 0 ? 1 : -1;
}
