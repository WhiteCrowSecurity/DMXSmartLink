# Update the hub

**How long:** a few minutes. The hub restarts itself at the end.

**Do this when:** a release fixes something you have hit, or adds something you want. There is no
obligation to update — a hub keeps working exactly as it does today whether or not you ever update
it.

---

## Before you update

**Take a backup first.** It takes fifteen seconds and it is the difference between a bad afternoon
and a non-event. See [Back up and restore](SOP-BACKUP-AND-RESTORE.md).

**Do not update an hour before a service.** Update on a weekday, then run a scene or two to confirm
the rig behaves.

---

## Update

1. Open the hub and go to the **Dashboard**.
2. Find the **Updates** panel. It shows:
   - **Installed** — the version you are on
   - **Available** — the newest release for your update channel
   - A badge saying **Up to date** or that an update is available
3. Press **Check for Updates** if you want to force a fresh look.
4. Press **Update Now**.
5. Wait. The status line says *"Updating… please wait. The web UI may restart."* — that restart is
   normal. Do not reboot the machine or close the tab during it.
6. When the page comes back, check that **Installed** now shows the new version.

---

## After updating

1. Recall a scene you know well. Do the lights do what they should?
2. Check the DMX Patch page still shows your fixtures where you expect.
3. If you use a Stream Deck, press a button.

If all three are fine, you are done.

---

## Stable and Test channels

The **Updates** panel has a channel toggle.

| Channel | Gets | Use it if |
| --- | --- | --- |
| **Stable** (default) | Full releases only | You run services on this machine. Leave it here. |
| **Test (pre-release)** | Pre-releases, earlier | You have a spare machine and want to help us catch things |

Do not put your only hub on Test. A pre-release is by definition something we are still checking.

---

## If an update goes wrong

**The page never comes back.**
Give it two full minutes — a first start after an update is slower than usual. Then, on a Pi or
Ubuntu:

```bash
sudo systemctl status dmxsmartlink
sudo systemctl restart dmxsmartlink
sudo journalctl -u dmxsmartlink -n 100
```

On Windows or macOS, quit the app and start it again.

**It updated, but something is behaving oddly.**
Restart the hub first — that clears most of it. If it persists, email
**support@dmxsmartlink.com** with your version number and what you are seeing. Include the log if you
can get it.

**My settings or fixtures look wrong.**
Restore the backup you took before updating. That is what it was for.

---

## Updating without internet

A hub on an isolated network cannot pull an update itself. Download the release on a machine that has
internet, copy it across, and install it the same way you did originally — see
[Install](SOP-INSTALL.md).

Your data folder is untouched by an install, so your patch and scenes survive. Take a backup first
anyway.

---

## What an update does not change

- **Your licence.** It stays activated. An update is not a reinstall.
- **Your patch, scenes, groups and stage layout.** Those live in the data folder, which updates do
  not touch.
- **Your settings**, including your DMX USB device and universes.
