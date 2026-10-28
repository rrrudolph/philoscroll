import { themes, type ThemeName } from "./tokens";

export function themeFromPreference(prefersDark: boolean): ThemeName {
  return prefersDark ? "dark" : "light";
}

export function applyTheme(theme: ThemeName): void {
  document.documentElement.dataset.theme = theme;
  let meta = document.querySelector('meta[name="theme-color"]');
  if (!(meta instanceof HTMLMetaElement)) {
    meta = document.createElement("meta");
    meta.setAttribute("name", "theme-color");
    document.head.append(meta);
  }
  meta.setAttribute("content", themes[theme].bg);
}
