import { readFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import raw from "../data.json";
import { handoffTravel, mount } from "./app";
import { loadQuotes } from "./quotes";

const css = readFileSync(join(process.cwd(), "src", "styles.css"), "utf8");

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

function render(options?: { storage?: Storage }) {
  if (!document.head.querySelector("style[data-app-css]")) {
    const style = document.createElement("style");
    style.dataset.appCss = "true";
    style.textContent = css;
    document.head.append(style);
  }
  const root = document.createElement("div");
  document.body.append(root);
  mount(root, { quotes, random: () => 0.42, storage: options?.storage });
  return root;
}

afterEach(() => {
  document.body.innerHTML = "";
  document.documentElement.removeAttribute("data-theme");
});

describe("the scroll", () => {
  it("shows only the teaching and the author", () => {
    const root = render();
    const article = root.querySelector(".quote");
    const text = article?.querySelector(".quote-text");
    const author = article?.querySelector(".quote-author");
    expect(text?.textContent?.length).toBeGreaterThan(20);
    expect(author?.textContent?.length).toBeGreaterThan(0);
    expect(author?.parentElement?.lastElementChild).toBe(author);
    expect(root.querySelector("h1, header, button, nav, .quote-work")).toBeNull();
    expect(article?.classList.contains("is-visible")).toBe(true);
    expect(quotes.some((quote) => quote.text === text?.textContent)).toBe(true);
    expect(quotes.some((quote) => quote.author === author?.textContent)).toBe(true);
  });

  it("stays dark regardless of system appearance and does not offer a switch", () => {
    const root = render();
    expect(document.documentElement.dataset.theme).toBe("dark");
    expect(document.querySelector('meta[name="theme-color"]')?.getAttribute("content")).toBe("#121824");
    expect(root.querySelector("[data-action='theme']")).toBeNull();
    expect(root.querySelector("button")).toBeNull();

    const styles = getComputedStyle(document.documentElement);
    expect(styles.getPropertyValue("--bg").trim()).toBe("#121824");
    expect(styles.getPropertyValue("--text").trim()).toBe("#E5E7EB");
  });

  it("changes the teaching only when the page is swiped", () => {
    const root = render();
    const feed = root.querySelector("main");
    const text = () => root.querySelector(".quote.is-visible .quote-text")?.textContent;
    const first = text();
    expect(root.querySelectorAll(".quote").length).toBe(1);

    feed?.dispatchEvent(new WheelEvent("wheel", { bubbles: true, deltaY: 400 }));
    expect(text()).toBe(first);

    swipe(feed, 200, 190);
    expect(text()).toBe(first);

    swipe(feed, 300, 120);
    const second = text();
    expect(second).not.toBe(first);
    expect(quotes.some((quote) => quote.text === second)).toBe(true);

    swipe(feed, 80, 220);
    expect(text()).toBe(first);
  });

  it("follows the finger and fades the line while it is still moving", () => {
    const root = render();
    const feed = root.querySelector("main");
    const article = root.querySelector(".quote") as HTMLElement;
    const text = () => root.querySelector(".quote-text")?.textContent;
    const first = text();

    feed?.dispatchEvent(pointer("pointerdown", 360));
    feed?.dispatchEvent(pointer("pointermove", 290));
    const earlyFade = Number(article.style.opacity);
    expect(article.style.transition).toBe("none");
    expect(shiftY(article)).toBe(-70);
    expect(earlyFade).toBeCloseTo(1 - 70 / 120, 5);
    expect(earlyFade).toBeLessThan(0.65);

    feed?.dispatchEvent(pointer("pointermove", 250));
    expect(shiftY(article)).toBe(-110);
    expect(Number(article.style.opacity)).toBeLessThan(earlyFade);
    expect(Number(article.style.opacity)).toBeCloseTo(1 - 110 / 120, 5);

    feed?.dispatchEvent(pointer("pointerup", 348));
    expect(text()).toBe(first);
    expect(article.style.opacity).toBe("");
  });

  it("uses a quieter italic than a medium display face", () => {
    const root = render();
    const text = root.querySelector(".quote-text") as HTMLElement;
    const article = root.querySelector(".quote") as HTMLElement;
    const type = getComputedStyle(text);
    const motion = getComputedStyle(article);
    expect(type.fontStyle).toBe("italic");
    expect(Number(type.fontWeight)).toBe(400);
    expect(type.fontFamily.toLowerCase()).toContain("source serif 4");
    expect(parseFloat(type.letterSpacing)).toBeGreaterThanOrEqual(0);
    const settle = longestTransitionSeconds(motion.transition);
    expect(settle).toBeGreaterThan(0);
    expect(settle).toBeLessThanOrEqual(0.18);
  });

  it("slides the next line in while the last one slides out", async () => {
    const root = render();
    const feed = root.querySelector("main");
    const first = visibleText(root);
    swipe(feed, 300, 120);

    const leaving = root.querySelector(".quote.is-leaving") as HTMLElement;
    const arriving = root.querySelector(".quote.is-visible") as HTMLElement;
    const leaveStart = shiftY(leaving);
    const enter = shiftY(arriving);
    const travel = cardTravel(leaving);
    expect(travel).toBeGreaterThan(12);
    expect(leaving.clientHeight === 0 || travel <= leaving.clientHeight).toBe(true);
    expect(leaving.querySelector(".quote-text")?.textContent).toBe(first);
    expect(arriving.querySelector(".quote-text")?.textContent).not.toBe(first);
    expect(enter - leaveStart).toBe(travel);
    expect(Number(leaving.style.opacity)).toBe(1);
    expect(Number(arriving.style.opacity)).toBe(0);
    expect(root.querySelectorAll(".quote")).toHaveLength(2);

    await nextFrame();

    const exit = shiftY(leaving);
    expect(exit).toBe(leaveStart - travel);
    expect(Number(leaving.style.opacity)).toBe(0);
    expect(arriving.style.opacity).toBe("");
    expect(arriving.classList.contains("is-visible")).toBe(true);
    expect(leaving.isConnected && arriving.isConnected).toBe(true);
    const handoff = longestTransitionSeconds(getComputedStyle(leaving).transitionDuration);
    expect(handoff).toBeGreaterThan(0.18);

    leaving.dispatchEvent(new TransitionEvent("transitionend", { propertyName: "opacity", bubbles: true }));
    expect(root.querySelectorAll(".quote")).toHaveLength(1);
    expect(visibleText(root)).not.toBe(first);

    swipe(feed, 80, 220);
    const leavingBack = root.querySelector(".quote.is-leaving") as HTMLElement;
    const arrivingBack = root.querySelector(".quote.is-visible") as HTMLElement;
    const backStart = shiftY(leavingBack);
    const backEnter = shiftY(arrivingBack);
    const backTravel = cardTravel(leavingBack);
    expect(arrivingBack.querySelector(".quote-text")?.textContent).toBe(first);
    expect(backStart - backEnter).toBe(backTravel);
    expect(Number(arrivingBack.style.opacity)).toBe(0);
    expect(Number(leavingBack.style.opacity)).toBe(1);

    await nextFrame();
    expect(shiftY(leavingBack)).toBe(backStart + backTravel);
    expect(Number(leavingBack.style.opacity)).toBe(0);
    expect(arrivingBack.isConnected).toBe(true);
  });

  it("fades the next line in while the finger is still carrying the last one out", async () => {
    const root = render();
    const feed = root.querySelector("main");
    feed?.dispatchEvent(pointer("pointerdown", 400));
    feed?.dispatchEvent(pointer("pointermove", 320));

    const cards = [...root.querySelectorAll(".quote")] as HTMLElement[];
    const [current, preview] = cards;
    expect(cards).toHaveLength(2);
    const travel = cardTravel(current!);
    expect(shiftY(current!)).toBe(-80);
    expect(shiftY(preview!) - shiftY(current!)).toBe(travel);
    expect(Number(current!.style.opacity)).toBeCloseTo(1 - 80 / 120, 5);
    expect(Number(preview!.style.opacity)).toBeCloseTo(80 / 120, 5);

    feed?.dispatchEvent(pointer("pointerup", 320));
    const leaving = root.querySelector(".quote.is-leaving") as HTMLElement;
    const arriving = root.querySelector(".quote.is-visible") as HTMLElement;
    expect(shiftY(arriving) - shiftY(leaving)).toBe(travel);
    expect(Number(arriving.style.opacity)).toBeCloseTo(80 / 120, 5);

    await nextFrame();
    expect(shiftY(leaving)).toBe(Math.min(-80, -travel));
    expect(shiftY(leaving)).toBeLessThanOrEqual(-80);
    expect(Number(leaving.style.opacity)).toBe(0);
    expect(arriving.isConnected && leaving.isConnected).toBe(true);
  });

  it("remembers the teaching and browse position across a reload", () => {
    const storage = new MemoryStorage();
    const root = render({ storage });
    const feed = root.querySelector("main");
    const first = visibleText(root);
    swipe(feed, 300, 120);
    const second = visibleText(root);
    expect(second).not.toBe(first);

    document.body.innerHTML = "";
    const reloaded = render({ storage });
    const feedAgain = reloaded.querySelector("main");
    expect(visibleText(reloaded)).toBe(second);

    swipe(feedAgain, 80, 220);
    expect(visibleText(reloaded)).toBe(first);
  });

  it("replaces the line in place when motion is reduced", () => {
    const root = render();
    const restore = mockReducedMotion(true);
    try {
      const feed = root.querySelector("main");
      const first = visibleText(root);
      swipe(feed, 300, 120);
      expect(root.querySelectorAll(".quote")).toHaveLength(1);
      expect(visibleText(root)).not.toBe(first);
      expect((root.querySelector(".quote") as HTMLElement).style.transform).toBe("");
    } finally {
      restore();
    }
  });
});

function visibleText(root: ParentNode): string | null | undefined {
  return root.querySelector(".quote.is-visible .quote-text")?.textContent;
}

function cardTravel(card: HTMLElement): number {
  const block = card.querySelector("blockquote")?.getBoundingClientRect().height ?? 0;
  return handoffTravel(block, card.clientHeight);
}

function nextFrame(): Promise<void> {
  return new Promise((resolve) => {
    requestAnimationFrame(() => resolve());
  });
}

function mockReducedMotion(matches: boolean): () => void {
  const original = window.matchMedia.bind(window);
  window.matchMedia = (query: string) => {
    if (query.includes("prefers-reduced-motion")) {
      return {
        matches,
        media: query,
        onchange: null,
        addEventListener() {},
        removeEventListener() {},
        addListener() {},
        removeListener() {},
        dispatchEvent: () => false,
      } as MediaQueryList;
    }
    return original(query);
  };
  return () => {
    window.matchMedia = original;
  };
}

function pointer(type: string, clientY: number) {
  return new PointerEvent(type, { bubbles: true, clientY, pointerId: 1 });
}

function swipe(feed: Element | null, fromY: number, toY: number) {
  feed?.dispatchEvent(pointer("pointerdown", fromY));
  feed?.dispatchEvent(pointer("pointerup", toY));
}

function shiftY(article: HTMLElement): number {
  const match = /translate3d\(\s*0(?:px)?,\s*(-?\d+(?:\.\d+)?)px/.exec(article.style.transform);
  if (!match?.[1]) throw new Error(`expected a vertical drag, got ${article.style.transform}`);
  return Number(match[1]);
}

function longestTransitionSeconds(transition: string): number {
  const tokens = transition.match(/\d+(?:\.\d+)?m?s/g) ?? [];
  return tokens.reduce((longest, token) => {
    const amount = parseFloat(token);
    const seconds = token.endsWith("ms") ? amount / 1000 : amount;
    return Math.max(longest, seconds);
  }, 0);
}
