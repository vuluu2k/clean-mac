# Public source and bilingual landing — 0.3.0

## Target

Publish the existing native app and a new static introduction at vuluu2k/clean-mac with GitHub Pages. User explicitly approved public visibility and Pages.

## Dependents

- `site/`: new isolated website. No callers from app runtime modules.
- README pair, project scope/conventions and CLAUDE commands: source/site/build links and publication instructions.
- `.github/workflows/`: Swift/localization/app/site checks, then main-only Pages deployment.
- `.gitignore` and initial Git publication: generated bundles, build caches, local logs, screenshots and secrets must stay private/untracked.
- Download extension: Scripts/build-dmg.sh, INSTALL.md, native version-linked landing CTAs and GitHub Release assets. Cross-build both architectures, sign the app ad-hoc, validate a read-only DMG mount and checksum. No notarization claim.
- Public claims must remain consistent with `Sources/`, SCOPE and verification evidence. No synthetic data presented as a real scan.

## Affected stories

E01–E04 remain the native app regression baseline. E05 adds public source and static marketing/documentation, not a cleanup capability.

## Test coverage

49 Swift tests and the compiler-based localization check remain required. Add Node site assertions and isolated real-browser interaction/responsive checks. Validate workflow YAML, pin first-party actions, and inspect hosted checks/deployment after push.

## Risk: Medium

The website does not touch user files. Public Git history and workflow permissions are the main risks: inspect candidates before staging, use least privileges and never commit local logs or artifacts. Keep live app bundles untouched.

## Recommended action

Build a dependency-free static site, test both languages and layout sizes, then commit/push only reviewed source to the newly approved repository. The user additionally approved a prebuilt download like LidRun: publish the reviewed Universal DMG and checksums as GitHub Release assets, never in Git. Deploy main through GitHub Pages and verify the page and binary download. Do not create a Vercel project.
