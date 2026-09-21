# DMXSmartLink Hub

**Bring DMX fixtures and smart lighting together — from a lighting console, your browser, or an audio-reactive show.**

DMXSmartLink combines visual lighting control, whole-rig scenes, AI Light Shows, presentation/video-driven lighting, and physical controller integrations. Use it for churches, theaters, live events, studios, gyms, venues, or smart-home lighting. Choose the capabilities your setup needs and start with a single light.

[Shop and product information](https://dmxsmartlink.com) · [Download Latest](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest) · [Documentation](docs/README.md) · [Video tutorials](https://www.youtube.com/@WhiteCrowSecurity) · [Discord](https://discord.gg/pj6f54dpv7)

## What's new in 2026.09.21.1444

- **Whole-rig scenes:** capture lights and fixtures regardless of selection, including off states, using Homebridge or Home Assistant accessory state for smart lights.
- **Difference-only recall:** apply the values that need changing, with individual-light priority where groups overlap.
- **Selected-light controls:** improved selection scope and Govee RGB/color-temperature switching, including returning to a previously used color.
- **Easier Visual Control:** hold and drag to select on desktop or touchscreens; clearer brightness and mixed-state indicators, Help layout, and mobile update controls.
- **Saved AI Light Show, Slideshow and NDI setups**, with slideshow playlists and resource checks before starting output.
- **NDI input/audio fixes** and Windows/macOS **MIDI-over-IP and Stream Deck downloads** in Settings.
- **16,827 bundled fixture profiles**, including **34 additions** in this release batch.

Read the [release notes](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/tag/DMXSmartLink-v2026.09.21.1444) and [feature guide](docs/FEATURES.md) for behavior, setup and limitations.

## What you can control

| Capability | What it does |
|---|---|
| DMX and smart lights | Bridge supported smart lights through **Homebridge and Home Assistant**, alongside patched DMX fixtures. Available controls depend on the device and integration. |
| Console input | Receive Art-Net, sACN, or supported USB DMX input and route it through your configured patch. |
| Fixture output | Control DMX fixtures through supported USB DMX interfaces or network output. USB input and output capabilities depend on the adapter. |
| Visual Control | Arrange your rig on a map; adjust brightness, color, temperature, pan/tilt and fixture-specific controls. |
| Scenes and groups | Save complete looks, recall changes, and organize lights. Overlapping groups must not override an individual light's saved state. |
| AI Light Show | Audio-reactive lighting using selected fixtures/groups and supported audio inputs, including NDI audio. |
| AI Slideshow and NDI video | Drive lighting from images, presentations or a network video source; save reusable setups. |
| Media, Favorites and Follow Spot | Work with media, keep frequent controls handy, and steer supported moving fixtures. |
| Stream Deck and MIDI | Trigger supported scene/show actions using the appropriate connector or plugin. See [controller choices](docs/FEATURES.md#stream-deck-and-midi). |
| Fixture library and CSV import | Find fixture profiles, import supported patch CSVs and check channel mappings against the actual fixture mode. |
| Backup and diagnostics | Export your configuration and inspect network logs when troubleshooting. |

### Preserve your patch

When one external USB DMX input is intentionally reused across multiple universes, keep the assigned channel ranges non-overlapping across that fanout. Independent network universes are a different case. Do not renumber a working patch just to copy an example.

Smart-light status comes from the configured Homebridge or Home Assistant provider. A provider's reported state is not an independent measurement of a physical lamp. Ordinary DMX fixtures may have no physical readback.

## Choose your platform

| Platform | Current release |
|---|---|
| Raspberry Pi 5 | ARM64 package; a useful dedicated hub for permanent installations. |
| Ubuntu | x86-64 package for a supported PC or VM. |
| Windows | x64 installer; this release was installation/runtime tested on Windows 11. |
| macOS | Apple silicon package; this release was installation/runtime tested on an M4 Mac. The current package is not an Intel Mac build. |

For Linux, plan for at least 2 CPU cores and 4 GB RAM, plus free storage for the application, media and updates. A licence is required for licensed lighting operation. Smart-device compatibility depends on your Homebridge plugins or Home Assistant integrations; not every consumer bulb exposes every feature.

## Install

### Windows and macOS

1. Download the [Windows installer](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/DMXSmartLink-Setup.exe) or [Apple silicon Mac package](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/DMXSmartLink-Installer.pkg).
2. Run the installer and follow its prompts.
3. Open DMXSmartLink. For access from another device on your local network, open `https://<hub-address>:5000`.
4. Enter your licence and configure your smart-light provider in Settings.

### Raspberry Pi 5 and Ubuntu

On a supported 64-bit system, run from the intended user's home directory:

```bash
cd ~ && curl -fsSL https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/setup.sh -o setup.sh && sudo bash setup.sh
```

The setup script selects the platform package. Allow installation to finish, then open `https://<hub-address>:5000`. See the [installation guide](docs/SOP-INSTALL.md) for provider setup and troubleshooting.

### Homebridge and Home Assistant

- **Homebridge:** configure the bundled integration and the relevant vendor plugin, then check the light in Homebridge **Accessories**. Keep the bundled Govee integration version unless the release instructions say otherwise.
- **Home Assistant:** enable its integration in Hub Settings and configure the host, port and access token for your Home Assistant instance. Confirm the light is available in that instance before importing it.
- Refresh the device inventory after provider setup, then test one light before adding the rest of your rig. Never share provider tokens in support posts or screenshots.

## Update an existing hub

1. [Export a backup](docs/SOP-BACKUP-AND-RESTORE.md).
2. Open **Dashboard → Updates** and choose **Stable/Latest**. Beta users can switch back to Stable for this release.
3. Select **Check for Updates**, then **Update Now**. Allow the application to close/restart when required.
4. Confirm the installed version, then test your saved scenes and connected controllers before an event.

For beta testing, enable **Developer mode** and select **Test (pre-release)**. The release tag shown in the UI identifies the package that channel will install. Keep production rigs on Stable unless you deliberately choose to test a candidate.

If an update fails, retain the updater log and follow the [update guide](docs/SOP-UPDATE-THE-HUB.md). Desktop installers are also available directly from [Latest](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest).

## Validation and known limitations

The 2026.09.21.1444 release passed installation/native runtime checks on Pi, Ubuntu, Windows and macOS; Windows reinstall data preservation, NDI audio and responsive UI checks also passed. This does not certify every fixture, provider, controller or venue. Native desktop GUI lifecycle coverage remains limited.

The intermittent fixture-display flashing report remains under investigation and is **not claimed fixed**. Check the release notes and test scenes, transitions, brightness and color temperature on your actual hardware before an event.

## Photosensitivity and show safety

Lighting effects can produce flashing and strobing that may trigger seizures or other adverse effects. Validate effects before using them with an audience, provide appropriate warnings, and keep a way to stop output readily available. The hub cannot determine how every physical fixture will respond to its commands.

## Help and support

- [Documentation and operating guides](docs/README.md)
- [YouTube tutorials](https://www.youtube.com/@WhiteCrowSecurity)
- [Discord community](https://discord.gg/pj6f54dpv7)
- Email: **support@dmxsmartlink.com**

When reporting a problem, include the installed version, platform, fixture/device model, provider and steps to reproduce. Remove credentials and private information from logs.

This public repository distributes software builds and customer documentation. Application source is maintained privately. Audio-reactive features use audio analysis and project-specific show-control logic.

© White Crow Security / DMXSmartLink
