import { QuoteDeck, resumeDeck } from "./deck";
import { fitQuoteFont } from "./fit";
import { dragOffset, swipeDirection, swipeOpacity } from "./gesture";
import {
  loadScroll,
  quotesFromIds,
  saveScroll,
  scrollPoolKey,
  storageForMount,
} from "./session";
import { applyTheme, themeFromPreference } from "./theme";
import type { Quote } from "./types";

export type MountOptions = {
  quotes: readonly Quote[];
  random?: () => number;
  storage?: Storage;
  prefersDark?: boolean;
};

let stopThemeFollow: (() => void) | undefined;

function followSystemTheme(prefersDark: boolean | undefined): void {
  stopThemeFollow?.();
  stopThemeFollow = undefined;
  const media = window.matchMedia("(prefers-color-scheme: dark)");
  applyTheme(themeFromPreference(prefersDark ?? media.matches));
  if (prefersDark !== undefined) return;
  const onChange = (event: MediaQueryListEvent) => {
    applyTheme(themeFromPreference(event.matches));
  };
  media.addEventListener("change", onChange);
  stopThemeFollow = () => media.removeEventListener("change", onChange);
}

/** How far the two teachings travel together: past the text, and never off the card. */
export function handoffTravel(blockHeight: number, cardHeight: number): number {
  const card = cardHeight > 0 ? cardHeight : 320;
  const distance = blockHeight > 0 ? blockHeight + 64 : card * 0.34;
  return Math.round(Math.min(Math.max(distance, 96), card));
}

type QuoteCard = {
  article: HTMLElement;
  block: HTMLElement;
  text: HTMLElement;
  author: HTMLElement;
};

export function mount(root: HTMLElement, options: MountOptions): void {
  const quotes = options.quotes;
  const random = options.random ?? Math.random;
  followSystemTheme(options.prefersDark);

  root.replaceChildren();
  if (quotes.length === 0) return;

  const feed = document.createElement("main");
  root.append(feed);

  const storage = options.storage ?? storageForMount();
  const poolKey = scrollPoolKey(quotes);
  const stored = loadScroll(poolKey, storage);
  let deck: QuoteDeck;
  let seen: Quote[] = [];
  let index = 0;

  const restoredSeen = stored ? quotesFromIds(quotes, stored.seenIds) : null;
  const resumed =
    stored && restoredSeen
      ? resumeDeck(quotes, random, stored.queueIds, stored.lastId)
      : null;
  if (stored && restoredSeen && resumed) {
    deck = resumed;
    seen = restoredSeen;
    index = stored.index;
  } else {
    deck = new QuoteDeck(quotes, random);
  }

  function persist(): void {
    const currentQuote = seen[index];
    if (!currentQuote) return;
    saveScroll(
      {
        v: 1,
        pool: poolKey,
        ...deck.snapshot(),
        seenIds: seen.map((quote) => quote.id),
        index,
      },
      storage,
    );
  }
  let current = createCard();
  feed.append(current.article);
  let neighbor: QuoteCard | null = null;
  let held: Quote | null = null;
  let drag: { pointerId: number; originY: number; originT: number } | null = null;
  let settleToken = 0;

  function reduceMotion(): boolean {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  function lengthPx(value: string): number {
    const parsed = parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  function travelPx(element: HTMLElement): number {
    const block = element.querySelector("blockquote")?.getBoundingClientRect().height ?? 0;
    return handoffTravel(block, element.clientHeight);
  }

  function fitCard(card: QuoteCard): void {
    const { article, block, text } = card;
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

  function paint(card: QuoteCard, quote: Quote): void {
    card.article.dataset.quoteId = quote.id;
    card.text.textContent = quote.text;
    card.author.textContent = quote.author;
  }

  function show(card: QuoteCard, quote: Quote): void {
    paint(card, quote);
    card.article.classList.add("is-visible");
    fitCard(card);
  }

  function canFollow(deltaY: number): boolean {
    return deltaY < 0 || index > 0;
  }

  function quoteAhead(direction: 1 | -1): Quote | null {
    const nextIndex = index + direction;
    if (nextIndex < 0) return null;
    if (nextIndex < seen.length) return seen[nextIndex] ?? null;
    if (direction < 0) return null;
    if (!held) held = deck.draw();
    return held;
  }

  function advance(direction: 1 | -1): Quote | null {
    const nextIndex = index + direction;
    if (nextIndex < 0) return null;
    if (nextIndex < seen.length) {
      const quote = seen[nextIndex];
      if (!quote) return null;
      index = nextIndex;
      persist();
      return quote;
    }
    const quote = held ?? deck.draw();
    held = null;
    if (!quote) return null;
    seen.push(quote);
    index = seen.length - 1;
    persist();
    return quote;
  }

  function dropNeighbor(): void {
    neighbor?.article.remove();
    neighbor = null;
  }

  function dismissNeighbor(): void {
    const card = neighbor;
    if (!card) return;
    neighbor = null;
    const el = card.article;
    const away = translateY(el) >= 0 ? travelPx(current.article) : -travelPx(current.article);
    el.classList.remove("is-visible");
    el.classList.add("is-leaving", "is-handoff");
    el.setAttribute("aria-hidden", "true");
    el.style.transition = "";
    void el.offsetWidth;
    el.style.opacity = "0";
    el.style.transform = `translate3d(0, ${away}px, 0)`;
    const remove = () => el.remove();
    el.addEventListener("transitionend", remove, { once: true });
    window.setTimeout(remove, transitionMs(el) + 80);
  }

  function followNeighbor(offset: number, deltaY: number): void {
    if (reduceMotion() || deltaY === 0 || !canFollow(deltaY)) {
      dropNeighbor();
      return;
    }
    const direction: 1 | -1 = deltaY < 0 ? 1 : -1;
    const quote = quoteAhead(direction);
    if (!quote) {
      dropNeighbor();
      return;
    }
    if (!neighbor || neighbor.article.dataset.quoteId !== quote.id) {
      dropNeighbor();
      neighbor = createCard();
      paint(neighbor, quote);
      neighbor.article.classList.add("is-visible");
      neighbor.article.setAttribute("aria-hidden", "true");
      feed.append(neighbor.article);
      fitCard(neighbor);
    }
    const y = offset + direction * travelPx(current.article);
    neighbor.article.style.transition = "none";
    neighbor.article.style.transform = `translate3d(0, ${y}px, 0)`;
    neighbor.article.style.opacity = String(1 - swipeOpacity(offset));
  }

  function track(deltaY: number): void {
    const card = current.article;
    const offset = dragOffset(deltaY, canFollow(deltaY));
    card.classList.add("is-dragging");
    card.style.transition = "none";
    card.style.transform = `translate3d(0, ${offset}px, 0)`;
    card.style.opacity = String(swipeOpacity(offset));
    followNeighbor(offset, deltaY);
  }

  function releaseFinger(): void {
    const card = current.article;
    card.classList.remove("is-dragging", "is-handoff");
    card.style.transition = "";
    card.style.transform = "";
    card.style.opacity = "";
  }

  function snapHandoff(): void {
    settleToken += 1;
    dropNeighbor();
    for (const node of feed.querySelectorAll(".quote.is-leaving")) node.remove();
    const card = current.article;
    card.classList.add("is-visible");
    card.classList.remove("is-dragging", "is-handoff", "is-leaving");
    card.removeAttribute("aria-hidden");
    card.style.transition = "none";
    card.style.opacity = "";
    card.style.transform = "";
  }

  function beginHandoff(direction: 1 | -1, quote: Quote): void {
    const leaving = current;
    const travel = travelPx(leaving.article);
    const dragY = translateY(leaving.article);
    const enterY = dragY + direction * travel;
    const exitY = direction === 1 ? Math.min(dragY, -travel) : Math.max(dragY, travel);

    let arriving = neighbor && neighbor.article.dataset.quoteId === quote.id ? neighbor : null;
    neighbor = null;
    if (!arriving) {
      arriving = createCard();
      paint(arriving, quote);
      arriving.article.classList.add("is-visible");
      arriving.article.style.transition = "none";
      arriving.article.style.opacity = "0";
      arriving.article.style.transform = `translate3d(0, ${enterY}px, 0)`;
      feed.append(arriving.article);
      fitCard(arriving);
    } else {
      arriving.article.style.transition = "none";
      arriving.article.removeAttribute("aria-hidden");
    }

    leaving.article.style.transition = "none";
    leaving.article.style.transform = `translate3d(0, ${dragY}px, 0)`;
    if (leaving.article.style.opacity === "") leaving.article.style.opacity = "1";
    leaving.article.classList.remove("is-visible");
    leaving.article.classList.add("is-leaving");
    leaving.article.setAttribute("aria-hidden", "true");

    current = arriving;

    const token = ++settleToken;
    requestAnimationFrame(() => {
      if (token !== settleToken) return;
      armHandoff(leaving.article, arriving.article, exitY, token);
    });
  }

  function armHandoff(leavingEl: HTMLElement, arrivingEl: HTMLElement, exitY: number, token: number): void {
    if (token !== settleToken || !leavingEl.isConnected) return;
    leavingEl.classList.remove("is-dragging");
    leavingEl.classList.add("is-handoff");
    arrivingEl.classList.add("is-handoff");
    leavingEl.style.transition = "";
    arrivingEl.style.transition = "";
    void leavingEl.offsetWidth;
    void arrivingEl.offsetWidth;
    if (token !== settleToken) return;
    leavingEl.style.opacity = "0";
    leavingEl.style.transform = `translate3d(0, ${exitY}px, 0)`;
    arrivingEl.style.opacity = "";
    arrivingEl.style.transform = "";

    let finished = false;
    const finish = () => {
      if (finished || token !== settleToken) return;
      finished = true;
      window.clearTimeout(timer);
      leavingEl.removeEventListener("transitionend", onEnd);
      leavingEl.remove();
      arrivingEl.classList.remove("is-handoff");
    };
    const onEnd = (event: Event) => {
      if (event.target !== leavingEl) return;
      const name = (event as TransitionEvent).propertyName;
      if (name && name !== "opacity" && name !== "transform") return;
      finish();
    };
    leavingEl.addEventListener("transitionend", onEnd);
    const timer = window.setTimeout(finish, transitionMs(leavingEl) + 80);
  }

  function settle(deltaY: number, elapsedMs: number): void {
    const direction = swipeDirection(deltaY, elapsedMs, canFollow(deltaY));
    drag = null;
    if (direction === null || reduceMotion()) {
      releaseFinger();
      if (reduceMotion()) dropNeighbor();
      else dismissNeighbor();
      if (direction) {
        const quote = advance(direction);
        if (quote) show(current, quote);
      }
      return;
    }
    const quote = advance(direction);
    if (!quote) {
      releaseFinger();
      dropNeighbor();
      return;
    }
    beginHandoff(direction, quote);
  }

  if (seen.length === 0) {
    const first = deck.draw();
    if (!first) return;
    seen.push(first);
    index = 0;
  }
  const active = seen[index];
  if (!active) return;
  show(current, active);
  persist();

  if (typeof ResizeObserver === "function") {
    const observer = new ResizeObserver(() => fitCard(current));
    observer.observe(feed);
  }
  const fonts = document.fonts;
  if (fonts) void fonts.ready.then(() => fitCard(current));

  feed.addEventListener("pointerdown", (event) => {
    if (event.pointerType === "mouse" && event.button !== 0) return;
    snapHandoff();
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
    dismissNeighbor();
  });

  feed.addEventListener(
    "touchmove",
    (event) => {
      event.preventDefault();
    },
    { passive: false },
  );
}

function createCard(): QuoteCard {
  const article = document.createElement("article");
  article.className = "quote";
  const block = document.createElement("blockquote");
  const text = document.createElement("p");
  text.className = "quote-text";
  const author = document.createElement("cite");
  author.className = "quote-author";
  block.append(text, author);
  article.append(block);
  return { article, block, text, author };
}

function translateY(element: HTMLElement): number {
  const match = /translate3d\(\s*0(?:px)?,\s*(-?\d+(?:\.\d+)?)px/.exec(element.style.transform);
  return match?.[1] ? Number(match[1]) : 0;
}

function transitionMs(element: HTMLElement): number {
  const raw = getComputedStyle(element).transitionDuration.split(",")[0]?.trim() ?? "";
  const amount = parseFloat(raw);
  if (!Number.isFinite(amount) || amount <= 0) return 440;
  return raw.endsWith("ms") ? amount : amount * 1000;
}
