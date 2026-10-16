# E01 — Explainable native cleanup

## Implementation slices

1. Scan old cache files in an isolated home, without mutations. Test freshness boundaries and unrelated paths.
2. Add categories and review folders. Test symlink, hard-link, package, hidden, and protected-path rejection.
3. Add Trash validation. Test unchanged selection, changed identity, path replacement, duplicates, and partial failure.
4. Add asynchronous state and native dashboard. No preselected files. Confirm a captured file list before cleanup.
5. Package the app, document safe use, run all tests and release build.

## Acceptance

- All scan activity is read-only and cancellable.
- Age is an explainable heuristic, not proof of disuse.
- Each moved file was explicitly selected and confirmed.
- Changed, protected, replaced, or missing files fail closed.
- Failed Trash calls do not invoke a fallback deletion.
- The dashboard never presents moved bytes as reclaimed space.

## Manual verification

1. Run `./Scripts/run-app.sh`.
2. Click scan. Cancel and verify the app remains responsive.
3. Scan again. Inspect category counts, paths, reasons, permission warnings, and disk capacity.
4. Create a disposable file larger than 100 MB in a disposable home subfolder. Add that folder.
5. Select only that file. Check its full path in the confirmation sheet.
6. Cancel once. Verify the file remains untouched.
7. Confirm once. Verify the file is in Finder Trash and use Put Back.
8. Verify available capacity does not claim a gain merely because the file moved.

Verify: `swift test && ./Scripts/build-app.sh`.
