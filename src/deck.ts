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

export type DeckResume = {
  queue: Quote[];
  lastId?: string;
};

export class QuoteDeck {
  private queue: Quote[] = [];
  private lastId: string | undefined;

  constructor(
    private readonly pool: readonly Quote[],
    private readonly random: () => number = Math.random,
    resume?: DeckResume,
  ) {
    if (resume) {
      this.queue = resume.queue.slice();
      this.lastId = resume.lastId;
    } else if (this.pool.length > 0) {
      this.refill(undefined);
    }
  }

  snapshot(): { queueIds: string[]; lastId?: string } {
    return { queueIds: this.queue.map((quote) => quote.id), lastId: this.lastId };
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

export function resumeDeck(
  pool: readonly Quote[],
  random: () => number,
  queueIds: string[],
  lastId?: string,
): QuoteDeck | null {
  const byId = new Map(pool.map((quote) => [quote.id, quote]));
  const queue: Quote[] = [];
  for (const id of queueIds) {
    const quote = byId.get(id);
    if (!quote) return null;
    queue.push(quote);
  }
  return new QuoteDeck(pool, random, { queue, lastId });
}
