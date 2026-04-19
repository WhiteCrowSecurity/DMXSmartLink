# DMXSmartLink Release Notes

## 2026.04.19

### Update System

- `Update Now` now syncs the correct `dist_*` files, refreshes the Homebridge Docker container to the latest `homebridge/homebridge` image, updates the official `homebridge-plugins/homebridge-govee#latest` plugin, and then reboots.
- The Homebridge plugin refresh path now treats a failed `npm install` as a real update failure instead of silently continuing.
- Homebridge image refresh now normalizes `homebridge/homebridge` tags back to latest so old pinned tags do not block updates.

### Scenes

- Scene saves now capture the full live group and fixture target state instead of only the currently selected targets.
- Scene recalls now keep RGB and CT intent separate so CT scenes do not carry stale RGB tinting forward.
- Scene timing was refined so off-target groups can complete their final off transition more reliably after scene changes.

### Homebridge / Govee

- DMXSmartLink is standardized on the official `homebridge-plugins/homebridge-govee` plugin path.
- Public installer/setup scripts now force-refresh the official plugin during install/update instead of quietly leaving older plugin state in place.

### Packaging

- All public Python application modules in this release are PyArmor-obfuscated.
- `VERSION` files were updated to `2026.04.19` so the dashboard update UI shows the new release date.
- Shipped `update_settings.json` files were reset so public packages do not include stale internal update timestamps.
