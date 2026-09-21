# Scenes, shows and controllers

This guide describes features shipped in **2026.09.21.1444**. Some connector package READMEs still describe their beta introduction; use the downloads bundled with your Hub release and retain their platform, pairing and hardware-validation cautions.

## Scenes capture a lighting look

Saving a scene captures the rig, not just the lights currently selected in Visual Control. Off states matter too. Smart-light values come from the configured Homebridge or Home Assistant accessories. The Hub retains color-mode evidence so an RGB look and a temperature look can be distinguished.

1. Set your lights to the desired look and let the provider finish reporting the changes.
2. In **Visual Control**, choose **Save scene**, enter its name and save.
3. Review any incomplete-state warning. If a light or its active color mode cannot be read reliably, check that device in its provider and save again after resolving the problem.
4. Recall another scene, then return to the new scene and check the result on your actual lights.

Recall applies differences rather than resending every value. If a group overlaps individual lights, the individual saved light states take priority. Selection in the editor is for manual control; it does not define what a whole-rig scene contains.

Provider state is not independent physical feedback. A disconnected lamp or provider delay can still need investigation. Do not suppress an incomplete-state warning simply to make a scene appear complete.

## Saved show setups are different from scenes

A scene stores a lighting look. A named **AI Light Show, AI Slideshow or NDI setup** stores reusable show configuration. Save and load setups in the relevant show UI; confirm the target lights, source and other resources are available before starting.

- **AI Light Show:** choose the target fixtures/groups and an audio input. With an NDI source, confirm the sender includes audio and check input activity/BPM before judging lighting output.
- **AI Slideshow:** prepare images and an ordered playlist, configure targets and save the setup. Source files must still be available when loaded later.
- **NDI video:** choose a reachable source and target lights. A source's presence does not guarantee it carries audio as well as video.

Use **Stop** before handing control back to a saved lighting scene. The release includes Stop/recall and color-temperature handoff improvements; verify the sequence with your devices.

## Visual Control

- Tap or click a light to select it. Hold, then drag across the canvas to box-select; desktop Shift-drag remains available.
- Drag a fixture to position it, drag the background to pan, and pinch or scroll to zoom.
- Brightness and mixed-state indicators help distinguish a uniform selection from lights with different states. Controls depend on the capabilities available for the selected lights.
- Manual changes should affect only the selected targets. If an unselected light changes, report the overlapping group membership and the exact control used.

## Stream Deck and MIDI

Download the appropriate package from **Settings** or the [release assets](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest). These are separate ways to control the Hub:

| Package | Purpose and scope |
|---|---|
| `DMXSmartLink-StreamDeck-Windows.zip` / `-macOS.zip` | Standalone DMXSmartLink USB Stream Deck remote app. Follow its included README. |
| `DMXSmartLink-Elgato-Windows.zip` / `-macOS.zip` | Plugin for the Elgato Stream Deck application. Includes scene recall and AI Light Show/Slideshow Start/Stop. Requires Stream Deck 6.9 or later. |
| `DMXSmartLink-MIDI-Windows.zip` / `-macOS.zip` | Connect a MIDI controller to a computer and send supported scene actions to the Hub over a trusted local network. |

### Elgato plugin

Unzip the package and open the included `.streamDeckPlugin` file. Keep Elgato's app running. Do not run the standalone USB remote app against the same deck at the same time.

Enter the Hub address and verify its certificate fingerprint as the plugin instructs. For **Recall scene**, load the scene list, choose the scene and save. Show Start/Stop actions use the targets configured on the Hub. **Do not assume named show setups automatically appear in the scene dropdown**: configure/load the intended setup in the Hub before using Start.

Windows is x64 and the current Windows plugin is unsigned; Mac downloads target Apple silicon. Installed-plugin and physical-controller validation remains separate from package and protocol checks.

### MIDI over IP

1. In **Settings → MIDI controller**, generate a pairing key.
2. Open the MIDI Connector on your Windows x64 PC or Apple silicon Mac. Enter the Hub HTTPS address, pairing key and verified certificate fingerprint.
3. Connect your MIDI controller, refresh inputs, select it and connect.
4. Enable MIDI input and configure the note base, channel and scene-step CC mappings on the Hub.

Supported actions are mapped note-on scene recall and next/previous scene buttons. **The network connector does not implement a master-brightness fader**, or forward Program Change, SysEx, MIDI clock or MIDI output. Direct USB MIDI is a separate path; do not assume its mappings all work over the network connector.

Only one network MIDI connector can be active per Hub. Pairing keys must be entered again after the connector restarts. After a disconnect, sleep or Hub restart, wait for Connected and press controls again; stale queued actions are discarded rather than replayed.

## Updates and testing

Use Stable/Latest for the official release and Test (pre-release) for deliberate beta testing. See [Update the hub](SOP-UPDATE-THE-HUB.md). Export a backup before updating and check scene transitions, provider state, controller actions and NDI input before a service or show.

The intermittent fixture LCD/display flashing report remains under investigation. Report remaining problems with version, platform, device model and reproduction steps through [Discord](https://discord.gg/pj6f54dpv7) or **support@dmxsmartlink.com**. Do not include pairing keys, provider tokens or account passwords.
