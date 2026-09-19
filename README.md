# DMX Smart Link

**Drive smart lights from your lighting desk, and drive your stage lights from anything.**

DMX Smart Link is a lighting hub that speaks DMX on one side and smart-home lights on the
other. Patch your Govee or Alexa lights as DMX fixtures and control them from the
lighting software you already use — or run the whole show from the hub itself.

Tutorials: https://www.youtube.com/@WhiteCrowSecurity

---

## What you can do with it

**Bridge smart lights into DMX.** Smart bulbs, strips and bars appear as ordinary DMX
fixtures. Your desk sends DMX; they respond. Art-Net or sACN in, smart lights out.

**Control real fixtures too.** Moving heads, washes, pars and profile spots over Art-Net or
a USB DMX interface — the hub is a full lighting controller, not only a bridge. sACN is
supported as an input, so a desk speaking sACN can drive the hub.

**Visual Control.** Point-and-click control of any fixture or group: colour, brightness,
colour temperature, pan and tilt, strobe, gobos and effects. Controls appear based on what
each fixture can actually do.

**Scenes and groups.** Save a look and recall it instantly from the hub, a phone, a Stream
Deck or a MIDI controller. Group fixtures so one fader moves twelve lights.

**AI Light Show.** Audio-reactive shows that follow the music, using the fixtures and
groups you choose.

**AI Slide Show.** Lighting that follows images and presentations.

**Follow Spot.** Track a performer across the stage with saved stage positions, driven from
a phone, a MIDI surface or a Stream Deck.

**NDI video follow.** Lights take their colour from a live video feed, so stage washes match
what's on screen. Includes a visible stop control that leaves the lights where they are.

**Media Player.** Play audio through the hub and drive the show from it.

**Stream Deck and MIDI.** Recall scenes, trigger shows and run the follow spot from physical
buttons and faders. Apps for Windows and macOS are included with every release.

**Network Logs.** See exactly what the hub is sending and receiving when something looks wrong.

---

## The fixture library

**16,475 fixtures from 1,697 manufacturers, with 56,465 modes**, shipped with the app and
kept up to date every release. Includes **6,987 moving heads**.

Patch a fixture and its channels are mapped for you. Import an existing patch from a CSV and
the manufacturer, model and channel layout come with it.

**Channel Check** — for anything the library doesn't know. Send a value to a single channel,
watch what your light does, and save what works. No chart, no manual, no support ticket. A
value you set by looking at the fixture beats any data we hold, because you saw it.

**Moving lights open their shutter automatically** where the manufacturer data says how.
Where it doesn't, the fixture is left exactly as it is rather than guessed at, so nothing
starts flashing unexpectedly.

---

## Requirements

| Platform | Needs |
|---|---|
| **Windows 11** | One installer. Nothing else to set up. |
| **macOS** | One installer package. Apple Silicon and Intel. |
| **Raspberry Pi 5** | Recommended for permanent installs. 4 GB RAM. |
| **Ubuntu / Linux** | 2 CPUs, 4 GB RAM, internet during install. |

A licence key enables DMX output. Smart-light control runs through Homebridge, which the
installers set up for you.

---

## ⚠️ Photosensitivity and seizure warning

Lighting software can produce flashing, strobing and rapidly changing light. A small number
of people may experience seizures, loss of awareness or other adverse effects when exposed
to flashing lights or patterns, including people with no previous history of epilepsy.

**You are responsible for validating any show, scene or effect before running it in front of
an audience.** Test your programming in the venue, with your own fixtures, before anyone is
present. Warn your audience where flashing effects are used, and provide a way for people to
avoid or leave the space.

DMX Smart Link sends the instructions you give it to the fixtures you have patched. It cannot
know what your lights will physically do, and it is not a substitute for your own testing and
judgement.

---

# Installation


## Install on Windows 11 (one-click)

On Windows, DMX Smart Link installs from a single file — no Python, Docker, or Node.js to set up. Everything (the app, the audio engine, and the Homebridge + Govee integration) is bundled in the installer.

1. **Download:** https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/DMXSmartLink-Setup.exe
2. **Run it.** (Windows SmartScreen may warn it's from an unknown publisher → *More info* → *Run anyway*.) Accept the license agreement and finish the wizard — it installs the app + Homebridge, opens the firewall, and adds a **DMXSmartLink** Desktop / Start-Menu shortcut.
3. **Launch** via the DMXSmartLink shortcut. The app opens in its own window and is reachable on your network at `https://<this-pc-ip>:5000` (use that in the iPhone app or another browser).
4. **First run:** enter your license key to enable DMX output, and sign in to your Govee account in the Homebridge UI (`http://localhost:8581`) to control Govee lights.

**Uninstall:** Settings → Apps → DMX Smart Link → Uninstall (removes the app, the bundled Homebridge, the firewall rules, and all data).

---

## Install on macOS

1. **Download:** https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/DMXSmartLink-Installer.pkg
2. **Run it.** macOS may warn it is from an unidentified developer → right-click the package
   → *Open* → *Open*. The installer places the app and its bundled Homebridge integration.
3. **Launch** DMXSmartLink from Applications. The hub is reachable on your network at
   `https://<this-mac-ip>:5000`.
4. **First run:** enter your licence key to enable DMX output, and sign in to your smart-light
   account in the Homebridge UI (`http://localhost:8581`).

Apple Silicon and Intel are both supported.

---

## Raspberry Pi 5 / Ubuntu (Linux)

The steps below are for a Raspberry Pi 5 or Ubuntu install.

## Linux System Requirements

- Raspberry Pi 5 (recommended)
- Ubuntu Server or Virtual Machine
- Minimum **2 CPUs** and **4 GB RAM**
- Internet access during installation

### Default Credentials
```
Username: dmx
Password: dmx
```

**Change this password before the machine is reachable from anywhere but your bench.**
These are the documented defaults for a fresh image, which means everyone knows them.
Run `passwd` on first login.

---

## Installation Steps

### 1. Install Ubuntu Server
Install a basic Ubuntu Server on supported hardware or VM or install the Raspberry Pi 5 64bit os via their launcher from https://www.raspberrypi.com/software/.

---

### 2. Obtain the IP Address
You will need the system IP address later.

You can get it by:
- Installing the iOS app:  
  `https://apps.apple.com/us/app/dmxsmartlink-hub/id6753700995`
- Or running one of the following commands:
```
ip a
```
or
```
ifconfig
```

---

### 3. Run the Setup Script

Log in as the `dmx` user and run **one command**:

```
cd ~ && curl -fsSL https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/setup.sh -o setup.sh && sudo bash setup.sh
```

That is the whole install. The script downloads the right build for your machine by itself, so there
is nothing to unpack and no release page to choose from. It takes 15-30 minutes, mostly unattended.

**Run it from the home folder.** The `cd ~` matters: the script works out which user to install for
from the folder it is sitting in, so running it from `/tmp` or `Downloads` installs to the wrong
place.

<details>
<summary>If you already downloaded setup.sh by hand</summary>

```
sudo su
cd /home/dmx
chmod +x setup.sh
./setup.sh
```
</details>

---

### 4. Access the Web Interface
After installation completes, open a browser and go to:
```
https://<YOUR_IP_ADDRESS>:5000
```

---

## Homebridge Setup

### 6. Initialize Homebridge
1. Click **Homebridge UI**
2. Click **GET STARTED**
3. Create a username and password
4. Click **OPEN DASHBOARD**

---

### 7. Install Govee and Alexa Plugin or other vendors light plugins
1. Navigate to **Plugins**
2. **DO NOT** update the existing Govee plugin (We recommend this Plugin over Alexa for your Govee lights)
3. Restart Homebridge
4. Click the **power plug icon**
5. Search for **Alexa**
6. Install **Homebridge Alexa Smarthome** by @joeyhage

---

### 8. Configure Alexa Plugin
1. Scroll to **Proxy Client Host**
2. Enter your **system IP address**
   - ❌ Do NOT use `127.0.0.1` or `localhost`
3. Click **SAVE**
4. Enable **Child Bridge**
5. Restart Homebridge again

---

### 9. Authenticate Amazon Account

First login to your amazon.com account then,

Open:
```
http://<YOUR_IP_ADDRESS>:9000
```

Log in using:
- Amazon email
- Password
- OTP from phone or other method

When you see:
```
Amazon Alexa Cookie successfully retrieved
```
Close the browser tab.

---

### 10. Verify Devices
1. Return to **Homebridge UI**
2. Click **Accessories**
3. Wait for Alexa devices to populate

---

## DMX Smart Link Configuration

### 11. License Setup
1. Return to **DMX Smart Link**
2. Click **Manage Config**
3. Paste your license key
4. Enter Homebridge username and password
5. Click **Update Config**
6. Confirm license status shows:
```
Valid: Expires on ...
```

---

### 12. Import Devices
1. Click **Refresh Device Inventory**
2. Confirm success message appears

---

### 13. Create Groups
1. Navigate to **Manage Groups**
2. Create a new group:
   - Universe: **2 or higher**
   - Channels: e.g. `1,2,3,4,5`
3. Assign devices to the group

---

### 14. DMX Software Configuration (Example)
1. Add **Universe 2**
2. Add **Generic → Bulb**
3. Edit profile and set **5 channels**
4. Assign:
   - Channel 1: Red
   - Channel 2: Green
   - Channel 3: Blue
   - Channel 4: Dimmer
   - Channel 5: Color Temperature

---

## AI Light Show (Audio Reactive) – Quick Use

The AI Light Show runs inside the dashboard and can drive fixtures/groups based on audio input.

1. Open **AI Light Show (Audio Reactive)**
2. Select **Input Source (capture)**:
   - Line-In via USB sound card (tested: **CULILUX CB5**)
   - Or a system monitor source when analyzing playback on the device
3. Select **Output Device (speakers)** and click **Apply Settings**
4. Click **AI Show Start**

### Using the Media Player (Audio/Video files)
Inside the **AI Light Show** tab there is a **Media Player** section you can use to play local files and run the light show at the same time.

- **Audio files (MP3/WAV/etc)**:
  - Upload a file, select it, click **Play**
  - Audio plays in the browser using the built-in player controls
- **Video files (MP4/etc)**:
  - Upload a file, select it, click **Play**
  - Video plays in the browser (with controls)
  - Click **Fullscreen** for an in-page fullscreen experience

### Fullscreen & iPhone / AirPlay
- On **iPhone/iOS**, fullscreen uses an **in-page fullscreen overlay** to avoid the common AirPlay takeover behavior.
- If you want to AirPlay on purpose, use your device’s AirPlay controls; the UI fullscreen is designed to stay local.

### YouTube link playback + light show
You can paste a YouTube link in **External Video URL (YouTube/etc)** and click **Open** to watch it in the UI.

To sync the light show to a YouTube link:
- Use the **YouTube sync** feature (server-side audio extraction).
- **Prerequisite**: `yt-dlp` must be installed on the hub (setup.sh does this for you):
  - `sudo apt update && sudo apt install -y yt-dlp`

Important note on sync:
- The embedded YouTube player and server-synced audio may not start at the exact same “0:00” due to ads/buffering/cross-origin limitations.
- For perfect 1:1 sync between audio and video, use uploaded local media files (single source of truth).

---

## Visual Control – Quick Use

Use **Visual Control** for manual testing and setup:
- Verify your DMX universes and patching
- Test groups/fixtures output without audio analysis

---

## Updating DMX Smart Link

### Option A: Built-in Update
1. Open the Dashboard
2. Click **Check for Updates**
3. Click **Update Now**
4. System will sync from GitHub and reboot automatically

---

### Option B: Manual Update
1. Download latest release from GitHub
2. Extract `dmxsmartlink.zip`
3. Copy files to `/home/$USER`
4. Run:
```
sudo ./setup.sh
```

---

## Support

Email: **support@dmxsmartlink.com**  
Discord support available via the dashboard or `https://discord.gg/pj6f54dpv7`

---

## Legal / implementation note
The audio-reactive feature uses **standard audio analysis techniques** plus project-specific show-control logic.

© White Crow Security / DMXSmartLink
