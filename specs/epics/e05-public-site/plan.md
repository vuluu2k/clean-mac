# E05 — Public repository and open-source landing page

## Approval and outcome

The user approved a new public `vuluu2k/clean-mac` repository and GitHub Pages, then requested a downloadable app like LidRun. Publish source plus an explicitly ad-hoc Universal DMG as a GitHub Release asset. No notarization claim. Target URL: `https://vuluu2k.github.io/clean-mac/`.

## Scope

- Static `site/` HTML, CSS and small native JS modules. No runtime dependencies, accounts, analytics, forms or external fonts.
- Responsive English/Vietnamese presentation using the app's mint/dark identity, with accessible keyboard navigation and reduced-motion support.
- Explain actual scan/uninstall capabilities, read-only protection, Trash semantics and current verification limits. Interface illustration uses clearly labeled sample data, never private machine screenshots.
- Real source/build/license/download links. Include checksums and installation guidance. No false notarization, performance or complete-removal claims.
- GitHub Actions verifies Swift, localization, app bundle and site before deploying `site/` from main with pinned first-party Pages actions.
- Inspect all publication candidates for credentials, generated bundles, local logs and personal-machine evidence. Keep runtime app code unchanged.

## Git and deployment

GitHub CLI account and existing SSH authentication both identify vuluu2k. HTTPS token lacks workflow scope, so use the already-authorized SSH transport for Git pushes rather than requesting more token privileges. Never force-push.

Create the initial Conventional Commit on the current feature branch. Publish the verified commit as main in the new empty repository, create the version tag/release with reviewed DMG/checksum assets, enable Pages Actions and wait for checks/deployment. Never commit dist/. Preserve any running local app. Packaging details: `download.md`.

## Prior Art

- Existing app palette and README/SCOPE: extend brand and factual copy.
- Repo has no web framework or site to reuse. Build a static page with native HTML/CSS/modules instead of adding a framework.
- Installed bigpowers deploy/wire-ci guidance: compose validation/deployment gates. Swift has no bundled wire-ci template, so use an explicit minimal workflow.
- GitHub official custom Pages workflows: adopt configure-pages, upload-pages-artifact and deploy-pages with least permissions and full SHA pins.
- Existing Chrome and Node: use an isolated browser profile for responsive/interaction smoke without adding app/site dependencies.

## Verification

- Node assert tests for language keys, safe fallback, HTML links/assets and factual build/source CTAs.
- Isolated desktop/mobile Chrome smoke for layout overflow, language switching/persistence, keyboard focus and clipboard success/failure with a stubbed clipboard.
- Existing Swift tests and localization checks; separate app bundle only if needed, never overwrite a running bundle.
- Source/secret review before staging; workflow syntax and command dry-runs locally. Hosted macOS and Pages acceptance checked after push.
- Three independent deployment facts: valid local artifact, accepted GitHub deployment, live HTTPS page/assets and source/build links.
