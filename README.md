
DMX Smart Link – Installation Instructions

Best Tutorials for the product:  https://www.youtube.com/@WhiteCrowSecurity

1. Install a basic Ubuntu Server on hardware such as a Raspberry Pi 5 or a VM with at least 2 CPUs and 4GB of RAM.
     - Default credentials are:
       Username: dmx
       Password: dmx

     - Get the OVF image for Intel systems here https://www.dropbox.com/scl/fi/q2xqj8dfd8jqexwyuchy9/dmxsmartlink-vm-intel-ovf.zip?rlkey=g4i1bg6m1kpgdp4xo22fewcre&st=45bl1380&dl=1

3. Obtain the IP address of the host by installing the iOS iPhone App at https://apps.apple.com/us/app/dmxsmartlink-hub/id6753700995 or typing either:
   - `ip a`
   - or `ip config`
   (You will need this IP address later.)

4. Copy all files from `dmxsmartlink.zip` into the `/home/$USER` folder.

5. Open a terminal and type:
   - `sudo su`

6. Make the setup script executable:
   - `chmod +x setup.sh`

7. Run the setup script:
   - `sudo ./setup.sh`

8. After the automated reboot, browse to:
   - `https://<YOUR_IP_ADDRESS>:5000`

9. Click the **"Homebridge UI"** link and then click **"GET STARTED"**.

10. Create a username and password and remember these for future steps.

11. Click **"OPEN DASHBOARD"**, then navigate to **"Plugins"** on the top-left navigation bar.

12. Click **"UPDATE"** for the available update for **Homebridge UI**, then click **"CLOSE"**.

13. Click the **Restart** button on the top-right corner.

14. Once restarted, click the **power plug icon** on the top-left sidebar to access the plugins page.

15. In the top-left search bar, type **"Alexa"** and press **Enter**.

16. Click the orange **Download** button on the **"Homebridge Alexa Smarthome"** plugin by @joeyhage.

17. Scroll to the **"Proxy Client Host"** field and enter your **IP address** from step 2 (Do NOT use 127.0.0.1 or localhost). Click **SAVE** at the bottom-right.

18. Enable the **child bridge** by toggling "HomebridgeAlexaSmartHome" and click **SAVE**.

19. Click **Restart** on the top-right again.

20. Open another browser tab and go to:
   - `http://<YOUR_IP_ADDRESS>:9000`

20. Enter your Amazon email, password, and OTP from your phone. You should see:
   - “Amazon Alexa Cookie successfully retrieved. You can close the browser.”  
   Now close the tab.

21. Return to the **Homebridge UI**, click the **light bulb "Accessories"** icon. You should see all Alexa devices populate in a few minutes.

22. Return to the **DMX Smart Link** webpage.

23. Navigate to **Manage Config**:
   - Insert your license key from the email into the **LICENSE_KEY** field and click **"Update Config"**.
   - Enter your **Homebridge Username** and **Password** and click **"Update Config"** again.
   - Click **"Back to Dashboard"** and confirm License Status shows:  
     **“Valid: Expires on ...”**

24. Click the **"Art-Net Output"** link in the top navigation bar and verify there are no license errors.

25. Go back to the Dashboard and click **"Refresh Device Inventory"**.  
    You should see **"Success: Device inventory refreshed"** once your Alexa devices have been imported.

26. Navigate to **Manage Groups** from the Dashboard:
   - You should now see all device names and IDs listed.

27. Scroll to **Create New Groups**:
   - Enter a **Group Name**
   - Set **Universe** to 2 or higher
   - Define 5 DMX channels (e.g., 1,2,3,4,5)
   - Click **"Create Group"**

28. Select devices you want to assign to a group, choose the group name, and click **"Assign Devices"**.

29. In your DMX software (e.g., LightKey):
   - Open **"Manage Fixtures"**
   - Add **Universe 2** to match the group

30. Click **Generic → Bulb** and drag it into the first channel of the group.

31. Right-click the fixture and select **"Edit Profile"**

32. Click **"Edit a Copy"**, name it (e.g., "Alexa Smart Lights").

33. Click **"Add Modes"**

34. Change channel count from **1 to 5**, click outside, then click **"Done"**.

35. Remove the **Dimmer** property by clicking the “x”.

36. Assign properties in this order:
   - Channel 1: Red
   - Channel 2: Green
   - Channel 3: Blue
   - Channel 4: Dimmer
   - Channel 5: Color Temperature
   - Click **"Save"**

37. Click **Done** to finish.

You can now manage this group of lights with one fixture.  
Repeat to add more fixtures and groups as needed.

For support, email: **support@whitecrowsecurity.com**
