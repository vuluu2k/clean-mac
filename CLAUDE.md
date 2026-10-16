<!-- BEGIN bigpowers:project -->
# clean-mac

Read `CONVENTIONS.md` before changing code or running Git operations.

Native macOS 14+ disk cleanup assistant. Swift 6, SwiftUI, Foundation, no external dependencies.

| Action | Command |
|---|---|
| Test | `swift test` |
| Build app | `./Scripts/build-app.sh` |
| Package download | `./Scripts/build-dmg.sh` |
| Run | `./Scripts/run-app.sh` |
| Preflight | `swift test && swift Scripts/check-localization.swift && node --test Scripts/test-site.mjs && ./Scripts/build-app.sh` |
| Website check | `node --test Scripts/test-site.mjs` |
| Website preview | `python3 -m http.server 8000 --directory site` |

`CleanMacCore` owns scan rules, filesystem validation, and Trash operations.
`CleanMac` owns presentation and asynchronous task state.
Read `specs/product/SCOPE_LATEST.yaml` before expanding features.
Never scan or clean real user data during automated verification.
`site/` is a bilingual static GitHub Pages landing, separate from the native app. Keep website claims aligned with app safety limits. Never commit local logs, credentials, generated app bundles or private screenshots. Publish verified DMG/checksum files as versioned GitHub Release assets, with explicit ad-hoc/notarization disclosures.
<!-- END bigpowers:project -->
