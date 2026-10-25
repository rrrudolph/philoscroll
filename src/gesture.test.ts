import { describe, expect, it } from "vitest";
import { dragOffset, SWIPE_COMMIT_PX, SWIPE_FADE_PX, swipeDirection, swipeOpacity } from "./gesture";

describe("swipe", () => {
  it("fades in step with the finger and is already dim at the commit point", () => {
    expect(swipeOpacity(0)).toBe(1);
    expect(swipeOpacity(SWIPE_FADE_PX / 2)).toBeCloseTo(0.5, 5);
    expect(swipeOpacity(SWIPE_FADE_PX)).toBe(0);
    expect(swipeOpacity(SWIPE_FADE_PX + 40)).toBe(0);
    expect(swipeOpacity(SWIPE_COMMIT_PX)).toBeLessThan(0.6);
    expect(SWIPE_FADE_PX).toBeLessThanOrEqual(140);
  });

  it("tracks the finger one to one, and only resists a dead end", () => {
    expect(dragOffset(-80, true)).toBe(-80);
    expect(dragOffset(80, true)).toBe(80);
    const resisted = dragOffset(100, false);
    expect(resisted).toBeGreaterThan(0);
    expect(resisted).toBeLessThan(50);
  });

  it("changes teaching on a real swipe or a flick, not on a twitch", () => {
    expect(swipeDirection(-10, 0, true)).toBeNull();
    expect(swipeDirection(-(SWIPE_COMMIT_PX - 1), 400, true)).toBeNull();
    expect(swipeDirection(-SWIPE_COMMIT_PX, 400, true)).toBe(1);
    expect(swipeDirection(SWIPE_COMMIT_PX, 200, true)).toBe(-1);
    expect(swipeDirection(-20, 20, true)).toBe(1);
    expect(swipeDirection(80, 100, false)).toBeNull();
  });
});
