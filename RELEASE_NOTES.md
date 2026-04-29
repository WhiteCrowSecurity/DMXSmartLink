# DMXSmartLink Release Notes

## 2026.04.29

### Pi5 Service Reliability

- Refreshed the Pi5 public payload from a new `linux.aarch64` PyArmor build.
- Hardened the embedded HTTPS app server so slow or abandoned TLS clients cannot stall the port `5000` accept loop.
- Added threaded request handling, a per-connection timeout, and a local health watchdog so `systemd` can restart `dmxsmartlink.service` if the web UI stops answering.
- Updated the Pi5 public `VERSION` file to `2026.04.29` so installed hubs detect this release through `Update Now`.
- Intel and M4 compiled application payloads were not rebuilt for this release and remain unchanged.

## 2026.04.25

### iPhone App / UI

- Replaced native browser popups in the DMXSmartLink hub UI with in-app dialogs so confirmation, prompt, and alert flows work reliably in iPhone app WebView sessions.
- Added iPhone-focused popup handling for common hub workflows, including confirm, prompt, and alert actions that previously depended on native browser dialogs.
- Hardened dashboard, media, and UI state guards so disconnected or partial state responses do not break visible controls.
- Improved mobile layout behavior across the app so cards, buttons, forms, and status rows wrap instead of overflowing on smaller iPhone screens.
- Removed the AI Slide Show shortcut from the main dashboard; the dashboard now keeps the existing Visual Control entry only.

### AI Slide Show

- Added a standalone AI Slide Show page separate from AI Light Show (Audio Reactive), so image slideshows can be operated independently from audio-reactive lighting.
- Added slide image upload support for JPG, PNG, and WebP files.
- Added both automatic timed playback and manual Previous/Next controls so operators can let slides advance on a timer or take over pacing live.
- Added a fullscreen slide screen designed for presentation use, with in-page fullscreen behavior that works better inside iPhone app WebView sessions.
- Added slide thumbnail management controls, including per-slide navigation, reorder controls, and removal.
- Added lighting target selection so slideshow-driven lighting can be aimed at selected fixture and group targets.

### DMX Fixtures

- Fixed responsive overflow in the DMX fixture editor so channel rows, advanced capability rows, output selectors, and action buttons stay inside their cards on iPhone-sized screens.
- Improved wrapping for long fixture/channel labels and compact action buttons so the fixture editor remains usable on mobile without horizontal scrolling.

### Visual Control

- Added per-client Visual Control ownership and epoch handling so a stale session cannot continue overriding a newer scene, brightness, effect, or power action selected from another device.
- Multi-user scene changes now return explicit stale-control feedback to older sessions instead of silently losing the newer operator's changes.
- Improved multi-user scene and visual control behavior so a newer operator's changes can take effect even when another browser or iPhone session is already connected.

### Packaging

- Refreshed the Pi5 public payload from the latest 2026.04.25 PyArmor build.
- Intel and M4 compiled application payloads were not rebuilt for this release and remain unchanged.
- Public Python application modules remain PyArmor-obfuscated; raw private source was not published.
- Rebuilt `dmxsmartlink.zip` with only the approved `dist_pi5/`, `dist_ubuntu_intel/`, and `dist_ubuntu_m4/` folders at the zip root.
- Validated the live public release on the smoke-test Pi through the `Update Now` path, including file sync, dependency refresh, Homebridge/Govee refresh, reboot, service return, and route checks.

## 2026.04.22

### Updater

- `Update Now` now launches a root-owned updater helper installed by `setup.sh` instead of starting a second obfuscated Python worker from the live app process.
- Public `setup.sh` now installs `/usr/local/sbin/dmxsmartlink-update-launcher` and `/usr/local/sbin/dmxsmartlink-root-update`, and grants passwordless sudo only for the launcher path.
- The root helper starts the real update job in a transient `systemd-run` unit, stops `dmxsmartlink.service` before replacing obfuscated files, refreshes Homebridge plus the official Govee plugin, and now reboots the system on a successful update. Service restart remains only as a fallback if reboot cannot be triggered.
- The launcher and worker now carry the install user and target paths explicitly, which fixes fresh Pi5 installs where the updater previously inferred the wrong home directory under `systemd-run`.
- This updater flow was validated on the fresh Pi5 at `192.168.1.159`, including a full `Update Now` run that stopped the service, synced the public release, refreshed Homebridge/plugin state, and returned the UI to `200 OK`.

### Packaging

- The Pi5 public payload is refreshed from the validated `V19` obfuscated build.
- Intel and M4 compiled application modules were not recompiled for this respin; only their release-facing `setup.sh` and `upgrade_pi5.sh` scripts were refreshed.

### Reboot

- `setup.sh` now restores a narrow passwordless sudo rule for the OS reboot command, so the dashboard `Reboot OS` button works again after install.
- The Pi5 updater also self-heals that reboot sudoers file during a successful update, so the reboot button stays functional after moving onto this release.

## 2026.04.21

### Installer / Updater

- `setup.sh` now survives GitHub API fallback cleanly by piping the release JSON into Python instead of accidentally treating JSON booleans like `false` as Python code.
- `setup.sh` and `upgrade_pi5.sh` now allow warning-only `unzip` exits when the expected release files were still extracted, which fixes installs on Debian/Ubuntu where the previous public zip triggered a backslash path-separator warning.
- The Pi5 build now launches the built-in update worker through a transient `systemd-run` unit and checks only the specific passwordless sudo commands the updater actually needs, so `Update Now` no longer depends on a broad `sudo -n true` or `sudo bash` allowance.
- Public `setup.sh` now provisions passwordless sudo for `/usr/bin/systemd-run` alongside the updater's existing `apt-get` and `reboot` commands.
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
