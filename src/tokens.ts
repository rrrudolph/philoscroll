export type ThemeName = "light" | "dark";

export const themes = {
  light: {
    bg: "#120e0a",
    surface: "#ede4d3",
    text: "#000000",
    quote: "#363636",
    muted: "#000000",
    accent: "#3e5140",
    line: "#6b5f52",
    glow: "rgba(62, 81, 64, 0.14)",
  },
  dark: {
    bg: "#0d1014",
    surface: "#0d1014",
    text: "#e5e7eb",
    quote: "#c4c9d1",
    muted: "#9aa3b2",
    accent: "#b7c9a3",
    line: "#6b768a",
    glow: "rgba(183, 201, 163, 0.10)",
  },
} as const;
