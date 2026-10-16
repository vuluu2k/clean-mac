# Prebuilt macOS download — approved extension

The user requested a downloadable app like LidRun, not source instructions alone. This supersedes the source-only binary-release exclusion in the initial E05 plan.

## Prior art and choice

LidRun publishes a version/url/sha256 download manifest and an ad-hoc DMG. Its latest GitHub Release endpoint is absent; it uses an external CDN. For clean-mac, use versioned public GitHub Release assets instead of introducing a separate upload service.

## Deliverable

- `clean-mac-0.3.0-universal.dmg`, containing the app, an Applications shortcut and bilingual installation guidance.
- `SHA256SUMS` for integrity checking.
- GitHub Release `v0.3.0`, linked from the bilingual landing page and README pair.
- Clearly disclose ad-hoc signing, lack of Developer ID/notarization, manual macOS approval and unverified Intel hardware. Never instruct users to disable Gatekeeper/SIP or silently remove quarantine.

## Implementation and verification

Reuse build-app.sh into an isolated staging directory. Cross-build the other Mac architecture, combine with lipo, sign again and verify both architectures and signatures. Create the compressed DMG, mount read-only at a unique owned path, check contents, version, signature and architectures, then detach without force. Never run a real scan or uninstall, overwrite a running user bundle, commit binaries, or upload source credentials.

The app version does not change: packaging and the website do not change the native 0.3.0 feature set. Publish DMG/checksums as release assets, not in Git. The website must not claim notarization or complete real-data verification.
