# Source safety review — 0.3.0

Type: self-review. Context: application removal, related-file review, recommendation filters and runtime vi/en localization in addition to the existing scan/cleanup boundaries.
The Git branch has no HEAD yet, so a merge-base/diff review is unavailable. No independent reviewer was requested.

## Data flow

1. The user selects Quick or Deep. App launch does not start a scan.
2. Quick retains Home-only scan rules. Deep adds read-only traversal of accessible startup-volume paths.
3. Application inventory reads bounded Info.plist files from discovered .app bundles. Other files are inspected through metadata.
4. Exact reverse-DNS names in specific Library roots become suspected ownership candidates after inventory and LaunchServices checks.
5. System, shared, container, service and known database findings remain read-only. Incomplete app inventories also lock leftovers.
6. UI selection and confirmation exclude read-only findings. Core cleanup rechecks capability independently.
7. Leftover cleanup rebuilds standard-root inventory and rechecks registration, ownership, ancestry and stat snapshots before native Trash.
8. A separate uninstall intent reviews a third-party app under safe roots and its full bounded bundle metadata tree. The app moves first only after captured confirmation; related data remains individually selected and validated.
9. Other app copies/vendor families and running/system/Apple/self apps are protected independently of UI flags.

## Checks

- PASS: no external dependencies, server, network transport, runtime subprocesses, root helper, sudo, SIP changes or automatic permission grants.
- PASS: no production permanent deletion or Empty Trash action.
- PASS: system read-only capability cannot be bypassed by Select All, raw selection IDs or a forged container flag.
- PASS: installed app IDs, vendor families, Apple IDs, shared names and newly registered/reinstalled apps are protected.
- PASS: symlink roots/ancestors, hard links, changed files and partial failure behavior remain covered by fixtures.
- PASS: deep traversal roots and application-registration lookup are injected in tests; real user data and Trash are untouched.
- PASS: 49 tests, 211 extracted localization keys and a separate release bundle pass the final preflight in `specs/verifications/bilingual-preflight.log`.
- PASS: language switches preserve fixture results, selected IDs and filters. Open confirmation blocks switching and keeps its captured token.
- PASS: safety checks use typed protection fields, not translated strings. Deferred text preserves warning identities and interpolates paths/names as values.
- PASS: core resources resolve from the packaged app, with paired privacy descriptions and matching placeholder signatures. Sheet locales are explicit.
- PASS: runtime API-site audit finds three injected/default native Trash calls and no network, subprocess or permanent-deletion sites in Sources/.
- PASS: complete bundle metadata revalidation detects changed descendants; internal symlinks are recorded without following external targets.
- PASS: app-first ordering, app Trash failure, later individual data failures, changed running state, forged IDs and other copies/vendor-family checks are fixture-covered.
- PASS: recommendation filtering intersects category/search without granting eligibility; selection starts empty and confirmation remains immutable.
- PASS: app catalog, review and confirmation native UI were rendered from production sources with temporary roots and fake Trash. No real uninstallation was performed.
- PASS: folder totals use a separate read-only type; forged folder IDs do not enter confirmation or the Trash pipeline.
- PASS: live previews are bounded to 500 rows, throttled, and rejected for stale scan IDs/inactive phases. Existing busy guards block cleanup during scanning.
- PASS: folder totals exclude protected credentials, external volumes and APFS duplicate paths in fixture regression tests.
- PASS: late larger files survive bounded result pruning; reduced deep analysis thresholds do not expand cleanup scope.
- FIXED: Cocoa URL directory listings can rewrite /var aliases. The new walker uses relative names beneath the validated root.

## Limits, not guarantees

- Missing .app ownership is not proof of uninstallation. CLI tools, plugins, portable apps or unplugged volumes can still need the data.
- Fresh cleanup inventory checks standard app roots and LaunchServices, not another whole-volume walk. Unregistered portable reinstallation elsewhere can be missed.
- Exact ID matching intentionally misses human-friendly folder names and protects entire installed vendor families conservatively.
- A path-based Trash API cannot make validation atomic against hostile concurrent renames. Never run as root.
- Known database recognition is extension-based. Ordinary Application Support files can still contain important offline data.
- Bundle removal does not invoke vendor uninstallers, unload services or remove drivers/extensions. Exact-ID matching can miss data. There is no automatic rollback of partially completed operations.
- Full Disk Access, SIP/Unix permission boundaries, real full-volume duration, provider behavior and real Finder Trash/Put Back remain manual checks.
- The bundle is ad-hoc signed and not notarized. No production security certification is claimed.

Verify: `swift test && ./Scripts/build-app.sh`.
