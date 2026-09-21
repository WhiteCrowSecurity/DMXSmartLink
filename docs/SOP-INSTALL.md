# Install DMXSmartLink Hub

Use the [Latest release](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest) for a production installation. The current packages cover Raspberry Pi 5 ARM64, Ubuntu x86-64, Windows x64 and Apple silicon macOS. The current Mac package is not an Intel Mac build.

## Before you start

Use a supported system with adequate free storage for installation, media and future updates. For Linux, plan for at least 2 CPU cores and 4 GB RAM. Internet access is needed to download the package and required setup components.

A USB DMX adapter is needed only for a USB DMX connection. Network DMX output uses compatible network devices; smart lights use their configured provider. Check the specific adapter's input/output capabilities before buying it.

Reserve the Hub's local IP address on your router so phones and controllers can find it consistently. Export a backup before replacing an existing installation.

## Windows

1. Download [DMXSmartLink-Setup.exe](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/DMXSmartLink-Setup.exe).
2. Run the installer and follow its prompts. It includes the application and bundled Homebridge components.
3. Launch DMXSmartLink from its shortcut. Enter your licence and configure the provider in Settings.
4. For access from a phone or another computer, use `https://<pc-address>:5000` on your local network. Use the installed firewall rules for Hub access.

This release's installer, installed backend and same-version reinstall were tested on Windows 11. Export your settings before uninstalling; uninstall is not an update procedure.

## macOS

1. Download the [Apple silicon installer package](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/DMXSmartLink-Installer.pkg).
2. Run the installer and follow its prompts.
3. Open DMXSmartLink from Applications, enter your licence and configure the provider in Settings.
4. Other devices on your local network can access `https://<mac-address>:5000`.

This release was installed and its native backend tested on an M4 Mac. Verify that a download matches your Mac architecture; do not use this package as an Intel build.

## Raspberry Pi 5 or Ubuntu

Install an appropriate 64-bit OS and sign in as the intended Hub user. From that user's home directory, run:

```bash
cd ~ && curl -fsSL https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/setup.sh -o setup.sh && sudo bash setup.sh
```

The setup script downloads the matching package and configures the service. Run it from the intended user's home folder, allow it to finish, then open `https://<hub-address>:5000`.

The local Hub uses a local certificate. Confirm you are connecting to your own Hub before accepting a browser certificate warning. Use your OS account's credentials; a generic OS installation does not automatically have a `dmx` account or password.

Useful service diagnostics:

```bash
sudo systemctl status dmxsmartlink
sudo journalctl -u dmxsmartlink -n 100 --no-pager
```

Do not restart or update a Hub during a live service or show.

## Connect smart lights

### Homebridge

Open **Homebridge UI** from the Hub and configure the relevant vendor integration. Confirm your light is visible and controllable in **Accessories**. Preserve the bundled Govee plugin version unless the release instructions recommend changing it. Only configure an Alexa plugin if your devices require that integration.

Enter the Homebridge connection details in Hub Settings, save, and refresh device inventory. Follow the vendor plugin's setup instructions for its account authentication.

### Home Assistant

Connect an existing Home Assistant instance through Hub Settings: enable the integration and enter its host, port and access token. Check the light entity in Home Assistant first, then refresh the Hub inventory. Enabling this connection does not by itself install Home Assistant or add every vendor integration.

Keep access tokens private. Provider compatibility and the available controls depend on the light's integration.

## Start with one light

1. Confirm the licence status and provider connection.
2. Add a supported light or patch one DMX fixture in the correct mode.
3. Check its universe, start address and full channel footprint.
4. Use Visual Control to test brightness, color and temperature where supported.
5. Save and recall a scene, then expand to the rest of the rig.

Preserve an existing external USB DMX fanout patch: when one input frame is reused across universes, assigned channel ranges must not overlap across that fanout.

Next: [Scenes and show setups](FEATURES.md), [Backup and restore](SOP-BACKUP-AND-RESTORE.md), [Update the Hub](SOP-UPDATE-THE-HUB.md).
