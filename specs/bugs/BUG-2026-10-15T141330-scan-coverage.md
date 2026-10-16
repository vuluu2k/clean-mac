# BUG-2026-10-15T141330: Deep scanning looks empty and misses heavy small-file folders

## Problem

The user reports very little visible scan coverage. Expected: visible progress/results during scanning and discovery of large folders composed of small files.
Security impact: NONE. No security exploit path identified. Cleanup permissions must remain unchanged.

## Root Cause Analysis

### Reproduce

The user's already-running Deep scan showed over 335,000 checked files and 20,003 temporary candidates while the dashboard cards remained empty. The agent observed the existing app only; it did not start, stop or clean a real-data scan.
An isolated-volume fixture with twelve 9 MB files reports all twelve visited but zero findings. Their containing folder occupies 108 MB logically.
Verify: `swift test --filter smallFilesAreTraversedButTheirLargeFolderIsCurrentlyInvisible` exited 0 before the fix.

### Isolate

Traversal and result display use different state. Only progress counters update during scanning; result state is assigned after the complete scan.
Deep file analysis requires each individual file to reach 100 MB. It has no aggregate directory analysis.
Final UI shows the number of findings, not persistent scanned-file/byte/directory counts. A result cap stores early matches rather than guaranteeing the largest retained files.

### Hypothesize

1. Traversal stopped early: falsified for the observed app, which was actively processing hundreds of thousands of files.
2. Wrong scan mode: falsified by the observed Deep-mode selector and active system-path progress.
3. Display/filtering hides real work: verified by the live empty cards, source data flow, and small-file fixture.
4. Permissions can reduce actual coverage: remains a separate possibility, not an excuse or established cause for this observation.

### Verify

The confirmed defect is delayed result publication plus per-file-only eligibility without folder aggregates. This is a missing capability/UX defect, not evidence that the whole startup volume is fully readable.
Risk: Medium. Report and UI contracts change, but cleanup scope does not expand.

## TDD Fix Plan

1. RED: twelve sub-threshold files must produce a 108 MB read-only folder summary and persistent coverage totals.
   GREEN: aggregate logical sizes while traversing accessible files, with bounded depth/count and explicit nested-folder semantics.
   verify: `swift test --filter largeFolderOfSmallFilesIsVisibleInCoverage`
2. RED: report snapshots must arrive before final completion and carry scan counters separately from findings.
   GREEN: publish throttled immutable previews, preserve final counters, keep selection disabled while scanning.
   verify: `swift test --filter liveScanSnapshotsArriveBeforeCompletion`
3. RED: a late larger file must survive bounded result collection.
   GREEN: retain largest candidates with bounded batched pruning; expose a 10 MB deep file threshold without changing Quick rules.
   verify: `swift test --filter boundedResultsKeepLateLargeFiles`
4. RED: live/canceled previews must not enable unsafe cleanup or stale-state confirmation.
   GREEN: retain busy/confirmation guards and read-only folder rows; add visible partial/cap/error messaging.
   verify: `swift test`

## Acceptance Criteria

- [x] Show live previews and final scanned-file/directory/logical-byte totals.
- [x] Show heavy folders built from small files, without allowing folder deletion.
- [x] Keep final file results bounded and sorted by actual retained size.
- [x] Keep existing cleanup protections and confirmation tests passing.
- [x] Build a separate validation bundle without replacing the user's active app/scan.

## Resolution

Fixed in source and verified on 2026-10-15. Root cause confirmed: end-only result publication and individual-file-only filtering hid real traversal work and aggregate folder usage.
Both selectable modes now deliver bounded live snapshots. Deep analysis starts at 10 MB and aggregates small-file folder usage separately. Folder results are a read-only type, not cleanup capabilities. Active-scan guards reject stale previews; existing busy guards still block confirmation while scanning.

Evidence: 30 passing tests and the separate 0.2.1 release bundle in `specs/verifications/coverage-preflight.log`. Native fixture UI proof, including a pre-completion screenshot, is recorded in `specs/verifications/coverage-behavior.md`. Both public user-selectable scanner entrypoints were swept; the generalization artifact validator passed.
The original user's app/scan was preserved. Real-volume duration, permissions and native Trash remain manual checks. No commit was created, per user policy.
Suggested commit only: `fix: show live scan coverage and large folder totals`.
