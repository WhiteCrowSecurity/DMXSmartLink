# Update DMXSmartLink Hub

Schedule updates outside a service, show or other live use. [Export a backup](SOP-BACKUP-AND-RESTORE.md) first and allow time to validate your rig afterward.

## Built-in update

1. Open **Dashboard → Updates**.
2. Confirm the installed version and selected channel.
3. Select **Check for Updates** and review the available version.
4. Select **Update Now** and follow the prompts. The application or service may close and restart while installation runs. Keep the host powered on and do not repeatedly start another update.
5. Reconnect and confirm the **Installed** version matches the release you selected.

The official release **2026.09.21.1444** is on Stable/Latest. Users of its earlier betas can switch back to Stable to install it.

## Stable and Test channels

| Channel | Purpose |
|---|---|
| Stable / Latest | Published official releases. Use this for normal installations. |
| Test (pre-release) | Candidate releases for deliberate beta testing. Enable Developer mode to expose this option. |

Read the resolved release tag in the UI before installing. The existence of a newer beta does not mean the stable channel should install it.

## Desktop installer fallback

If the built-in Windows or macOS update fails, retain its error/log and download the matching installer from [Latest](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest). Close DMXSmartLink as prompted and run the installer over the existing installation. Do not uninstall first as an update workaround; export a backup before making changes.

The current Windows package is x64; the current Mac package targets Apple silicon. This release's Windows installer and same-version reinstall passed data-preservation checks; the Mac installation preserved the protected application data in testing. Keep your own backup regardless.

## If the Hub does not reconnect

- Allow installation to finish. Check the host's current network address and use `https://<hub-address>:5000`.
- Keep the updater log. A failed-update message is not proof that the installed version changed successfully.
- On Pi/Ubuntu, inspect the service without launching another update:

```bash
sudo systemctl status dmxsmartlink
sudo journalctl -u dmxsmartlink -n 100 --no-pager
```

- Contact support with the platform, previous version, target version and error. Remove credentials from any logs you share.

## Validate before the next event

Check your patch and provider connections, recall familiar scenes, inspect brightness and color temperature, and try your controller buttons. For audio/video shows, confirm the source and target selection, load the intended saved setup, and test Stop followed by scene recall.

The intermittent fixture-display flashing report remains under investigation. See the [current release notes](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest) for known limitations.

[Discord support](https://discord.gg/pj6f54dpv7) · **support@dmxsmartlink.com**
