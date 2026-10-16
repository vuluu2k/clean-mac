# Coverage behavior evidence — 0.2.1

## Reproduced failure

The existing user-started Deep scan displayed more than 335,000 inspected files while category cards were still empty. No real scan was started or interrupted by the agent.
Before implementation, a fixture of twelve 9 MB files produced twelve visits and zero findings; the 108 MB containing folder was absent.
RED tests then failed for missing aggregates, omitted live callbacks and retention of early smaller files instead of late larger files.

## Automated proof

`specs/verifications/coverage-preflight.log` records the final contiguous 30-test run and separate release build.
The live-preview test cancels from the first non-empty snapshot and verifies that traversal stopped before all 450 fixture files were inspected. Both selectable modes pass this test.
Folder aggregates exclude credential paths, external volumes and duplicate APFS paths. Folder IDs never enter confirmation.

## Native UI proof on disposable fixtures

Compiled a temporary SwiftUI runner from the actual AppModel/dashboard sources and the release CleanMacCore objects, with an injected temporary Home/startup volume and fake application lookup. No production debug launch mode was added.

Initial fixture output:

```text
DEMO_RESULT files=12 bytes=108000000 leafBytes=108000000 leafFiles=12 canTrashFolder=false selected=0
```

Final screenshot: `/tmp/clean-mac-coverage-fixture.png`.
The dashboard shows 108 MB scanned logical data, twelve file inspections, folder analysis, zero file candidates and disabled cleanup. The absence of individual large files no longer hides the containing folder's size.

A second fixture adds a one-byte synthetic preference and delays its fake application lookup. During this delay, the still-running scan visibly shows 108 MB, thirteen inspections, partial-result messaging and disabled cleanup.
Live screenshot: `/tmp/clean-mac-coverage-fixture-live.png`.

After completion:

```text
DEMO_RESULT files=13 bytes=108000001 leafBytes=108000000 leafFiles=12 canTrashFolder=false selected=0
```

## Release smoke and preservation

The actual ad-hoc signed release bundle at `dist/preview/clean-mac.app` launches idle as version 0.2.1. Screenshot: `/tmp/clean-mac-coverage-preview-idle.png`.
Only agent-owned idle/demo processes were closed. The user's original version 0.2.0 bundle and process were preserved; its scan was not stopped, replaced or restarted.

Temporary screenshots and the fixture runner live outside the repo and can expire. Real whole-volume duration, permissions, cloud-provider behavior and native Trash remain unverified. No permanent deletion or real-data cleanup was performed.
