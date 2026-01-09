# DMX Smart Link – Installation Instructions

Best tutorials for the product:  
https://www.youtube.com/@WhiteCrowSecurity

---

## System Requirements

- Ubuntu Server (recommended)
- Raspberry Pi 5 or Virtual Machine
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
Install a basic Ubuntu Server on supported hardware (Raspberry Pi 5 or VM).

---

### 2. Obtain the IP Address
You will need the system IP address later.

You can get it by:
- Installing the iOS app:  
  https://apps.apple.com/us/app/dmxsmartlink-hub/id6753700995
- Or running one of the following commands:
```
ip a
```
or
```
ip config
```

---

### 3. Copy Installation Files
Copy all files from `dmxsmartlink.zip` into:
```
/home/$USER
```

---

### 4. Run the Setup Script
Open a terminal and run:

```
sudo su
chmod +x setup.sh
sudo ./setup.sh
```

---

### 5. Access the Web Interface
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

### 7. Install Alexa Plugin
1. Navigate to **Plugins**
2. **DO NOT** update the existing Govee plugin
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
Open:
```
http://<YOUR_IP_ADDRESS>:9000
```

Log in using:
- Amazon email
- Password
- OTP from phone

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
Discord support available via the dashboard

---

© White Crow Security / DMXSmartLink
