import { describe, expect, it } from "vitest";
import raw from "../data.json";
import { loadQuotes } from "./quotes";
import { loadScroll, saveScroll, scrollPoolKey } from "./session";

const quotes = loadQuotes(raw);

class MemoryStorage implements Storage {
  private data = new Map<string, string>();

  get length(): number {
    return this.data.size;
  }

  clear(): void {
    this.data.clear();
  }

  getItem(key: string): string | null {
    return this.data.get(key) ?? null;
  }

  key(index: number): string | null {
    return [...this.data.keys()][index] ?? null;
  }

  removeItem(key: string): void {
    this.data.delete(key);
  }

  setItem(key: string, value: string): void {
    this.data.set(key, value);
  }
}

describe("scroll session", () => {
  it("round-trips deck and browse position in storage", () => {
    const storage = new MemoryStorage();
    const pool = scrollPoolKey(quotes);
    saveScroll(
      {
        v: 1,
        pool,
        queueIds: ["3", "2", "1"],
        lastId: "9",
        seenIds: ["9", "8"],
        index: 1,
      },
      storage,
    );
    expect(loadScroll(pool, storage)).toEqual({
      v: 1,
      pool,
      queueIds: ["3", "2", "1"],
      lastId: "9",
      seenIds: ["9", "8"],
      index: 1,
    });
  });

  it("drops saved state when the teaching list changes", () => {
    const storage = new MemoryStorage();
    const pool = scrollPoolKey(quotes);
    saveScroll(
      {
        v: 1,
        pool,
        queueIds: ["1"],
        seenIds: ["1"],
        index: 0,
      },
      storage,
    );
    expect(loadScroll(`${pool}-other`, storage)).toBeNull();
  });
});
