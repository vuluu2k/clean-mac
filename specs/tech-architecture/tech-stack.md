# Architecture and safety boundary — 0.3.0

## Modules

- `CleanMacCore`: immutable results, scan rules, filesystem metadata, app inventory, leftover matching and Trash validation.
- `CleanMac`: main-actor view model and SwiftUI dashboard. Worker tasks perform scans and cleanup outside the main actor.
- `Scripts`: release build, bundle assembly, ad-hoc signing, launch.

## Scan modes

`Scanner` retains the original quick-scan roots and age rules.
`DeepScanner` composes quick results, known application roots, a read-only startup-volume walk, and leftover analysis.
`FileTreeWalker` uses relative directory names to preserve validated root spellings. Cocoa URL listings can rewrite `/var` to `/private/var`.
The deep walk includes hidden entries and package descendants but skips symlinks, aliases, cloud placeholders, pseudo filesystems, external volumes, APFS duplicate paths, Trash and common credential directories.
Every inaccessible path produces a bounded warning. Cancellation and result limits remain visible.
Only application `Contents/Info.plist` contents are read, up to 1 MiB. Other files are inspected through metadata only.

Both scanners publish throttled immutable previews (at most 500 items) as well as progress. The main actor rejects snapshots from stale scan IDs or inactive scans. Busy/confirmation guards still block cleanup during scanning.
Deep file analysis starts at 10 MB; Quick keeps its 100 MB rule. Batched bounded pruning retains the largest deep files, including late discoveries, before final deduplication and leftover prioritization.
`FolderUsage` is a separate read-only result type, never a `ScanItem` cleanup capability. Aggregate accessible file sizes into at most eight ancestor levels / 50,000 paths; show the largest 100 folders from 100 MB. Ancestor/descendant totals overlap and must not be added. Folder-detail limits do not stop traversal.
Persist inspection counts, logical bytes and read-error counts separately from findings. Counts can overlap between Quick and Deep passes; neither counters nor a completed traversal prove full-volume access.

## Suspected ownership

`ApplicationInventory` collects bundle identifiers from application roots and deep-discovered apps.
`LeftoverScanner` recognizes exact reverse-DNS names in specific user/system Library locations.
It checks both indexed app IDs and LaunchServices. Apple IDs, group names and installed vendor families remain protected.
Missing .app ownership is a heuristic, not proof of uninstallation. Friendly app names are not enough evidence.
Incomplete application inventory makes leftover findings read-only.

## Cleanup contract

`ScanItem.canTrash` is false for system analysis and explicitly locked findings.
The UI excludes those items from Select All, captured confirmation and selected totals.
The core independently rejects them. A forged flag cannot grant access to containers or system data.
Ordinary cleanup moves explicitly selected regular files only. Folders, hidden data, packages, multiply linked files, placeholders and known databases cannot move through that capability. App removal uses a separate restricted capability below.
For suspected leftovers, cleanup rebuilds the standard-root inventory, checks LaunchServices again, derives ownership from the actual path and verifies the app ID.
Allowlisted user locations are Caches, Logs, Preferences, Application Support and Saved Application State.
Containers, shared Library locations, launch agents and daemons are read-only.
The current device, inode, byte size, mtime and ctime must match the scan snapshot.
The native `FileManager.trashItem` call has no permanent-delete fallback. Failed items remain visible.

## Application removal and recommendations

`InstalledApplication` retains a bounded plist identity and root stat snapshot. `ApplicationBundleSnapshot` captures the complete metadata tree (maximum 200,000 entries), recording symlinks without following targets. `ApplicationUninstaller` restricts the bundle to third-party /Applications or ~/Applications apps, protects Apple/system/self/running apps and rechecks scope, identity, descendants and running state before native Trash.

`ApplicationRemovalPlan` holds reviewed bundle and exact-ID related files. No files are selected by default. An immutable separate confirmation captures only eligible selected data; the app bundle is always part of that explicit uninstall intent. The app moves first. App failure prevents data operations; later data failures are reported independently, without fallback or automatic rollback.

Fresh inventory and registration checks protect other installed copies and vendor families. Containers, services, databases and system/shared data stay locked. Related traversal is bounded to 50,000 entries and 20,000 stored files. Unmatched friendly names and vendor-specific helpers can be missed; the UI does not claim complete removal.

`CleanupRecommendation` is presentation guidance, not permission: eligible old caches/logs/build data are recommended with caveats; installers, large files and uncertain data require review; locked findings stay locked. Core validation independently derives eligibility. Filter/category/search intersection never grants cleanup capability. Directory aggregates remain separate and read-only.

`AppModel` serializes scans, app review, cleanup and uninstall. Captured confirmation blocks other work. Filesystem work and catalog protection lookups run off the main actor; UI filters cached records. Tests inject both ordinary and app Trash operations.

## Runtime localization

`AppLanguage` stores the explicit vi/en choice in local UserDefaults. The sidebar switches it only while idle with no open review. IDs, paths, filters, selections and snapshot capabilities do not depend on language.

`LocalizedText` retains Foundation `String.LocalizationValue` until display, including typed interpolation values. Its frozen Vietnamese source keeps equality and warning IDs stable. Safety decisions inspect typed protection fields, not translated strings. Native OS errors can retain the system language.

SwiftUI uses the selected environment locale. Every sheet receives that locale explicitly, including nested uninstall confirmation. Scan-mode picker labels use localized literals; locale changes do not rebuild the entire dashboard or reset selection.

SwiftPM owns core `.strings` resources. The app build copies the core resource bundle and the main SwiftUI localization tables into Contents/Resources. `L10n` prefers the packaged bundle before SwiftPM's development fallback. The fixture verifies that resolved resources live inside the app.

Verify translations with `swift Scripts/check-localization.swift`: compiler-extracted English coverage, matching placeholders and three paired privacy descriptions. Vietnamese source strings provide fallback text.

## Limits

A path-based Trash API cannot make validation atomic against hostile concurrent renames.
Portable apps outside known roots that are not registered can escape a later reinstallation check. Absence never proves abandonment.
App inventory identifies .app bundles, not every independent CLI package or plugin.
Full Disk Access does not bypass SIP or Unix ownership permissions. No privileged helper is included.
Never run with elevated privileges. Close relevant applications before cleanup.

## Space accounting

Show scanned logical bytes, retained finding bytes, bytes eligible for review and current volume availability separately. Folder aggregates include small files and represent the scan snapshot, not live disk usage.
APFS clones, compression, and hard links affect physical storage. Moving files to Trash does not recover space.
The app never empties Trash.

## Verification

Run `swift test && ./Scripts/build-app.sh`.
Tests inject temporary homes, startup-volume roots, application registration lookup and Trash movement.
Real full-disk scans, Full Disk Access/SIP interactions and Finder Trash/Put Back require manual verification.

## API sources

- https://developer.apple.com/documentation/foundation/filemanager/trashitem(at:resultingitemurl:)
- https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(withbundleidentifier:)
- https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/mac
- https://support.apple.com/en-us/102624
