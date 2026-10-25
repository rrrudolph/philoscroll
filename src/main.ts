import "@fontsource/source-serif-4/latin-400-italic.css";
import "@fontsource/outfit/latin-400.css";
import "@fontsource/outfit/latin-500.css";
import "./styles.css";
import raw from "../data.json";
import { mount } from "./app";
import { loadQuotes } from "./quotes";

const root = document.querySelector("#app");
if (root instanceof HTMLElement) {
  try {
    mount(root, { quotes: loadQuotes(raw) });
  } catch (error) {
    root.textContent = "The teachings could not be opened.";
    console.error(error);
  }
}
