import type { Quote } from "./types";

export function loadQuotes(data: unknown): Quote[] {
  if (!Array.isArray(data) || data.length === 0 || !data.every(isRawQuote)) {
    throw new Error("Expected a list of teachings.");
  }
  const quotes = data.map((quote) => ({
    id: String(quote.id),
    text: quote.text.trim(),
    author: quote.author.trim(),
  }));
  const ids = new Set(quotes.map((quote) => quote.id));
  if (ids.size !== quotes.length) {
    throw new Error("Each teaching needs its own id.");
  }
  return quotes;
}

function isRawQuote(value: unknown): value is { id: number | string; text: string; author: string } {
  if (value === null || typeof value !== "object") return false;
  const quote = value as Record<string, unknown>;
  const idOk =
    typeof quote.id === "number" || (typeof quote.id === "string" && quote.id.length > 0);
  return (
    idOk &&
    typeof quote.text === "string" &&
    quote.text.trim().length > 0 &&
    typeof quote.author === "string" &&
    quote.author.trim().length > 0
  );
}
