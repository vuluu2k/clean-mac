# Bilingual UI verification — 0.3.0

## Mechanical checks

Final command:

```sh
swift test && swift Scripts/check-localization.swift && CLEAN_MAC_APP_PATH="$PWD/dist/preview/clean-mac.app" ./Scripts/build-app.sh
```

Passed: 49 tests, 211 compiler-extracted English keys, placeholder parity, three paired privacy descriptions, release build, plist validation and ad-hoc signature verification. Evidence: `bilingual-preflight.log`. Compiler warnings: none.

README style checking completed with zero errors and two nonblocking descriptive/table terminology warnings. No formal STE compliance is claimed.

## Native fixture scenarios

An explicit NSWindow/NSHostingView runner rendered production AppModel/Dashboard/views against release core objects. All filesystem roots, application lookup, running-state checks and Trash movement were injected. Fixture preferences used a separate bundle identifier.

Assertions and observed output:

```text
UI_READY mode=switch-en language=en files=3 selected=1 packagedResources=true
UI_READY mode=persistence language=en packagedResources=true
UI_READY mode=review-en language=en apps=2 selected=0 confirmationFiles=0 packagedResources=true
UI_READY mode=confirmation-en language=en apps=2 selected=1 confirmationFiles=1 packagedResources=true
UI_READY mode=switch-vi language=vi files=3 selected=1 packagedResources=true
UI_READY mode=review-vi language=vi apps=2 selected=0 confirmationFiles=0 packagedResources=true
UI_READY mode=confirmation-vi language=vi apps=2 selected=1 confirmationFiles=1 packagedResources=true
```

Switch scenarios first completed a fake deep scan, deliberately selected one cache and selected the recommendation filter. Switching in either direction retained the complete item array, selected ID, filter and scanned state. A separate relaunch retained English without resetting the preference. Attempting a language change during confirmation did not change the language or confirmation token.

Every scenario asserted that the localization bundle URL is inside the app's Contents/Resources, not the absolute SwiftPM development fallback.

Visual checks confirmed translated navigation, scan controls, recommendation summaries, review reasons, related-file locks and both confirmation screens. Acknowledgment starts unchecked, the Trash button is disabled and paths/app names remain unchanged.

Temporary evidence under `.build/bilingual-smoke/`:

- `switch-en-fixed.png` and `switch-vi-fixed.png`
- `confirmation-en-fixed.png` and `confirmation-vi-fixed.png`
- `review-en.png`, `review-vi.png` and `persistence.png`
- Corresponding scenario logs and the disposable runner

## UI issues caught and corrected

- Cached dynamic scan-mode labels retained the previous language. Native localized literal labels now update with the locale.
- macOS sheets did not reliably inherit the parent locale. Every sheet, including nested confirmation, now receives the selected locale explicitly.
- Deferred recommendation badges observe locale changes without recreating the dashboard or resetting selection.
- Some initial WindowGroup-only harness launches had no visible window. Explicit NSWindow/NSHostingView removed that harness lifecycle uncertainty. The actual release app also launched normally.
- Window capture uses only owned PIDs. Activating an owned fixture before capture avoids offscreen-window omissions. No user process is stopped.

## Actual release idle smoke

`dist/preview/clean-mac.app` launched successfully. Screenshot: `.build/bilingual-smoke/release-idle.png`.
The language selector is visible, Quick scan is the initial mode, no scan starts automatically, selection is zero and cleanup is disabled. The release window remains open for the user. The original `dist/clean-mac.app` bundle remains unchanged.

## Limits

No agent-initiated real Home/startup-volume scan, native Trash, real uninstall, permission change, force quit, permanent deletion, commit or push occurred. Programmatic fixture switching plus visual inspection does not establish VoiceOver or every native interaction.

Real app/Put Back, FDA/SIP/Unix permission behavior, cloud-provider behavior, full-volume duration, light appearance, VoiceOver, macOS 14 and Intel remain manual checks. OS-owned dialogs/errors and byte formatting can follow macOS language/region rather than the app choice. Signing remains ad-hoc, without notarization.
