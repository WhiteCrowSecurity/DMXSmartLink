# DMXSmartLink Release Notes

## Version 1.0.1

### 🎨 User Interface Improvements

#### Professional Dark Theme
- Complete UI redesign with modern, professional dark theme
- Mobile-responsive design optimized for all screen sizes
- Improved button styling with gradient backgrounds and hover effects
- Enhanced visual hierarchy and readability
- Consistent styling across all pages (Dashboard, Devices, Groups, Config, Art-Net Output)

#### Mobile Optimization
- Buttons now display in a 2-column grid on mobile devices (instead of stacking vertically)
- Improved touch targets and spacing for mobile users
- Responsive layout adjustments for better mobile experience

### 🔄 Update System

#### GitHub-Based Updates
- New update system that pulls files from GitHub repository
- Architecture-aware updates (automatically detects Pi 5, Ubuntu Intel, Ubuntu M4, M5, etc.)
- Configuration file preservation (devices.json, groups.json, license files, config.py)
- Only updates files that exist in the repository, preserving local files

#### Auto-Update Feature
- **NEW:** Auto-update now enabled by default for new installations
- One-shot auto-update that runs once on startup (then automatically disables)
- Green toggle switch in UI to enable/disable auto-update
- Auto-update includes: file updates, Homebridge container update, and Govee plugin installation

#### Update Process
- Manual "Update Now" button available in UI
- Updates Homebridge Docker container automatically
- **NEW:** Automatically installs custom Govee plugin during updates (matches setup behavior)
- Clear status messages and progress feedback

### 🏠 Home Assistant Integration (Experimental)

- **NEW:** Experimental Home Assistant integration support
- Configure HA connection via config page (IP, port, token)
- Unified device inventory merges Homebridge and HA devices
- Control HA light entities via DMX/Art-Net input
- Mix Homebridge and HA devices in the same groups
- Labeled as "Experimental" in the UI with red warning indicator

### 📦 Device & Group Management

#### Improved Group Management Workflow
- **NEW:** Streamlined group creation and device assignment
- Create group first, then add devices via dedicated "Add Devices" button
- Device selection page with filtering options
- Visual indicators for device status (already in group, in another group, available)
- "Show all devices" option to see devices already assigned to other groups

#### Enhanced Device Views
- **NEW:** Device filtering and sorting on "View All Devices" page
- Search by name, provider, model, or device ID
- Sortable columns (Position, Name, Provider, Model, Device ID)
- Same filtering/sorting capabilities on "Add Devices to Group" page

#### Bulk Operations
- **NEW:** "Select All" checkbox for each group to remove multiple devices at once
- Improved device removal workflow

### 🔑 License Management

#### License Status Display
- Visual indicators: green checkmark (✓) for valid license, red X (✗) for invalid
- Combined "Buy/Renew License" button (always visible)
- Deactivate License button for valid licenses

#### Trial License
- Direct link to 14-day trial license request page
- Integrated with Shopify trial form
- Clear call-to-action button

### 🆘 Support & Contact

#### Support Options
- **NEW:** "Contact Support" button linking to contact form
- **NEW:** Discord support button with icon
- Support options moved to main dashboard buttons section
- Easy access to help resources

### 🧹 Code Cleanup & Maintenance

#### Matter Support Removal
- Removed all Matter controller code and dependencies
- Cleaned up setup scripts (removed Matter server installation)
- Removed Matter-related UI elements and routes
- Simplified architecture focusing on Homebridge and Home Assistant integration

#### Configuration Management
- Removed incorrect warning about server restart requirement
- Changes to config.py now take effect immediately
- Updated all status messages to reflect immediate effect
- Improved error messages and user feedback

### 🐛 Bug Fixes

- Fixed binary file handling in update process (proper encoding handling)
- Improved error handling throughout the application
- Fixed mobile button layout issues
- Corrected default values for auto-update feature

### 📝 Developer Notes

- Improved code organization and structure
- Better separation of concerns
- Enhanced error handling and logging
- More robust update process with better error recovery

---

## Migration Notes

### For Existing Installations

1. **Auto-Update:** Auto-update is now enabled by default. Existing installations will keep their current setting.

2. **Home Assistant:** To use Home Assistant integration, configure it in the "Manage Config" page. This is experimental and may have limitations.

3. **Device Inventory:** All devices (Homebridge and HA) are now in a unified inventory. No action needed - existing devices remain compatible.

4. **Update Process:** When updating, the custom Govee plugin will now be automatically reinstalled if needed.

---

## Technical Details

### New Dependencies
- None (removed Matter dependencies)

### Removed Dependencies
- `python-matter-server`
- `aiohttp` (Matter-related)
- `matter_server.client`

### Configuration Changes
- No breaking changes to existing configuration files
- New optional HA configuration parameters available

---

## Known Issues

- Home Assistant integration is marked as experimental and may have limitations
- Mobile UI may need further refinements based on user feedback

---

## Upgrade Instructions

1. **Automatic:** If auto-update is enabled, updates will occur on next startup
2. **Manual:** Click "Update Now" button in the Updates section
3. **Via Setup Script:** Re-run setup script for fresh installation

---

For support, visit: https://dmxsmartlink.com/pages/contact or join our Discord server.

