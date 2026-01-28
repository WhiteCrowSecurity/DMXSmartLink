#!/bin/bash
# setup.sh — DMXSmartLink installer (flat layout, Raspberry Pi OS/Ubuntu)
# - Uses any installed Python 3.x for the venv
# - No CPython-from-source builds
# - venv-only installs (PEP-668 safe)
# - Installs Flask, requests, PyJWT[crypto], PyArmor
# - Copies flat project (incl. pyarmor_runtime_XXXXX/ for PyArmor Pro)
# - Files are pre-obfuscated, runtime is included
# - Installs Docker (+ fallback via get.docker.com)
# - Starts Homebridge in Docker with host DBus socket for BLE access
# - Installs Govee plugin inside the container + BLE build deps
# - Creates systemd unit running flat main.py from the venv
# - Ensures child processes use venv (PATH), and files are writable by service user
set -Eeuo pipefail

# ---------------- Non-interactive APT (no blue screens) ----------------
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export APT_LISTCHANGES_FRONTEND=none
export TZ=Etc/UTC
APT_FLAGS='-yq -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold'
apt_update()  { apt-get update -yq; }
apt_install() { apt-get install $APT_FLAGS --no-install-recommends "$@"; }

# ---------------- Paths / Users ----------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="$(basename "$SCRIPT_DIR")"     # e.g., /home/dmx -> dmx
HOME_DIR="$SCRIPT_DIR"
TARGET_DIR="$HOME_DIR/dmxsmartlink"
SERVICE_FILE="/etc/systemd/system/dmxsmartlink.service"
CONFIG_DIR="/home/$USER_NAME/homebridge-config"

# ---------------- Python 3.x ----------------
PYTHON_BIN=""

# ---------------- Custom Govee plugin repo ----------------
# You can swap this to @homebridge-plugins/homebridge-govee if you want the official one
GOVEE_REPO="github:cybermancerr/homebridge-govee#latest"

log() { echo -e "$*"; }

detect_architecture() {
  # Detect architecture and return the appropriate dist directory name
  local arch_dir=""

  # Check for Raspberry Pi (Raspbian/Debian on ARM)
  if [ -f /etc/os-release ]; then
    local os_release=$(cat /etc/os-release | tr '[:upper:]' '[:lower:]')
    if echo "$os_release" | grep -q "raspbian\|raspberry"; then
      echo "dist_pi5"
      return 0
    fi
  fi

  # Check CPU info for better detection
  local machine=$(uname -m)
  local cpuinfo=""
  if [ -f /proc/cpuinfo ]; then
    cpuinfo=$(cat /proc/cpuinfo | tr '[:upper:]' '[:lower:]')
  fi

  # ARM architecture (64-bit)
  if [[ "$machine" == "aarch64" ]] || [[ "$machine" == "arm64" ]] || [[ "$machine" == "armv8l" ]]; then
    # Check for Apple Silicon
    if echo "$cpuinfo" | grep -q "apple"; then
      if echo "$cpuinfo" | grep -q "m5"; then
        echo "dist_ubuntu_m5"
        return 0
      elif echo "$cpuinfo" | grep -q "m4"; then
        echo "dist_ubuntu_m4"
        return 0
      fi
      echo "dist_ubuntu_m4"  # Default Apple Silicon
      return 0
    fi
    # Check if it's Ubuntu (not Raspbian) - likely Apple Silicon VM
    if [ -f /etc/os-release ]; then
      local os_release_content=$(cat /etc/os-release | tr '[:upper:]' '[:lower:]')
      if echo "$os_release_content" | grep -q "ubuntu" && ! echo "$os_release_content" | grep -q "raspbian\|raspberry"; then
        # Ubuntu on ARM64 (not Raspbian) - likely Apple Silicon VM
        # Try to detect M5 specifically, otherwise default to M4
        if echo "$cpuinfo" | grep -q "m5"; then
          echo "dist_ubuntu_m5"
        else
          echo "dist_ubuntu_m4"
        fi
        return 0
      fi
    fi
    # Default ARM (Raspberry Pi should have been caught above)
    echo "dist_pi5"
    return 0
  fi

  # Intel/AMD x86_64
  if [[ "$machine" == "x86_64" ]] || [[ "$machine" == "amd64" ]] || [[ "$machine" == "i686" ]] || [[ "$machine" == "i386" ]]; then
    echo "dist_ubuntu_intel"
    return 0
  fi

  # Default fallback
  echo "dist_ubuntu_intel"
}

copy_project() {
  log "✅ STEP 2: Ensuring target folder: $TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  chown "$USER_NAME:$USER_NAME" "$TARGET_DIR"

  # Ensure minimal tooling for GitHub download
  if ! command -v curl >/dev/null 2>&1; then apt_update; apt_install curl ca-certificates; fi
  if ! command -v unzip >/dev/null 2>&1; then apt_update; apt_install unzip; fi
  if ! command -v python3 >/dev/null 2>&1; then apt_update; apt_install python3; fi

  # Detect architecture to determine which dist directory to use
  local DIST_DIR
  DIST_DIR=$(detect_architecture)
  log "    Detected architecture, using GitHub directory: $DIST_DIR"

  # Save the architecture to a file for future updates
  echo "$DIST_DIR" > "$TARGET_DIR/.install_arch"
  chown "$USER_NAME:$USER_NAME" "$TARGET_DIR/.install_arch"

  # GitHub repository details
  local GITHUB_REPO="WhiteCrowSecurity/DMXSmartLink"
  local TEMP_DIR="/tmp/dmxsmartlink-src-$$"
  local ZIP_PATH="/tmp/dmxsmartlink-release-$$.zip"

  rm -rf "$TEMP_DIR" "$ZIP_PATH"
  mkdir -p "$TEMP_DIR"

  # ------------------------------------------------------------
  # PRIMARY (NO-API): Always try GitHub "latest" asset download.
  # Requires the release to have an asset named: dmxsmartlink.zip
  # ------------------------------------------------------------
  local SRC_DIR=""
  local LATEST_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/dmxsmartlink.zip"

  log "    Fetching latest release zip (no API): $LATEST_URL"
  if curl -fL "$LATEST_URL" -o "$ZIP_PATH" 2>/dev/null; then
    log "    ✓ Downloaded latest release asset"
    if unzip -q "$ZIP_PATH" -d "$TEMP_DIR" 2>/dev/null; then
      local ROOT_DIR
      ROOT_DIR="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)"
      if [[ -n "$ROOT_DIR" ]] && [[ -d "$ROOT_DIR/$DIST_DIR" ]]; then
        SRC_DIR="$ROOT_DIR/$DIST_DIR"
        log "    Using extracted release folder: $SRC_DIR"
      else
        # Check if dist directory exists directly in extracted location (no root subdirectory)
        if [[ -d "$TEMP_DIR/$DIST_DIR" ]]; then
          SRC_DIR="$TEMP_DIR/$DIST_DIR"
          log "    Using extracted release folder (direct): $SRC_DIR"
        else
          log "    ⚠ Directory $DIST_DIR not found in extracted zip"
          log "    Available directories: $(ls -1 "$TEMP_DIR" 2>/dev/null | head -5 | tr '\n' ' ')"
          if [[ -n "$ROOT_DIR" ]]; then
            log "    Root dir contents: $(ls -1 "$ROOT_DIR" 2>/dev/null | head -10 | tr '\n' ' ')"
          fi
          SRC_DIR=""
        fi
      fi
    else
      log "    ⚠ Failed to extract zip file"
      SRC_DIR=""
    fi
  else
    log "    ⚠ Failed to download latest asset (no API). Will try API fallback…"
  fi

  # ------------------------------------------------------------
  # FALLBACK: GitHub API (/releases/latest) to find ANY zip asset,
  # or zipball_url if no asset found.
  # ------------------------------------------------------------
  if [[ -z "${SRC_DIR:-}" ]]; then
    log "    Fetching via GitHub API fallback..."
    local API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    local REL_JSON=""
    local API_ERROR=""

    if command -v curl >/dev/null 2>&1; then
      # NOTE: -f makes curl exit non-zero on 4xx/5xx (rate limits, etc.)
      if ! REL_JSON="$(curl -fsSL "$API_URL" 2>/dev/null)"; then
        API_ERROR="api_failed"
      fi
    else
      API_ERROR="no_curl"
    fi

    local DOWNLOAD_URL=""
    if [[ -z "$API_ERROR" ]] && [[ -n "$REL_JSON" ]] && command -v python3 >/dev/null 2>&1; then
      # IMPORTANT: keep stderr separate so DOWNLOAD_URL stays clean
      DOWNLOAD_URL="$(
        python3 - <<'PY' <<<"$REL_JSON"
import json,sys
try:
    d=json.loads(sys.stdin.read() or "{}")
    if isinstance(d, dict) and d.get("message"):
        # API error payload
        print("")
        raise SystemExit(0)

    assets=d.get("assets") or []

    # Prefer an asset named like dmxsmartlink*.zip (case-insensitive)
    for a in assets:
        name=(a.get("name","") or "").lower()
        url=a.get("browser_download_url","") or ""
        if name.startswith("dmxsmartlink") and name.endswith(".zip") and url:
            print(url); raise SystemExit(0)

    for a in assets:
        name=(a.get("name","") or "").lower()
        url=a.get("browser_download_url","") or ""
        if "dmxsmartlink" in name and name.endswith(".zip") and url:
            print(url); raise SystemExit(0)

    # Else: first .zip asset
    for a in assets:
        name=a.get("name","") or ""
        url=a.get("browser_download_url","") or ""
        if (name.endswith(".zip") or url.endswith(".zip")) and url:
            print(url); raise SystemExit(0)

    # Fallback to zipball_url (source code zip)
    zipball=d.get("zipball_url","") or ""
    if zipball:
        print(zipball)
    else:
        print("")
except Exception:
    print("")
PY
      )"
    fi

    if [[ -n "$DOWNLOAD_URL" ]]; then
      log "    Downloading release via API-derived URL: $DOWNLOAD_URL"
      if curl -fL "$DOWNLOAD_URL" -o "$ZIP_PATH" 2>/dev/null; then
        if unzip -q "$ZIP_PATH" -d "$TEMP_DIR" 2>/dev/null; then
          local ROOT_DIR
          ROOT_DIR="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)"
          if [[ -n "$ROOT_DIR" ]] && [[ -d "$ROOT_DIR/$DIST_DIR" ]]; then
            SRC_DIR="$ROOT_DIR/$DIST_DIR"
            log "    Using extracted release folder: $SRC_DIR"
          else
            if [[ -d "$TEMP_DIR/$DIST_DIR" ]]; then
              SRC_DIR="$TEMP_DIR/$DIST_DIR"
              log "    Using extracted release folder (direct): $SRC_DIR"
            else
              log "    ⚠ Directory $DIST_DIR not found in extracted zip"
              log "    Available directories: $(ls -1 "$TEMP_DIR" 2>/dev/null | head -5 | tr '\n' ' ')"
              if [[ -n "$ROOT_DIR" ]]; then
                log "    Root dir contents: $(ls -1 "$ROOT_DIR" 2>/dev/null | head -10 | tr '\n' ' ')"
              fi
              SRC_DIR=""
            fi
          fi
        else
          log "    ⚠ Failed to extract zip file"
          SRC_DIR=""
        fi
      else
        log "    ⚠ Failed to download zip file via API-derived URL"
        SRC_DIR=""
      fi
    else
      log "    ⚠ API fallback did not produce a download URL"
    fi
  fi

  # Final failure if still no source directory
  if [[ -z "${SRC_DIR:-}" ]]; then
    log "❌ Failed to download release zip."
    log "    Primary (no-API) tried:"
    log "    $LATEST_URL"
    log "    Fallback tried GitHub API:"
    log "    https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    log "    Check: https://github.com/${GITHUB_REPO}/releases"
    log "    Make sure the release has an asset named exactly: dmxsmartlink.zip"
    log "    The zip should contain: dist_pi5/, dist_ubuntu_intel/, dist_ubuntu_m4/, etc."
    rm -rf "$TEMP_DIR" "$ZIP_PATH"
    exit 1
  fi

  log "    Syncing all files from $DIST_DIR into $TARGET_DIR (preserving user data)..."
  if ! command -v rsync >/dev/null 2>&1; then
    apt_update
    apt_install rsync
  fi

  # Copy EVERYTHING from the extracted dist folder into the install directory.
  # Exclusions prevent clobbering user data and venv.
  rsync -a --delete \
    --exclude=".venv/" \
    --exclude="__pycache__/" \
    --exclude=".install_arch" \
    --exclude="config.json" \
    --exclude="devices.json" \
    --exclude="groups.json" \
    "$SRC_DIR/" "$TARGET_DIR/"
  log "    ✓ Sync complete"

  # Clean up temp download directory
  rm -rf "$TEMP_DIR" "$ZIP_PATH"

  chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR"
  find "$TARGET_DIR" -type d -exec chmod 775 {} \;
  find "$TARGET_DIR" -type f -exec chmod 664 {} \;
  # Ensure .so files are executable (required for PyArmor runtime)
  find "$TARGET_DIR" -name "*.so" -exec chmod 755 {} \;

  echo
}

install_docker() {
  log "------------------------------------------------------"
  log "STEP 3: Installing Docker (apt, then fallback to get.docker.com if needed)..."
  apt_update || true
  if ! apt_install docker.io; then
    log "    apt install docker.io failed or unavailable; trying Docker convenience script…"
  fi

  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
  fi

  systemctl enable docker
  systemctl start docker

  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker CLI not found after installation attempts. Aborting."
    exit 10
  fi
  docker --version || true
  systemctl --no-pager status docker.service -n 0 || true
  echo
}

ensure_base_tooling() {
  log "------------------------------------------------------"
  log "STEP 4: Installing base tooling (venv + basics)..."
  apt_update
  apt_install python3 python3-venv python3-pip curl ca-certificates build-essential wget openssl git unzip \
              avahi-daemon libnss-mdns dbus \
              python3-dev portaudio19-dev pipewire pipewire-pulse wireplumber pulseaudio-utils \
              bluez libspa-0.2-bluetooth rfkill \
              ffmpeg yt-dlp

  # Optional: PipeWire CLI tools package name differs by distro.
  # We primarily need either:
  # - `pw-cat` (PipeWire) OR
  # - `parec` (PulseAudio utils) which we already install via pulseaudio-utils.
  if command -v apt-cache >/dev/null 2>&1 && apt-cache show pipewire-tools >/dev/null 2>&1; then
    apt_install pipewire-tools || true
  else
    apt_install pipewire-bin || true
  fi
  systemctl enable avahi-daemon || true
  systemctl restart avahi-daemon || true
  echo
}

# ---------- Host-side BLE prerequisites (Pi 5 / Raspberry Pi OS / Ubuntu) ----------
install_ble_support_host() {
  log "------------------------------------------------------"
  log "STEP 4b: Installing host Bluetooth / BLE dependencies..."
  # These follow the Homebridge Bluetooth wiki recommendations.
  # pi-bluetooth will simply be ignored on non-Raspberry Pi distros.
  apt_update
  apt_install bluetooth bluez libbluetooth-dev libudev-dev expect || true
  apt_install pi-bluetooth || true

  systemctl enable bluetooth || true
  systemctl restart bluetooth || true

  # Quick hint for the operator:
  log "    → Host Bluetooth stack should now be active (check with: hciconfig or bluetoothctl show)."
  echo
}

ensure_python() {
  log "------------------------------------------------------"
  log "STEP 5: Ensuring Python 3.x is available..."

  # 1) Prefer any available python3.x version
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
    log "Found $("$PYTHON_BIN" -V) — will use this for the venv."
    return 0
  fi

  # 2) Fallback: if python3.13 exists, use it
  if command -v python3.13 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3.13)"
    log "Found $("$PYTHON_BIN" -V) — will use this for the venv."
    return 0
  fi

  # If no Python 3.x is found
  echo "❌ Python 3.x not found."
  echo "   This project REQUIRES Python 3.x. Please install Python 3.x, then rerun this script."
  exit 2
}

create_venv_and_install() {
  log "------------------------------------------------------"
  log "STEP 6: Creating venv on Python 3.x and installing deps…"
  log "    Using interpreter: $("$PYTHON_BIN" -V)"
  sudo -u "$USER_NAME" bash -lc "
    set -e
    cd '$TARGET_DIR'
    rm -rf .venv
    '$PYTHON_BIN' -m venv .venv
    source .venv/bin/activate
    pip install -U pip
    pip install -U Flask requests 'PyJWT[crypto]' pyarmor pyarmor.cli.core pyserial psutil numpy sounddevice
    # aubio is optional; on newer Python versions it may not build from source
    pip install -U aubio || true
  "
  echo
}

# NOTE: PyArmor Pro runtime is included and copied automatically
# Files are pre-obfuscated with PyArmor Pro, runtime folder is detected and copied
# No need to regenerate or verify when just copying files

add_user_to_docker() {
  log "------------------------------------------------------"
  log "STEP 7: Adding user '$USER_NAME' to the docker group..."
  getent group docker >/dev/null 2>&1 || groupadd docker
  usermod -aG docker "$USER_NAME" || true
  log "    (You may need to log out/in for group changes to apply.)"
  echo
}

# ---------- Detect host DBus socket (for BLE in Docker) ----------
detect_dbus_socket_dir() {
  # Returns host directory that contains system_bus_socket, or empty string
  if [[ -S /run/dbus/system_bus_socket ]]; then
    echo "/run/dbus"
  elif [[ -S /var/run/dbus/system_bus_socket ]]; then
    echo "/var/run/dbus"
  else
    echo ""
  fi
}

start_homebridge() {
  log "------------------------------------------------------"
  log "STEP 8: Pulling Homebridge Docker image..."
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ docker CLI not found; install_docker must succeed before this step."
    exit 11
  fi
  docker pull homebridge/homebridge
  echo

  log "------------------------------------------------------"
  log "STEP 9: Starting Homebridge container on ports 8581/9000 with BLE support..."
  mkdir -p "$CONFIG_DIR"
  chown "$USER_NAME:$USER_NAME" "$CONFIG_DIR"

  if docker ps -a --format '{{.Names}}' | grep -q '^homebridge$'; then
    log "    Existing 'homebridge' container found; removing to recreate..."
    docker rm -f homebridge || true
  fi

  # Mount DBus socket into container at /run/dbus:ro per Bluetooth wiki
  local DBUS_HOST_DIR
  DBUS_HOST_DIR="$(detect_dbus_socket_dir)"
  local DBUS_VOLUME=""
  if [[ -n "$DBUS_HOST_DIR" ]]; then
    DBUS_VOLUME="-v ${DBUS_HOST_DIR}:/run/dbus:ro"
    log "    → Using DBus socket from ${DBUS_HOST_DIR} -> /run/dbus:ro in container."
  else
    log "    ⚠ WARNING: No DBus system_bus_socket found; BLE plugins may not work in Docker."
  fi

  docker run -d \
    --name homebridge \
    --restart=always \
    --network host \
    ${DBUS_VOLUME} \
    -v "$CONFIG_DIR":/homebridge \
    homebridge/homebridge

  log "    → Homebridge container started."
  log "    → Visit http://<your-pi-or-ubuntu-ip>:8581 to finish Homebridge setup."
  echo
}

setup_audio_sudoers() {
  log "------------------------------------------------------"
  log "STEP 10: Configuring sudoers for audio controls..."
  local SUDO_FILE="/etc/sudoers.d/dmx-audio"
  cat > "$SUDO_FILE" <<'EOF'
dmx ALL=(root) NOPASSWD: /usr/bin/bluetoothctl, /usr/bin/pactl
EOF
  chmod 440 "$SUDO_FILE"
  visudo -cf "$SUDO_FILE" || true
  echo
}

setup_update_sudoers() {
  log "------------------------------------------------------"
  log "STEP 10b: Configuring sudoers for updater prereqs..."
  # Allows the web UI "Update Now" flow to install missing prerequisites and reboot non-interactively.
  local SUDO_FILE="/etc/sudoers.d/dmx-updater"
  cat > "$SUDO_FILE" <<'EOF'
dmx ALL=(root) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/sbin/reboot, /sbin/reboot, /usr/bin/reboot
EOF
  chmod 440 "$SUDO_FILE"
  visudo -cf "$SUDO_FILE" || true
  echo
}

install_govee_plugin() {
  log "------------------------------------------------------"
  log "STEP 10: Installing Govee plugin into Homebridge container (with BLE deps)..."

  # Install build/runtime deps for noble stack inside the container
  docker exec -u root -e DEBIAN_FRONTEND=noninteractive -e NEEDRESTART_MODE=a homebridge \
    bash -lc "apt-get update -yq && apt-get install -yq --no-install-recommends git curl bluetooth bluez libbluetooth-dev libudev-dev pi-bluetooth || true"

  # Install the plugin itself
  docker exec homebridge bash -lc "cd /homebridge && npm install '$GOVEE_REPO' || true"

  # Give node cap_net_raw so noble can open HCI sockets if needed
  docker exec -u root homebridge bash -lc 'setcap cap_net_raw+eip "$(eval readlink -f "$(which node)")" || true'

  docker exec homebridge bash -lc "cd /homebridge && npm ls --depth=0 || true"
  docker restart homebridge >/dev/null
  log "    → Govee plugin installed, BLE deps present, and Homebridge restarted."
  echo
}

write_service() {
  local entry_abs="/home/$USER_NAME/dmxsmartlink/main.py"
  local workdir="/home/$USER_NAME/dmxsmartlink"

  log "------------------------------------------------------"
  log "STEP 11: Creating systemd service at $SERVICE_FILE..."
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=DMXSmartLink Dashboard Service
After=network.target docker.service
Requires=docker.service

[Service]
User=$USER_NAME
WorkingDirectory=$workdir
ExecStartPre=/usr/bin/docker pull homebridge/homebridge
ExecStart=/home/$USER_NAME/dmxsmartlink/.venv/bin/python $entry_abs
Restart=always
RestartSec=5
UMask=0002
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=$workdir
Environment=PATH=/home/$USER_NAME/dmxsmartlink/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable dmxsmartlink.service
  systemctl restart dmxsmartlink.service
  echo
}

configure_passwordless_sudo() {
  log "------------------------------------------------------"
  log "STEP 12: Configuring passwordless sudo for service restart..."

  local sudoers_entry="$USER_NAME ALL=(ALL) NOPASSWD: /bin/systemctl restart dmxsmartlink.service"
  local sudoers_file="/etc/sudoers.d/dmxsmartlink-restart"

  # Check if entry already exists
  if [ -f "$sudoers_file" ] && grep -qF "$sudoers_entry" "$sudoers_file" 2>/dev/null; then
    log "    ✓ Passwordless sudo already configured"
  else
    echo "$sudoers_entry" > "$sudoers_file"
    chmod 0440 "$sudoers_file"
    log "    ✓ Passwordless sudo configured for: systemctl restart dmxsmartlink.service"
  fi
  echo
}

# ========================== MAIN ==========================
log "✅ STEP 1: Detected script directory: $SCRIPT_DIR (user = $USER_NAME)"

# Install git early if needed (for downloading from GitHub)
if ! command -v git >/dev/null 2>&1; then
  log "Installing git for GitHub access..."
  apt_update
  apt_install git || true
fi

echo

copy_project

# Verify main.py was downloaded
if [ ! -f "$TARGET_DIR/main.py" ]; then
  log "❌ ERROR: main.py not found in $TARGET_DIR after download"
  exit 1
fi

ENTRYPOINT_REL="main.py"
ensure_base_tooling
install_ble_support_host        # Host-side BLE support (Pi OS + Ubuntu)
ensure_python
create_venv_and_install
install_docker
add_user_to_docker
start_homebridge                # Starts with DBus exposed into container
install_govee_plugin            # Installs plugin + BLE deps + setcap inside container
write_service
configure_passwordless_sudo     # Allow service user to restart service without password
setup_audio_sudoers             # Allow bluetoothctl/pactl for UI
setup_update_sudoers            # Allow apt-get/reboot for Update Now prereq installs

log "✅ All steps complete."
log "Service status (last 30 lines):"
systemctl --no-pager -n 30 status dmxsmartlink.service || true
