# Back up and restore your setup

**Who this is for:** anyone running a hub. Do it once after you finish patching, and again after any
big change.

**How long:** under a minute.

Your hub holds work nobody can recreate from memory — a patched rig, a season of saved scenes, a
stage layout you placed by hand. On a Raspberry Pi that all lives on an SD card, which is the least
durable thing in the building. This saves it to one file.

---

## Make a backup

1. Open the hub in a browser and go to **Settings**.
2. Scroll to **Backup & restore** (or use the **Backup & restore** shortcut at the top of the page).
3. Click **Export backup**.
4. Your browser downloads `dmxsmartlink-backup-<date>-<time>.zip`. Put it somewhere you would still
   have it if the hub were gone — cloud storage, a USB stick, an email to yourself.

Nothing on the hub changes when you export. It is safe to do in the middle of a service.

> **Do this on a schedule.** Once a month, and always right after you patch a new fixture or build a
> scene you would hate to rebuild.

---

## Put a backup back

1. Go to **Settings → Backup & restore**.
2. Click **Import a backup…** and choose your `.zip` file.
3. The page tells you **when the backup was made**, what version it came from, and exactly what it is
   about to replace. Nothing has happened yet.
4. Read that, then click **Restore this backup**.
5. The page reloads. Your fixtures, scenes, groups and stage layout are back.

You do not need to restart the hub.

### If you change your mind

Click **Cancel** at step 4. Nothing is written.

### If you restored the wrong file

Everything the restore overwrote was copied aside first, into a folder named
`pre-restore-<date>-<time>` inside the hub's data folder. Nothing is lost — contact support and we
will help you put it back.

---

## Moving to a new machine

1. **Export** on the old hub.
2. Install DMX Smart Link on the new machine.
3. **Activate the new machine's licence** — see [Activate your licence](SOP-ACTIVATE-A-LICENCE.md).
4. **Import** the backup.

Your patch, scenes and stage come across. Your licence does not, and that is deliberate — see below.

---

## What is in the file, and what is not

**In it:** fixtures and their stage positions, scenes, groups and the stage background, your smart
light inventory, the Visual Control layout, follow-spot settings, and your ordinary settings.

**Not in it — on purpose:**

- **Your licence key.** It belongs to you and to that machine, so it never travels in a file that
  might get emailed around. A restored hub asks for its own licence.
- **Passwords and API keys** — Home Assistant token, Homebridge password, Govee API key, email
  password. The backup tells you which ones it left out.
- **Live status** — which scene is up right now, what the DMX output looked like a moment ago,
  whether a Stream Deck is plugged in. All of that rebuilds itself in seconds.

This means a backup file is safe to store in cloud storage or hand to support. It does not contain
your licence or your passwords.

---

## Questions

**Can I restore a backup onto a different kind of machine?**
Yes. A backup from a Raspberry Pi restores onto Windows, macOS or Ubuntu, and the other way round.

**Can I restore an old backup onto a newer version of the app?**
Yes. The other direction is refused: a backup made by a *newer* version than the hub you are
restoring onto will be rejected rather than half-applied. Update the hub first.

**Will it black out my lights?**
No. A restore changes files, not the current output.

**I get "not a DMX Smart Link backup".**
The file is not one of ours, or it was renamed from something else. Use the `.zip` the Export button
produced, unmodified — do not unzip and rezip it.
