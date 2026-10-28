export type ThemeName = "light" | "dark";

export const themes = {
  light: {
    bg: "#FDFBF7",
    text: "#1F2937",
    muted: "#4B5563",
    accent: "#3E5140",
    line: "#908778",
    glow: "rgba(62, 81, 64, 0.14)",
  },
  dark: {
    bg: "#121824",
    text: "#E5E7EB",
    muted: "#9AA3B2",
    accent: "#B7C9A3",
    line: "#6B768A",
    glow: "rgba(183, 201, 163, 0.10)",
  },
} as const;
