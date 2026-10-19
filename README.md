# clean-mac

**English** · [Tiếng Việt](README.vi.md) · [Website](https://vuluu2k.github.io/clean-mac/) · [GitHub](https://github.com/vuluu2k/clean-mac)

**Less clutter. More room. No subscription.**

A free, open-source macOS app built with SwiftUI. It explains cleanup suggestions and lets you decide what to remove.
No server, accounts, telemetry, cloud AI or external dependencies.
Optional update check (off by default) reads public release metadata from GitHub; no scan data is sent.

## Download

[Download Universal DMG — v0.4.0](https://github.com/vuluu2k/clean-mac/releases/download/v0.4.0/clean-mac-0.4.0-universal.dmg) · [SHA256SUMS](https://github.com/vuluu2k/clean-mac/releases/download/v0.4.0/SHA256SUMS)

The app includes Apple silicon and Intel code for macOS 14+. Intel hardware still needs manual verification.
**This download is ad-hoc signed, not Developer ID signed or notarized. macOS can block it.**
Read the [bilingual installation and security guide](INSTALL.md) before opening the disk image. Building from source remains an alternative.

## Build and run

Requires **macOS 14+** and Xcode or Command Line Tools with **Swift 6+**.

```bash
xcode-select --install  # Only if developer tools are missing
swift test
./Scripts/run-app.sh
```

The script builds and opens `dist/clean-mac.app`. You can drag this app into Applications.

To build without opening the app:

```bash
./Scripts/build-app.sh
```

The bundle uses local ad-hoc signing. It has no Developer ID signature or notarization.
Gatekeeper can block distribution to another Mac. Do not disable Gatekeeper globally.

## Switch between English and Vietnamese

Use the **Tiếng Việt / English** selector beside the globe at the top of the sidebar.
The interface changes immediately and saves your choice locally. Vietnamese is the initial default.
Existing results, filters and file selections stay intact. No restart or new scan is needed.

Language changes are disabled during an operation or an open review/confirmation.
System permission dialogs, native errors and disk-size formatting can follow macOS language or region settings.

## Features in 0.4.0

- Real disk capacity, background scans, progress, cancellation and bounded live previews.
- **Quick scan** for known cleanup locations and explicit **Deep volume scan** for accessible startup-volume metadata.
- Folder totals that include small files, with Finder reveal and no whole-folder removal.
- **Recommended / Review first / Do not delete** filters, explanations, search and category filters.
- Exact bundle-ID matching for suspected app leftovers, with ownership checks and protected data locks.
- **Uninstall apps** with related-file review, separate confirmation and running-app protection.
- No preselected files. Full-path confirmation, native Trash and individual failure reports.
- Optional update notices: manual check or opt-in daily launch check against GitHub Releases. No automatic download or install.

## Explainable rules, not garbage guarantees

| Category | Scope | Rule |
|---|---|---|
| Old caches | `~/Library/Caches` | Unchanged for at least 14 days |
| Old logs | `~/Library/Logs` | Unchanged for at least 14 days |
| Xcode builds | `~/Library/Developer/Xcode/DerivedData` | Each file unchanged for at least 30 days |
| Old installers | `~/Downloads` | `.dmg`, `.pkg`, `.mpkg` unchanged for at least 30 days |
| Large files | Downloads and explicitly added Home folders | At least 10 MB, always requires review |
| Suspected app leftovers | Recognized user/system Library locations | Exact bundle ID without a detected owning app |
| Volume analysis | Accessible startup-volume paths | Files from 10 MB, locked outside cleanup scope |
| Largest folders | Accessible deep-scan files | Totals from 10 MB, always analysis-only |

**Old or large does not mean unused.** Rules use modification time, not access time as proof of disuse.
Recommended cache/log/build files can still contain useful diagnostic or offline data.

Ordinary cleanup moves selected regular files only. Folder statistics never grant permission to remove a folder.
Empty cache/build folders remain untouched.

## Deep scans and permissions

1. Select **Deep volume scan**.
2. If you want wider read access, select **Full Disk Access**.
3. In **System Settings → Privacy & Security → Full Disk Access**, add and enable `clean-mac.app` yourself.
4. Quit and reopen the app. A rebuilt ad-hoc bundle can require permission again.
5. Start the scan. Use **Stop scan** to retain partial results.
6. Review inspection totals, folder sizes and access warnings before selecting files.

Few suggestions do not mean few inspected files. Deep scans count small files in folder totals.
Inspection counts can overlap between stages. Logical bytes are neither garbage estimates nor recoverable physical space.
Parent folder totals include children. Do not add those rows together.

Previews retain up to 500 files. Final results have no file-count cap; up to 100 warnings are kept.
Neither quick nor deep scans stop after a fixed number of entries.
Folder detail tracks up to eight ancestor levels and 50,000 paths, then shows the largest 100 folders.
Folder-detail limits do not stop file traversal.

Deep analysis includes hidden entries and package metadata. It excludes external volumes, pseudo filesystems, duplicate APFS paths, Trash and common credential folders.
It does not follow symlinks or intentionally download cloud placeholders.
Only bounded application `Contents/Info.plist` contents are read. Other user files are inspected through metadata.

Full Disk Access does not bypass SIP or Unix permissions. Access warnings describe incomplete coverage.
The app does not use `sudo`, privileged helpers or automatic permission changes.

## Suspected app leftovers

The app compares exact bundle IDs with known application roots, deep-scan discoveries and LaunchServices.
Recognized locations include Caches, Logs, Preferences, Application Support and Saved Application State.
Containers, services, system/shared Library data and known databases remain analysis-only.

A missing `.app` does not prove uninstallation. Portable apps, plugins, CLI tools and disconnected volumes can still need that data.
Apple IDs, shared names and installed vendor families are protected.
Friendly names such as `Slack` are not enough to establish ownership.

Incomplete inventories lock related-data cleanup. Before cleanup, the app rebuilds the standard-root inventory and checks LaunchServices again.
Unregistered portable apps outside those roots can still be missed.

## Uninstall an app and review its data

1. Open **Uninstall apps** and select **Scan apps**.
2. Find the app by name, bundle ID or path.
3. Quit the app normally. clean-mac never force-quits it.
4. Select **Review to uninstall**.
5. Inspect the app path and each related file. No data is preselected.
6. Select only data you want to discard. You can remove the app while retaining all related data.
7. Select **Review & uninstall**.
8. Review the fixed confirmation list and acknowledge the Trash operation.
9. Check the report and Finder Trash. When available, use **Put Back** to restore items.

Only verified third-party `.app` bundles under `/Applications` or `~/Applications` qualify.
Apple, system, running, out-of-scope and clean-mac itself are protected.
The app rechecks identity, running state and the complete bounded bundle metadata tree before moving it.
Changed, unreadable or oversized inspections block removal. Bundle inspection allows at most 200,000 entries.

Related data requires exact bundle-ID evidence. Other installed copies or vendor-family apps can lock shared data.
Related review inspects at most 50,000 entries and retains 20,000 files.
Databases, Containers, services and system/shared locations remain locked.

The app moves first. If that fails, related data stays untouched.
Later file failures are reported separately. There is no permanent-delete fallback or automatic rollback.
Drivers, extensions and daemons can require the vendor uninstaller. Complete removal is not guaranteed.

## Clean selected files safely

**CAUTION: Back up important data before cleanup.** Cache files can contain offline data. Rebuilding DerivedData can slow the next build.

1. Choose a scan mode and start a scan.
2. Read access warnings and partial-result notices.
3. Inspect paths and explanations. When needed, reveal the file in Finder.
4. Close apps that use the selected cache or build data.
5. Select only files you no longer need.
6. Select **Review & clean**, inspect the captured list and acknowledge the operation.
7. Inspect Finder Trash. When available, use **Put Back** to restore files.
8. When certain, empty Trash yourself in Finder.

**Moving to Trash does not free space.** The app never empties Trash.
APFS clones, compression and allocation affect actual recoverable space.

## Safety limits

- Ordinary cleanup rejects protected paths, packages, hidden files, aliases, symlinks, hard links and recognized cloud placeholders.
- A separately verified app bundle is the only directory-removal exception. Arbitrary data directories cannot be selected.
- Known database extensions and common incomplete downloads remain protected.
- Each operation rechecks scope, ancestry, file type, device/inode, size, mtime and ctime.
- Changed or inaccessible files stay untouched and require another scan.
- Path-based Trash cannot make validation atomic against hostile concurrent renames. Never run the app as root.

Duplicate detection, APFS snapshot removal, Docker cleanup and background schedules are not included.
Running-state checks apply to app uninstallation, not every possible consumer of each cache file.

## Development and localization

```bash
swift test
swift Scripts/check-localization.swift
./Scripts/build-app.sh
```

Tests inject temporary homes, startup-volume roots, application lookups and fake Trash operations.
They do not scan real user data or use native Trash.
Real uninstall/Put Back, Full Disk Access, VoiceOver, macOS 14 and Intel still need manual verification.

If another bundle is in use, build a separate preview:

```bash
CLEAN_MAC_APP_PATH="$PWD/dist/preview/clean-mac.app" ./Scripts/build-app.sh
```

Core policy and filesystem logic live in `Sources/CleanMacCore/`. SwiftUI presentation lives in `Sources/CleanMac/`.
Translations live in `Sources/CleanMacCore/Resources/`. Vietnamese source text is the fallback language.
The localization check extracts compiler keys and checks English coverage and format placeholders.
App names, paths and bundle IDs are interpolation values, never translated keys.

Build a Universal DMG with `./Scripts/build-dmg.sh`. It cross-builds the other architecture, signs ad-hoc, validates a read-only image mount and writes `dist/releases/` with checksums. Existing release output is not overwritten.

See the [safety conventions](CONVENTIONS.md), [uninstall plan](specs/epics/e03-app-uninstall/plan.md) and [language plan](specs/epics/e04-bilingual-ui/plan.md).

## Website

The bilingual landing page is dependency-free HTML/CSS/JavaScript in `site/`. It does not scan files or include analytics.
Its interface illustration uses sample data, not a real machine screenshot.

```bash
python3 -m http.server 8000 --directory site
node --test Scripts/test-site.mjs  # Node 22+ for website checks only
```

GitHub Actions verifies the native app, localization, bundle and website before deploying `site/` from `main` to GitHub Pages.
The live site is [vuluu2k.github.io/clean-mac](https://vuluu2k.github.io/clean-mac/).
Static files also work on another static host. No Vercel project is required.
Versioned downloads are GitHub Release assets, never committed app bundles. CI validates the Universal DMG before deploying the site.

## Contributing and license

Use Conventional Commits, add safety tests and run the full preflight before proposing changes.
See [open issues](https://github.com/vuluu2k/clean-mac/issues). Native tests never scan real user data or use native Trash.

[MIT](LICENSE). Free to use and modify. Provided as-is, without a guarantee against data loss.

## API references

- [FileManager.trashItem](https://developer.apple.com/documentation/foundation/filemanager/trashitem(at:resultingitemurl:))
- [NSWorkspace application lookup](https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication(withbundleidentifier:))
- [Apple: Full Disk Access](https://support.apple.com/guide/mac-help/change-privacy-security-settings-on-mac-mchl211c911f/mac)
- [Apple: Free up storage space](https://support.apple.com/en-us/102624)
