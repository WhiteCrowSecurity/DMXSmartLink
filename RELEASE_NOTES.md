# DMXSmartLink Release Notes

## 2026.04.21

### Installer / Updater

- `setup.sh` now survives GitHub API fallback cleanly by piping the release JSON into Python instead of accidentally treating JSON booleans like `false` as Python code.
- `setup.sh` and `upgrade_pi5.sh` now allow warning-only `unzip` exits when the expected release files were still extracted, which fixes installs on Debian/Ubuntu where the previous public zip triggered a backslash path-separator warning.
- Public `VERSION` files were updated to `2026.04.21` so installed systems show the installer fix date in the UI.

### Packaging

- `dmxsmartlink.zip` is rebuilt with forward-slash archive paths so Linux `unzip` no longer warns that the archive uses backslashes as path separators.

## 2026.04.19

### Update System

- `Update Now` now syncs the correct `dist_*` files, refreshes the Homebridge Docker container to the latest `homebridge/homebridge` image, updates the latest official Govee plugin, and then reboots.
- The released updater now resolves the extracted `dist_*` folder cleanly before syncing, so the full obfuscated payload copies into place instead of failing mid-update.
- The Homebridge plugin refresh path now prefers Homebridge's supported `hb-service add @homebridge-plugins/homebridge-govee@latest` flow, with an `npm` fallback only for older/non-standard containers.
- The Homebridge plugin refresh path now treats a failed install as a real update failure instead of silently continuing.
- Homebridge image refresh now normalizes `homebridge/homebridge` tags back to latest so old pinned tags do not block updates.
- The live updater now launches a separate user-level helper service, stops `dmxsmartlink.service` before copying obfuscated release files into place, and restarts only if the reboot path does not complete.

### Scenes

- Scene saves now capture the full live group and fixture target state instead of only the currently selected targets.
- Scene recalls now keep RGB and CT intent separate so CT scenes do not carry stale RGB tinting forward.
- Scene timing was refined so off-target groups can complete their final off transition more reliably after scene changes.
- The Pi5 build now applies Visual Control scenes in place, so users can trigger another scene immediately without manually refreshing the page.
- The Pi5 build now syncs shared selection and UI state between multiple browser sessions, so concurrent operators see scene/brightness changes settle onto the same live state.
- The Pi5 build also corrects the Visual Control power button icon rendering after the scene-sync changes.

### Homebridge / Govee

- DMXSmartLink is standardized on the official `@homebridge-plugins/homebridge-govee` plugin path.
- Public installer/setup scripts now force-refresh the official plugin during install/update using the supported Homebridge helper when available.

### Packaging

- All public Python application modules in this release are PyArmor-obfuscated.
- `VERSION` files were updated to `2026.04.19` so the dashboard update UI shows the new release date.
- Shipped `update_settings.json` files were reset so public packages do not include stale internal update timestamps.
