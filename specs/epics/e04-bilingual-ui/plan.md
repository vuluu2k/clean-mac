# E04 — Persistent Vietnamese / English switch

Approved by the user: add an in-app switch between Vietnamese and English, not documentation alone. Keep the current Vietnamese default and persist the explicit choice locally.

## Reach and safety

- AppModel language preference, visible sidebar selector, all SwiftUI labels/menus/confirmations, core recommendation/reason/error messages and scan/app status text.
- Retain source message templates and interpolation values until display so existing results can change language without rescanning.
- Use Foundation localization values and SwiftPM .strings resources; no translation service or dependency.
- Language changes must not alter IDs, paths, snapshots, eligibility, selected files, captured confirmations or operation order. OS-owned error/permission text may follow macOS language.
- Package resource bundles into the standalone app; do not depend on absolute developer build paths.
- English and Vietnamese READMEs link to each other.

## Implementation checkpoint

- In-app selector, local preference, deferred core messages and 211 English keys implemented. 49 tests pass.
- SwiftUI scan picker uses native localized literals so its labels update in both directions.
- Selected locale is passed explicitly to every sheet, including nested uninstall confirmation. Native fixture confirmed the Vietnamese confirmation correction and English switch without resetting selection.
- Main and core resource bundles are included in the standalone app. Native fixture asserts packaged paths rather than developer build fallbacks.
- Final bilingual UI sweep and paired READMEs passed. Consolidated release evidence: `specs/verifications/verification.yaml` and `bilingual-behavior.md`. Actual release launched idle with no automatic scan; real-data UAT remains pending.

## Checks

1. Failing tests for EN/VI labels, formatted placeholders, deferred messages and preference round-trip in an isolated defaults suite.
2. All extracted source keys translated; placeholder signatures match; resource files parse.
3. Existing safety suite remains green. Native fixture switch updates existing results, retains selections and persists after relaunch.
4. Render scan, related review and confirmation in both languages with fake roots and fake Trash only.
5. Full tests and standalone separate-bundle preflight. No real scans, native Trash, permission changes, user-process termination, commit or push.
