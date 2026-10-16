# Application uninstall and recommendation verification — 0.3.0

## Mechanical evidence

`uninstaller-preflight.log`: 46 tests, release build, Info.plist validation and ad-hoc signing passed for `dist/preview/clean-mac.app`. No dependencies were added. The original bundle in `dist/clean-mac.app` was not overwritten or terminated.

Coverage includes full app identity/bundle snapshots, app-first operation order, app move failure, per-file partial failure, running-state changes, changed descendants, forged IDs/plans, other copies/vendor families, Apple/system/self/out-of-scope protection and external symlinks. Model fixtures cover empty initial selection, filter intersection, immutable confirmation, stale-token rejection and an entire confirmed flow using a fake Trash directory.

## Native fixture UI

A temporary runner compiled the actual AppModel, Dashboard and application/recommendation views against the release core. All scan roots, running-state checks, registration lookup and Trash movement were injected. It contained one removable synthetic app, one protected Apple-ID app and synthetic data only.

Observed output:

```text
UI_READY mode=catalog apps=2 selected=0 confirmationFiles=0
UI_REVIEW canRemove=true related=6 recommended=1 review=2 keep=3 initiallySelected=0
UI_READY mode=confirmation apps=2 selected=1 confirmationFiles=1
UI_READY mode=results recommended=1 review=1 keep=1 selected=0
```

Visual checks:

- Catalog displays the protected app's reason and the explicit review button for the removable app.
- Related review shows the three recommendation levels, full paths, reasons, disabled protected-file checkboxes and no selected data.
- Confirmation contains the app plus the one deliberately selected cache file. Its acknowledgment is initially unchecked and the Trash button is disabled.
- Scan dashboard shows all three recommendation summaries and zero selected files. Logical inspected bytes are separate from retained result bytes.
- Screenshots: `/tmp/clean-mac-uninstall-{catalog,review,confirmation,results}.png` (temporary, not release assets).

The first temporary harness lacked the production AppDelegate/activation setup and presented too early; some instances had no window. Adding the same regular-activation delegate and waiting for parent presentation fixed the harness. PID detection must match the executable field, not the entire command suffix, because these fixtures have command-line arguments. Only PIDs with the unique temporary bundle path were closed.

## Not performed

No real application scan, native Trash operation, real uninstall, permission change, force quit, permanent deletion, commit or push. The old user app was not stopped by the agent. Real app/Put Back UAT, FDA, VoiceOver, light mode, macOS 14 and Intel remain pending.

VN/EN switching is an approved follow-up and is verified separately after implementation; these screenshots cover the Vietnamese UI before localization.
