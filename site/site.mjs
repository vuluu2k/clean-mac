import { messages, preferredLanguage } from "./translations.mjs";

const storageKey = "cleanMacSiteLanguage";
let stored;
try { stored = localStorage.getItem(storageKey); } catch { /* Storage can be disabled. */ }
let language = preferredLanguage(stored, navigator.language);
const status = document.querySelector("#copy-status");

function applyLanguage(next) {
  if (next !== "en" && next !== "vi") return;
  language = next;
  const text = messages[language];
  document.documentElement.lang = language;
  document.title = text.pageTitle;
  document.querySelector('meta[name="description"]').content = text.pageDescription;
  document.querySelector('meta[property="og:title"]').content = text.pageTitle;
  document.querySelector('meta[property="og:description"]').content = text.pageDescription;
  document.querySelector('meta[property="og:locale"]').content = language === "vi" ? "vi_VN" : "en_US";
  document.querySelectorAll("[data-i18n]").forEach(element => {
    const value = text[element.dataset.i18n];
    if (typeof value === "string") element.textContent = value;
  });
  document.querySelectorAll("[data-i18n-aria]").forEach(element => {
    const value = text[element.dataset.i18nAria];
    if (typeof value === "string") element.setAttribute("aria-label", value);
  });
  document.querySelectorAll("[data-language]").forEach(button => {
    button.setAttribute("aria-pressed", String(button.dataset.language === language));
  });
  status.textContent = "";
}

applyLanguage(language);
document.querySelectorAll("[data-language]").forEach(button => {
  button.addEventListener("click", () => {
    applyLanguage(button.dataset.language);
    try { localStorage.setItem(storageKey, language); } catch { /* The interface still works without storage. */ }
  });
});

document.querySelector("#copy-command").addEventListener("click", async () => {
  try {
    if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable");
    await navigator.clipboard.writeText(document.querySelector("#build-command").textContent.trim());
    document.querySelector("#copy-label").textContent = messages[language].copied;
    status.textContent = messages[language].copySuccess;
  } catch {
    status.textContent = messages[language].copyFailure;
  }
});
