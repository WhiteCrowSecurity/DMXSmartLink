# Install DMX Smart Link

**How long:** 15–30 minutes on a Raspberry Pi (most of it unattended), a few minutes on Windows or
macOS.

Pick your platform below. Whichever you choose, you will finish with a hub you reach from a browser
at `https://<the machine's address>:5000`.

---

## Before you start

**You will need a USB-to-DMX interface** to drive DMX fixtures — an FTDI-based device (a DMX USB Pro
or compatible). Smart lights over Wi-Fi do not need one.

**Give the machine a fixed address.** Reserve its IP on your router, or set a static address. You
will be typing this address on phones and saving it in Stream Deck buttons; you do not want it moving.

---

## Raspberry Pi or Ubuntu

A Raspberry Pi 5 is the usual choice. A Pi 4 works.

1. Install Raspberry Pi OS (64-bit) or Ubuntu, and make sure you can log in over SSH.
2. Log in, and run **one command**:

   ```bash
   cd ~ && curl -fsSL https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/setup.sh -o setup.sh && sudo bash setup.sh
   ```

   That is the whole install. The script downloads the right build for your machine by itself —
   there is nothing to unpack and no release page to pick from.

3. Leave it alone. It installs Python packages into a virtual environment, sets up Docker and
   Homebridge for smart-light support, and creates a `dmxsmartlink` systemd service.
4. When it finishes, open `https://<pi-address>:5000` in a browser.

> **Run it from your home folder.** The `cd ~` matters: the script works out which user to install
> for from the folder it is sitting in. Running it from `/tmp` or `Downloads` will install to the
> wrong place.

Your browser will warn about the certificate. That is expected — the hub generates its own, because
it serves your local network, not the public internet. Accept it and continue.

**Useful commands afterwards:**

```bash
sudo systemctl status dmxsmartlink     # is it running?
sudo systemctl restart dmxsmartlink    # restart it
sudo journalctl -u dmxsmartlink -f     # watch the log
```

---

## Windows

1. Download the Windows installer from the
   [Releases page](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases).
2. Run it and follow the prompts.
3. Launch DMX Smart Link. It opens your browser at `https://127.0.0.1:5000`.

Your settings and data live in `C:\ProgramData\DMXSmartLink`.

To reach the hub from a phone, use the PC's network address — `https://192.168.1.50:5000` or similar
— and allow DMX Smart Link through Windows Firewall when prompted.

---

## macOS

1. Download the `.pkg` from the
   [Releases page](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases).
2. Open it and follow the installer.
3. Launch **DMX Smart Link** from Applications. It opens your browser automatically.

Your settings and data live in `~/Library/Application Support/DMXSmartLink`.

---

## First run

1. **Activate your licence** — see [Activate your licence](SOP-ACTIVATE-A-LICENCE.md).
2. **Set the DMX USB device.** Settings → *DMX USB Device Configuration* → choose your interface and
   its output universe. Leave it on auto-detect if you only have one.
3. **Patch your fixtures.** Fixtures → add each light from the built-in library (over 12,000
   fixtures) and give it a DMX address.
4. **Lay out the stage.** Visual Control → drag each fixture to roughly where it is in the room. This
   is what makes the rest of the app make sense at a glance.
5. **Save a scene** once it looks right.
6. **Take a backup** — see [Back up and restore](SOP-BACKUP-AND-RESTORE.md). Do this before you need
   it.

---

## Common problems

**The browser says the connection is not private.**
Expected. The hub uses a self-signed certificate because it serves your local network. Continue past
the warning. It is encrypted; it is simply not signed by a public authority.

**I cannot reach it from my phone.**
The phone must be on the same network as the hub, and on Windows the firewall must allow it. Check
you are using the machine's network address, not `127.0.0.1`.

**No DMX output.**
Check Settings → DMX USB: is your interface listed and selected? Then check the fixture's DMX address
matches what you patched. The DMX Patch page shows what is assigned where.

**Lights flicker.**
Most often this is the same physical USB interface being used for both input and output. Use
different devices, or turn input off.
