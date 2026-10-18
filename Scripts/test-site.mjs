import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { messages, preferredLanguage } from "../site/translations.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const html = readFileSync(resolve(root, "site/index.html"), "utf8");
const css = readFileSync(resolve(root, "site/style.css"), "utf8");
const controller = readFileSync(resolve(root, "site/site.mjs"), "utf8");

test("both languages cover every page and accessibility key", () => {
  assert.deepEqual(Object.keys(messages.en).sort(), Object.keys(messages.vi).sort());
  for (const match of html.matchAll(/data-i18n(?:-aria|-alt)?="([^"]+)"/g)) {
    for (const language of ["en", "vi"]) assert.ok(messages[language][match[1]]?.trim(), `${language}: ${match[1]}`);
  }
  for (const text of Object.values(messages.en)) assert.equal(typeof text, "string");
});

test("language preference accepts only the supported choices", () => {
  assert.equal(preferredLanguage("en", "vi-VN"), "en");
  assert.equal(preferredLanguage("vi", "en-US"), "vi");
  assert.equal(preferredLanguage(null, "vi-VN"), "vi");
  assert.equal(preferredLanguage("__proto__", "en-US"), "en");
  assert.equal(preferredLanguage("unsupported", undefined), "en");
});

test("relative assets and anchors work under a GitHub project prefix", () => {
  const ids = new Set([...html.matchAll(/\bid="([^"]+)"/g)].map(m => m[1]));
  for (const [, value] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (value.startsWith("#")) assert.ok(ids.has(value.slice(1)), value);
    else if (!value.startsWith("https://")) {
      assert.ok(value.startsWith("./"), value);
      assert.ok(existsSync(resolve(root, "site", value)), value);
    }
  }
  assert.match(html, /rel="canonical" href="https:\/\/vuluu2k\.github\.io\/clean-mac\/"/);
});

test("mobile source link remains named and native controls are accessible", () => {
  assert.match(html, /class="source-link"[^>]*aria-label=/);
  assert.match(html, /class="skip-link" href="#main"/);
  assert.equal((html.match(/<h1\b/g) ?? []).length, 1);
  assert.equal((html.match(/<details>/g) ?? []).length, 5);
  assert.match(html, /id="copy-status"[^>]*role="status"/);
  assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /:focus-visible/);
});

test("screenshot tabs are accessible and every language variant exists", () => {
  assert.equal((html.match(/role="tablist"/g) ?? []).length, 1);
  const tabs = [...html.matchAll(/role="tab" id="([^"]+)" aria-controls="([^"]+)"/g)];
  assert.equal(tabs.length, 4);
  for (const [, tab, panel] of tabs) assert.match(html, new RegExp(`role="tabpanel" id="${panel}" aria-labelledby="${tab}"`));
  const shots = [...html.matchAll(/data-shot="([^"]+)"/g)].map(m => m[1]);
  assert.equal(shots.length, 4);
  for (const shot of shots) for (const language of ["en", "vi"]) {
    assert.ok(existsSync(resolve(root, `site/assets/screenshots/${shot}-${language}.webp`)), `${shot}-${language}`);
  }
  assert.match(controller, /ArrowRight/);
  assert.match(controller, /Home/);
  assert.match(controller, /End/);
});

test("download links match the native app version and include verification guidance", () => {
  const plist = readFileSync(resolve(root, "Resources/Info.plist"), "utf8");
  const version = plist.match(/<key>CFBundleShortVersionString<\/key><string>([^<]+)<\/string>/)?.[1];
  assert.ok(version);
  const release = `https://github.com/vuluu2k/clean-mac/releases/download/v${version}`;
  assert.ok(html.includes(`${release}/clean-mac-${version}-universal.dmg`));
  assert.ok(html.includes(`${release}/SHA256SUMS`));
  assert.match(html, /id="download-app"/);
  assert.ok(html.includes("https://github.com/vuluu2k/clean-mac/blob/main/INSTALL.md"));
  assert.match(messages.en.downloadWarning, /not notarized/);
});

test("public copy is honest and the page has no external runtime dependencies", () => {
  assert.match(html, /git clone https:\/\/github.com\/vuluu2k\/clean-mac.git/);
  assert.match(html, /\.\/Scripts\/run-app.sh/);
  assert.match(messages.en.previewCaption, /Sample data/);
  assert.match(messages.en.buildCaution, /not notarized/);
  assert.match(messages.en.faq3Body, /manual verification/);
  assert.match(messages.en.safetyNote, /does not free space/);
  assert.doesNotMatch(html, /<form\b|<script[^>]+src="https?:/);
  assert.doesNotMatch(css, /@import|url\(["']?https?:/);
  assert.doesNotMatch(controller, /innerHTML|eval\(|fetch\(/);
});
