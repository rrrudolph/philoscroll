import { describe, expect, it } from "vitest";
import raw from "../data.json";
import { loadQuotes } from "./quotes";

const quotes = loadQuotes(raw);

describe("teachings", () => {
  it("reads the lines and authors from data.json", () => {
    expect(quotes.length).toBeGreaterThanOrEqual(50);
    expect(quotes[0]).toMatchObject({
      id: "1",
      author: "Evagrios the Solitary",
    });
    for (const name of [
      "St. Antony the Great",
      "St. Isaiah the Solitary",
      "Evagrios the Solitary",
      "St. Mark the Ascetic",
    ]) {
      expect(quotes.some((quote) => quote.author === name)).toBe(true);
    }
    for (const quote of quotes) {
      expect(quote.text.length).toBeGreaterThan(20);
      expect(quote.author.length).toBeGreaterThan(0);
    }
  });

  it("rejects two teachings with the same words", () => {
    const first = quotes[0];
    if (!first) throw new Error("expected a teaching");
    expect(() =>
      loadQuotes([
        { id: 1, text: first.text, author: first.author },
        { id: 2, text: first.text, author: first.author },
      ]),
    ).toThrow(/words/);
  });

  it("rejects a teaching that is missing its words or its author", () => {
    expect(() => loadQuotes([{ id: 1, text: "A line with enough words to count.", author: "" }])).toThrow(
      /teachings/,
    );
    expect(() => loadQuotes([{ id: 1, text: "   ", author: "Someone" }])).toThrow(/teachings/);
  });
});
