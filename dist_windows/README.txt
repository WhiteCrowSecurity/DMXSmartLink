DMX Smart Link — Windows
========================

The Windows build ships as a single installer, DMXSmartLink-Setup.exe.

Download it (the installer is published as a release asset, not in this folder, because it
exceeds GitHub's 100 MB in-repo file limit):

    https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest/download/DMXSmartLink-Setup.exe

Unlike the Raspberry Pi / Ubuntu builds, Windows ships as a single setup.exe. You do NOT
need Python, Docker, Node.js, or any other prerequisite — everything (the app, the audio
engine, and the native Homebridge + Govee integration) is bundled inside the installer.


Requirements
------------
- Windows 11 (64-bit)
- ~2 GB free disk space
- Internet access for activation (license) and for the Govee cloud integration


Install
-------
1. Double-click DMXSmartLink-Setup.exe.
   (Windows SmartScreen may warn that it is from an unknown publisher — choose
    "More info" -> "Run anyway".)
2. Accept the License Agreement.
3. Finish the wizard. It installs the app + the Homebridge/Govee bundle, opens the
   Windows Firewall so your phone/other devices can reach it, and creates a
   "DMXSmartLink" shortcut on your Desktop and Start Menu.
4. Double-click the DMXSmartLink shortcut. The app opens in its own window, and the
   server is reachable on your network at https://<this-pc-ip>:5000 (use that address
   in the iPhone app / another browser).
5. Enter your license key on first run to enable DMX output, and your Govee account in
   the Homebridge UI (http://localhost:8581) to control Govee lights.

Closing the app window stops the app and the Homebridge service.


Uninstall
---------
Settings -> Apps -> DMX Smart Link -> Uninstall (or Control Panel -> Programs).
This removes the app, the bundled Homebridge, the firewall rules, and all app data.


Support
-------
https://dmxsmartlink.com/pages/contact     |     https://www.youtube.com/@WhiteCrowSecurity
