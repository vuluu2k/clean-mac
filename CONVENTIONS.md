# clean-mac conventions

## Scope
- Build a local-first macOS 14+ SwiftUI app with SwiftPM and Apple frameworks.
- Support an in-app Vietnamese/English switch. Keep English code identifiers and persist only the explicit language preference locally.
- Localize UI literals and defer captured messages with LocalizedText. Never translate IDs/paths or use display text to decide eligibility.
- Pass the selected locale explicitly into sheets. Keep language changes from clearing selections, filters or scan snapshots.
- Keep dependencies empty. Keep scanning off the main actor.
- Store plans and verification evidence under `specs/`.
- Keep quick scans unchanged. Make deep startup-volume scans explicit and read-only outside narrow user-data allowlists.

## Data safety
- NEVER run cleanup during development against the user's data.
- NEVER use sudo, recursive deletion, shell cleanup commands, or permanent-delete fallbacks.
- Ordinary cleanup moves only explicitly selected, confirmed, unchanged regular files to macOS Trash.
- Reject symlinks, hard links, protected paths, packages, and changed scan snapshots during ordinary cleanup.
- A separate explicit uninstall intent may Trash a verified third-party .app bundle under /Applications or ~/Applications only. Recheck its complete bounded metadata tree, identity, scope and running state before moving.
- Never force quit or auto-uninstall. Protect Apple/system apps, clean-mac itself, shared data, containers, databases and services. Only exact-ID related regular files may be separately selected; no arbitrary directory deletion.
- Treat whole-volume, container, shared, service, and known database findings as read-only.
- Match suspected leftovers by exact reverse-DNS ownership, not friendly app names.
- Protect Apple IDs and installed application families. Missing applications never prove disuse.
- Rebuild application inventory and recheck LaunchServices before leftover cleanup.
- Fail closed when app inventory is incomplete. Never trust a UI read-only flag alone.
- Revalidate every item immediately before moving it. Report each failure.
- Never infer that old files are unused. Explain each rule and its uncertainty.
- Never report bytes moved to Trash as disk space already recovered.
- Do not empty Trash or modify system data, Keychain, cloud placeholders, or app databases.

## Verification
- Run `swift test` with temporary fixtures before release builds.
- Run `./Scripts/build-app.sh` to validate the release app bundle.
- Run `swift Scripts/check-localization.swift` for English key coverage and placeholder parity. Package both main-UI and core resource tables.
- Use injected Trash operations in automated tests. Never touch the real Trash in tests.
- Inject startup-volume roots and application lookup in deep-scan tests. Never traverse the real volume in tests.
- Keep reproducible test and build failures blocking. Fix them or record a blocking issue.
- Do not dismiss failures as pre-existing or unrelated.
- Test cancellation, path boundaries, file changes, selection, and partial failures.

## Git
- Use Conventional Commits: `feat:`, `fix:`, `test:`, `docs:`, `chore:`.
- Work on a feature branch. Do not commit, push, or create a remote without user approval.
