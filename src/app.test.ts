import { readFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import raw from "../data.json";
import { mount } from "./app";
import { loadQuotes } from "./quotes";

const css = readFileSync(join(process.cwd(), "src", "styles.css"), "utf8");

const quotes = loadQuotes(raw);

function render(prefersDark = false) {
  if (!document.head.querySelector("style[data-app-css]")) {
    const style = document.createElement("style");
    style.dataset.appCss = "true";
    style.textContent = css;
    document.head.append(style);
  }
  const root = document.createElement("div");
  document.body.append(root);
  mount(root, { quotes, prefersDark, random: () => 0.42 });
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

  it("follows the system appearance and does not offer a switch", () => {
    const root = render(true);
    expect(document.documentElement.dataset.theme).toBe("dark");
    expect(document.querySelector('meta[name="theme-color"]')?.getAttribute("content")).toBe("#121824");
    expect(root.querySelector("[data-action='theme']")).toBeNull();

    document.body.innerHTML = "";
    const light = render(false);
    expect(document.documentElement.dataset.theme).toBe("light");
    expect(light.querySelector("button")).toBeNull();
  });

  it("changes the teaching only when the page is swiped", () => {
    const root = render();
    const feed = root.querySelector("main");
    const text = () => root.querySelector(".quote-text")?.textContent;
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
});

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
