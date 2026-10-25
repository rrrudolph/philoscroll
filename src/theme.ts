import { theme } from "./tokens";

export function applyTheme(): void {
  document.documentElement.dataset.theme = "dark";
  let meta = document.querySelector('meta[name="theme-color"]');
  if (!(meta instanceof HTMLMetaElement)) {
    meta = document.createElement("meta");
    meta.setAttribute("name", "theme-color");
    document.head.append(meta);
  }
  meta.setAttribute("content", theme.bg);
}
