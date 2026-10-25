import { QuoteDeck } from "./deck";
import { fitQuoteFont } from "./fit";
import { dragOffset, swipeDirection, swipeOpacity } from "./gesture";
import { applyTheme, themeFromPreference } from "./theme";
import type { Quote } from "./types";

export type MountOptions = {
  quotes: readonly Quote[];
  random?: () => number;
  prefersDark?: boolean;
};

export function mount(root: HTMLElement, options: MountOptions): void {
  const quotes = options.quotes;
  const random = options.random ?? Math.random;
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  applyTheme(themeFromPreference(options.prefersDark ?? media.matches));

  if (options.prefersDark === undefined) {
    media.addEventListener("change", (event) => {
      applyTheme(themeFromPreference(event.matches));
    });
  }

  root.replaceChildren();
  if (quotes.length === 0) return;

  const feed = document.createElement("main");
  const article = document.createElement("article");
  article.className = "quote is-visible";

  const block = document.createElement("blockquote");
  const text = document.createElement("p");
  text.className = "quote-text";
  const author = document.createElement("cite");
  author.className = "quote-author";
  block.append(text, author);
  article.append(block);
  feed.append(article);
  root.append(feed);

  const deck = new QuoteDeck(quotes, random);
  const seen: Quote[] = [];
  let index = 0;
  let drag: { pointerId: number; originY: number; originT: number } | null = null;
  let settleToken = 0;

  function reduceMotion(): boolean {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function lengthPx(value: string): number {
    const parsed = parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  function fitQuote(): void {
    if (!article.isConnected) return;
    const styles = getComputedStyle(article);
    const available = article.clientHeight - lengthPx(styles.paddingTop) - lengthPx(styles.paddingBottom);
    const rootPx = lengthPx(getComputedStyle(document.documentElement).fontSize) || 16;
    const viewportWidth = document.documentElement.clientWidth || window.innerWidth;
    const size = fitQuoteFont({
      viewportWidth,
      rootPx,
      availableHeight: () => available,
      apply: (fontPx) => {
        text.style.fontSize = `${fontPx}px`;
      },
      contentHeight: () => block.getBoundingClientRect().height,
    });
    text.dataset.fontPx = String(size);
  }

  function show(quote: Quote): void {
    article.dataset.quoteId = quote.id;
    text.textContent = quote.text;
    author.textContent = quote.author;
    article.classList.add("is-visible");
    fitQuote();
  }

  function canFollow(deltaY: number): boolean {
    return deltaY < 0 || index > 0;
  }

  function go(direction: 1 | -1): void {
    const nextIndex = index + direction;
    if (nextIndex < 0) return;
    if (nextIndex < seen.length) {
      index = nextIndex;
      const quote = seen[index];
      if (quote) show(quote);
      return;
    }
    const quote = deck.draw();
    if (!quote) return;
    seen.push(quote);
    index = seen.length - 1;
    show(quote);
  }

  function track(deltaY: number): void {
    const offset = dragOffset(deltaY, canFollow(deltaY));
    article.classList.add("is-dragging");
    article.style.transition = "none";
    article.style.transform = `translate3d(0, ${offset}px, 0)`;
    article.style.opacity = String(swipeOpacity(offset));
  }

  function releaseFinger(): void {
    article.classList.remove("is-dragging");
    article.style.transition = "";
    article.style.transform = "";
    article.style.opacity = "";
  }

  function settle(deltaY: number, elapsedMs: number): void {
    const direction = swipeDirection(deltaY, elapsedMs, canFollow(deltaY));
    drag = null;
    if (direction === null || reduceMotion()) {
      releaseFinger();
      if (direction) go(direction);
      return;
    }
    const token = ++settleToken;
    article.classList.add("is-dragging");
    article.style.transition = "none";
    article.style.opacity = "0";
    article.style.transform = "translate3d(0, 12px, 0)";
    go(direction);
    requestAnimationFrame(() => {
      if (token !== settleToken) return;
      article.classList.remove("is-dragging");
      article.style.transition = "";
      article.style.opacity = "";
      article.style.transform = "";
    });
  }

  const first = deck.draw();
  if (!first) return;
  seen.push(first);
  show(first);

  if (typeof ResizeObserver === "function") {
    const observer = new ResizeObserver(() => fitQuote());
    observer.observe(article);
  }
  const fonts = document.fonts;
  if (fonts) void fonts.ready.then(() => fitQuote());

  feed.addEventListener("pointerdown", (event) => {
    if (event.pointerType === "mouse" && event.button !== 0) return;
    settleToken += 1;
    drag = { pointerId: event.pointerId, originY: event.clientY, originT: event.timeStamp };
    if (typeof feed.setPointerCapture === "function") {
      try {
        feed.setPointerCapture(event.pointerId);
      } catch {
        /* Capture can fail if the pointer already ended. */
      }
    }
  });

  feed.addEventListener("pointermove", (event) => {
    if (!drag || event.pointerId !== drag.pointerId) return;
    track(event.clientY - drag.originY);
  });

  feed.addEventListener("pointerup", (event) => {
    if (!drag || event.pointerId !== drag.pointerId) return;
    const deltaY = event.clientY - drag.originY;
    const elapsed = event.timeStamp - drag.originT;
    settle(deltaY, elapsed);
  });

  feed.addEventListener("pointercancel", (event) => {
    if (!drag || event.pointerId !== drag.pointerId) return;
    drag = null;
    settleToken += 1;
    releaseFinger();
  });

  feed.addEventListener(
    "touchmove",
    (event) => {
      event.preventDefault();
    },
    { passive: false },
  );
}
