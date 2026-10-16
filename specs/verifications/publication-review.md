---
type: source-self-review
context: Initial public repository, bilingual landing and Universal DMG
---

# Publication self-review

- PASS — Correctness: 49 Swift tests, 211 localization keys, six website checks and real-browser smoke pass. Current native app sources are unchanged by the website/package work.
- PASS — Website: both languages, metadata, controls, storage fallback, clipboard denial, project-prefix assets, native FAQ, reduced motion and named interactive elements were exercised. No browser errors or missing resources.
- PASS — Packaging: arm64/x86_64 code targets macOS 14.0. App signature, read-only DMG layout, version, Applications link, image integrity and checksum pass. The builder refuses existing release output.
- PASS — Privacy: no external website scripts/fonts, analytics, forms or browser file access. Artwork uses labeled sample data. Known credential patterns, generated binaries and personal-machine paths are absent from publication candidates.
- PASS — Permissions: only the main deployment job gets Pages/OIDC writes. Pull requests have read-only contents permissions. First-party actions are pinned to verified full SHAs. No pull_request_target or custom credential secrets.
- PASS — Safety: no native scans, cleanup, security-setting changes, permanent deletion or forced detach. Packaging uses owned staging paths and a read-only image mount. No running user bundle is overwritten.
- PASS — Supply chain: no runtime dependencies added. Existing platform tools, native browser and standard Node modules provide implementation and verification.
- PASS — Claims: no notarization, complete-removal, speedup, garbage-size or zero-risk promises. The landing links to source, installation guidance and checksums.
- PASS — Scope: public GitHub source, GitHub Pages and downloadable release were explicitly approved. Vercel/CDN services and automatic binary-release updates were not introduced.

## Honest limits

This is self-review, not an independent audit. act/actionlint are not installed; workflow YAML and underlying commands are checked locally, and hosted jobs are inspected after push. Safari, VoiceOver, Intel hardware, downloaded Gatekeeper behavior and real-data native Trash/UAT remain manual.

The initial repository contains the previously verified native app, so there is no historical merge base for churn analysis. Stylesheets and the existing view model are not split solely to satisfy a generic line-count preference. Project conventions take precedence over unrelated generic skill checklists.

Verify:

```sh
swift test
swift Scripts/check-localization.swift
node --test Scripts/test-site.mjs
bash -n Scripts/build-app.sh Scripts/build-dmg.sh Scripts/run-app.sh
(cd dist/releases && shasum -a 256 -c SHA256SUMS)
```

Hosted acceptance and live page/download checks occur after this readiness snapshot. No binaries, local logs, browser profiles or private screenshots belong in Git.
