# E06 — Faithful product presentation and update notices

## Approved scope

The owner rejected the first landing as too quiet and its HTML app illustration as unlike the native UI. Replace it with a stronger product-led layout and real SwiftUI captures rendered against isolated sample data. Add bilingual installation instructions directly on the page.

The owner selected update notices, not automatic installation. Add a manual check and an optional, default-off launch check against this project's public GitHub Releases. Do not send scan data, automatically download/replace the app, interrupt scans or open an unsolicited modal.

## Impact

- `CleanMacCore`: bounded HTTPS release metadata retrieval, stable-version comparison and validation. No scanner, cleanup or uninstall capability changes.
- `CleanMac`: isolated update state, preference, menu/sidebar entry and localized sheet. Package version becomes 0.4.0; expose actual bundle version instead of a fixed sidebar label.
- Privacy: this is an explicit exception to offline-only behavior. Checking exposes ordinary request metadata such as IP to GitHub, not file names, scan results or identifiers. Cookies/credentials are not used; redirects are rejected.
- `site/`: centered oversized type, dark/mint native-inspired palette, genuine native screenshots, accessible screenshot tabs, inline install/security section and existing source/download links.
- Capture fixtures: actual production views, injected temporary Home/startup roots, fixed test disk metadata, blocked Trash and application registration. No real scan, app lookup or cleanup. No private paths or real disk statistics in published images.
- Docs/localization/tests: both app and site languages; update privacy and limits in README/INSTALL/scope. GitHub release assets stay outside Git.

## Tasks / gates

1. Test and implement numeric stable-version validation and GitHub release checks, including invalid/draft/prerelease/oversize/HTTP failures.
2. Test manual/automatic update state: opt-in off by default, daily launch throttle, errors, no competing checks and no data-state changes. Add menu/sidebar and bilingual notice sheet.
3. Render and inspect native sample screenshots for storage, uninstall review and confirmation in both languages. Derive optimized site assets without private machine data.
4. Replace approximate HTML mockup and redesign the page. Preserve download/signing truth, EN/VI switching, reduced motion, keyboard controls, copy failure handling and project-prefix paths. Put installation on the page.
5. Swift/localization/site/native fixture/browser gates; package a separate Universal 0.4.0 DMG without overwriting running bundles. Review all public files.
6. Publish via checked feature PR, never direct-push main. Release verified DMG/checksum, deploy Pages and verify unauthenticated downloads + live browser behavior.

## Limits

No self-installing updater, privileged helper, telemetry, Gatekeeper/SIP bypass, real-data scan or cleanup. Distribution remains ad-hoc signed and not notarized. Native Trash/Put Back and Intel/macOS 14 hardware remain manual UAT.
