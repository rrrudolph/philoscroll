import { describe, expect, it } from "vitest";
import raw from "../data.json";
import { QuoteDeck, resumeDeck } from "./deck";
import { loadQuotes } from "./quotes";

const quotes = loadQuotes(raw);

function mulberry32(seed: number): () => number {
  let state = seed;
  return () => {
    state |= 0;
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

describe("quote deck", () => {
  it("shows every teaching once before it repeats, and does not repeat the last one immediately", () => {
    for (const seed of [1, 2, 7, 99, 12345]) {
      const deck = new QuoteDeck(quotes, mulberry32(seed));
      const firstCycle = quotes.map(() => deck.draw()?.id);
      expect(firstCycle.every((id) => typeof id === "string")).toBe(true);
      expect(new Set(firstCycle).size).toBe(quotes.length);
      const next = deck.draw();
      expect(next?.id).not.toBe(firstCycle[firstCycle.length - 1]);
    }
  });

  it("can repeat when only one teaching is left", () => {
    const only = quotes[0];
    if (!only) throw new Error("expected a teaching");
    const deck = new QuoteDeck([only], () => 0);
    expect(deck.draw()?.id).toBe(only.id);
    expect(deck.draw()?.id).toBe(only.id);
  });

  it("returns nothing when there are no teachings", () => {
    expect(new QuoteDeck([]).draw()).toBeNull();
  });

  it("resumes the remaining shuffle after a snapshot", () => {
    const deck = new QuoteDeck(quotes, mulberry32(4));
    for (let i = 0; i < 12; i += 1) deck.draw();
    const snap = deck.snapshot();
    const resumed = resumeDeck(quotes, mulberry32(99), snap.queueIds, snap.lastId);
    if (!resumed) throw new Error("expected a resumed deck");
    expect(resumed.draw()?.id).toBe(deck.draw()?.id);
  });
});
