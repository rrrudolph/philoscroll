import type { Quote } from "./types";

export function shuffle<T>(items: readonly T[], random: () => number): T[] {
  const copy = items.slice();
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.min(i, Math.floor(random() * (i + 1)));
    const current = copy[i];
    copy[i] = copy[j];
    copy[j] = current;
  }
  return copy;
}

export class QuoteDeck {
  private queue: Quote[] = [];
  private lastId: string | undefined;

  constructor(
    private readonly pool: readonly Quote[],
    private readonly random: () => number = Math.random,
  ) {
    if (this.pool.length > 0) this.refill(undefined);
  }

  draw(): Quote | null {
    if (this.pool.length === 0) return null;
    if (this.queue.length === 0) this.refill(this.lastId);
    const quote = this.queue.shift();
    if (!quote) return null;
    this.lastId = quote.id;
    return quote;
  }

  private refill(avoidId: string | undefined): void {
    const next = shuffle(this.pool, this.random);
    if (avoidId && next.length > 1 && next[0]?.id === avoidId) {
      const first = next.shift();
      if (first) next.push(first);
    }
    this.queue = next;
  }
}
