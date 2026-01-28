# DMX Smart Link – Installation Instructions

Best tutorials for the product:  
`https://www.youtube.com/@WhiteCrowSecurity`

---

## What DMX Smart Link is

DMX Smart Link is a hub that bridges **DMX software** (Art-Net / DMX universes) with **SmartLights** via Homebridge, so you can control SmartLights from your DMX controller/software.

It also includes:
- **AI Light Show (Audio Reactive)** (new): an audio-reactive show mode inside the dashboard.
- **Visual Control**: manual DMX/fixture/group controls for testing and setup.

---

## System Requirements

- Raspberry Pi 5 (recommended)
- Ubuntu Server or Virtual Machine
- Minimum **2 CPUs** and **4 GB RAM**
- Internet access during installation

### Default Credentials
```
Username: dmx
Password: dmx
```

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
You only need `setup.sh` in the home directory of the `dmx` user.  
The installer will **download/sync everything it needs from the GitHub repo** automatically (no manual file copying required).

Open a terminal and run:

```
sudo su
cd /home/dmx
chmod +x setup.sh
./setup.sh
```

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

### 14. DMX Software Configuration (Example: LightKey)
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

Email: **support@whitecrowsecurity.com**  
Discord support available via the dashboard or `https://discord.gg/pj6f54dpv7`

---

## Legal / implementation note
The audio-reactive feature uses **standard audio analysis techniques** plus project-specific show-control logic.

© White Crow Security / DMXSmartLink
