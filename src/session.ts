import type { Quote } from "./types";

const STORAGE_KEY = "philoscroll-scroll";

export type StoredScroll = {
  v: 1;
  pool: string;
  queueIds: string[];
  lastId?: string;
  seenIds: string[];
  index: number;
};

export function scrollPoolKey(quotes: readonly Quote[]): string {
  let hash = 2166136261;
  const ids = quotes.map((quote) => quote.id).sort();
  for (const id of ids) {
    for (let i = 0; i < id.length; i += 1) {
      hash ^= id.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    hash ^= 10;
    hash = Math.imul(hash, 16777619);
  }
  return `${quotes.length}:${(hash >>> 0).toString(36)}`;
}

export function loadScroll(pool: string, storage: Storage | undefined): StoredScroll | null {
  if (!storage) return null;
  try {
    const raw = storage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const data = JSON.parse(raw) as StoredScroll;
    if (data.v !== 1 || data.pool !== pool) return null;
    if (!Array.isArray(data.queueIds) || !Array.isArray(data.seenIds)) return null;
    if (!Number.isInteger(data.index) || data.index < 0 || data.index >= data.seenIds.length) return null;
    if (!data.queueIds.every((id) => typeof id === "string")) return null;
    if (!data.seenIds.every((id) => typeof id === "string")) return null;
    if (data.lastId !== undefined && typeof data.lastId !== "string") return null;
    return data;
  } catch {
    return null;
  }
}

export function saveScroll(state: StoredScroll, storage: Storage | undefined): void {
  if (!storage) return;
  try {
    storage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    /* Private mode or full quota — keep scrolling without persistence. */
  }
}

export function quotesFromIds(quotes: readonly Quote[], ids: string[]): Quote[] | null {
  const byId = new Map(quotes.map((quote) => [quote.id, quote]));
  const resolved: Quote[] = [];
  for (const id of ids) {
    const quote = byId.get(id);
    if (!quote) return null;
    resolved.push(quote);
  }
  return resolved;
}

export function storageForMount(): Storage | undefined {
  try {
    return window.localStorage;
  } catch {
    return undefined;
  }
}
