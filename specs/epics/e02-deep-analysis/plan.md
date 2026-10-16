# E02 — Deep analysis and suspected app leftovers

Type: implementation-plan. Context: user requests whole-Mac discovery and leftover cleanup suggestions.

## Scope

- An explicit Deep mode walks accessible startup-volume directories, including hidden data and packages, using metadata only.
- Skip pseudo filesystems, external volumes, APFS duplicate volume paths, Trash, credentials, symlinks and cloud placeholders.
- Discover installed .app bundle identifiers from application roots and the deep walk. Consult LaunchServices for each suspected owner.
- Recognize exact reverse-DNS names in user/system Caches, Logs, Preferences, Application Support, Saved Application State, Containers and launch-agent locations.
- Never label missing app ownership as proven uninstallation. Protect Apple IDs, shared-group names and installed vendor families.
- Permit confirmed ordinary user-owned files only in the narrow leftover allowlist. Containers, shared locations, launch agents and known databases are read-only.
- Keep directory structures intact. Do not add root helpers, sudo, automatic Trash emptying or fuzzy app-name matching.

## Slices

1. Extend result types with categories, ownership evidence and enforced read-only capability.
2. Test and implement .app inventory and leftover matching with injected volume roots and registration lookup.
3. Test and implement broad metadata traversal, bounded result storage, exclusions and cancellation.
4. Reject read-only cleanup, re-inventory applications and revalidate ownership/stat immediately before moving each file.
5. Add mode controls, permission settings link, evidence/read-only labels and selection guards.
6. Run fixtures, release build and idle UI smoke. Document remaining manual checks.

## Acceptance and manual checks

- Deep mode is opt-in. Launch does not scan personal data.
- A denied path warns the user rather than silently claiming full coverage.
- Switching modes clears prior selection and results.
- System findings cannot enter confirmation, even through Select All or forged IDs.
- An application reinstalled after the scan blocks associated leftover cleanup.
- Canceled/incomplete inventories cannot enable suspected-leftover cleanup.
- Test a disposable user fixture manually before any valuable data. Real FDA/SIP and native Trash/Put Back remain user validation.

Verify: `swift test && ./Scripts/build-app.sh`.
