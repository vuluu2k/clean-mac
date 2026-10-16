# E03 — Application uninstall and explainable recommendations

User approval: “Thêm vào đi” authorizes this feature and recommendation filters, not removal of real data during development. Keep all commits/pushes unperformed.

## Scope and safety decisions

- Add a separate Gỡ ứng dụng page with explicit application inventory scan and search.
- Review ordinary third-party .app bundles under /Applications or ~/Applications, including ordinary nested folders. System, Apple IDs, clean-mac itself, symlinked/unknown app metadata and portable apps elsewhere remain read-only.
- Never force quit. A running app (same path or ID) blocks uninstall. Check again immediately before Trash.
- Capture and recheck the complete bounded bundle metadata tree, including symlink entries without following them. Changed descendants, unreadable/dataless entries, cancellation or limits block bundle removal.
- Related-data review uses exact bundle IDs in existing Library locations. Ordinary user-Library files can be explicitly selected. Containers, databases, launch services, system/shared locations and data potentially shared with another installed vendor-family app remain read-only.
- The app bundle is the only directory exception. Ordinary file cleanup remains file-only. Never move arbitrary data directories, helpers or scripts.
- Capture confirmation with application identity, paths, selected files, byte totals and explicit acknowledgment. Move the app first; if that fails, do not touch its data. Report later per-file failures without fallback.
- Recheck other installed/registered app copies before data cleanup. Absence and bundle-ID matching do not prove exclusive ownership or complete coverage.
- Post-scan levels: Khuyên dọn (old regenerable cache/log/build, with caveats), Cần xem lại (installers/large/uncertain user data), Không nên xóa (locked findings). No auto-selection or “safe garbage” guarantees.

## TDD slices

1. Retain application records without changing inventory ownership protection. Verify existing app inventory/leftover tests.
2. List and review a fixture app with full bundle snapshot and exact related files. Protect system/running/self/shared data.
3. Fail closed on changed descendants, forged selection, reinstalled copies and app Trash failure. Verify explicit app-first fake-Trash flow and related-file partial failures.
4. Add computed recommendation behavior and filters; preserve no-selection/captured-confirmation guards.
5. Native UI pages, related review and separate confirmation; fixture visual smoke and separate bundle build.

## Verification

`swift test && CLEAN_MAC_APP_PATH="$PWD/dist/preview/clean-mac.app" ./Scripts/build-app.sh`
No production scans or Trash operations during implementation. Validate native UI with injected disposable Home/startup-volume roots. Keep the user's running original app untouched.

## Manual follow-up

Real third-party app uninstall/Put Back requires user approval and a disposable app. FDA, macOS 14/Intel, VoiceOver and helper/installer-specific uninstall behavior remain manual. Vendor uninstallers may still be required for drivers, extensions and daemons.
