#!/bin/bash
# setup.sh â€” DMXSmartLink installer (flat layout, Raspberry Pi OS/Ubuntu)
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
ROOT_UPDATE_WORKER="/usr/local/sbin/dmxsmartlink-root-update"
ROOT_UPDATE_LAUNCHER="/usr/local/sbin/dmxsmartlink-update-launcher"

# ---------------- Python 3.x ----------------
PYTHON_BIN=""

# ---------------- Official Govee plugin repo ----------------
GOVEE_PLUGIN="@homebridge-plugins/homebridge-govee@latest"
GOVEE_REPO="github:homebridge-plugins/homebridge-govee#latest"

log() { echo -e "$*"; }

extract_zip_allowing_warnings() {
  local zip_path="$1"
  local dest_dir="$2"
  local unzip_output=""
  local unzip_status=0

  unzip_output="$(unzip -q "$zip_path" -d "$dest_dir" 2>&1)" || unzip_status=$?

  if [[ $unzip_status -eq 0 ]]; then
    return 0
  fi

  if find "$dest_dir" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    log "    unzip returned warning(s) but extracted files are present; continuing"
    if [[ -n "$unzip_output" ]]; then
      log "    unzip output: $(printf '%s' "$unzip_output" | head -n1)"
    fi
    return 0
  fi

  if [[ -n "$unzip_output" ]]; then
    log "    unzip output: $(printf '%s' "$unzip_output" | head -n1)"
  fi
  return 1
}

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
  log "âœ… STEP 2: Ensuring target folder: $TARGET_DIR"
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
  local TARBALL_PATH="/tmp/dmxsmartlink-release-$$.tar.gz"
  local ZIP_PATH="/tmp/dmxsmartlink-release-$$.zip"

  rm -rf "$TEMP_DIR" "$TARBALL_PATH" "$ZIP_PATH"
  mkdir -p "$TEMP_DIR"

  # ------------------------------------------------------------
  # PRIMARY (NO-API): download the small PER-ARCHITECTURE tarball asset
  # (dist_<arch>.tar.gz, ~65-70MB) instead of the combined dmxsmartlink.zip
  # (~740MB -- bundles every platform: Pi, Ubuntu, Windows, macOS). Pulling
  # the full combined zip just to use one arch's subfolder was unreliable on
  # constrained Pi hardware (slow WiFi, small SD card, tight /tmp space) and
  # caused installs to fail outright. The combined zip is kept as a fallback
  # further down in case a specific release is ever missing the per-arch asset.
  # ------------------------------------------------------------
  local SRC_DIR=""
  local ASSET_NAME="${DIST_DIR}.tar.gz"
  local LATEST_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${ASSET_NAME}"

  # Resolve the update channel. A 'test' box (dev only) installs the newest GitHub
  # PRE-RELEASE via the API path below; the no-API 'latest' shortcut is stable-only
  # (GitHub's 'latest' excludes pre-releases). Set by --test-channel / DMXSMARTLINK_CHANNEL,
  # or an existing update_channel marker on a re-run.
  local CHANNEL="${DMXSMARTLINK_CHANNEL:-stable}"
  if [[ "$CHANNEL" != "test" ]] && [[ "$(cat "$TARGET_DIR/update_channel" 2>/dev/null | tr -d '[:space:]')" == "test" ]]; then
    CHANNEL="test"
  fi
  [[ "$CHANNEL" == "test" ]] || CHANNEL="stable"
  log "    Update channel: $CHANNEL"

  if [[ "$CHANNEL" == "stable" ]]; then
    log "    Fetching latest release asset (no API): $LATEST_URL"
  else
    log "    Test channel: skipping no-API latest; will resolve newest pre-release via API"
  fi
  if [[ "$CHANNEL" == "stable" ]] && curl -fL "$LATEST_URL" -o "$TARBALL_PATH" 2>/dev/null; then
    log "    OK: downloaded latest release asset ($ASSET_NAME)"
    if tar -xzf "$TARBALL_PATH" -C "$TEMP_DIR" 2>/dev/null; then
      if [[ -d "$TEMP_DIR/$DIST_DIR" ]]; then
        SRC_DIR="$TEMP_DIR/$DIST_DIR"
        log "    Using extracted release folder: $SRC_DIR"
      else
        log "    WARNING: $DIST_DIR not found after extracting $ASSET_NAME"
        log "    Extracted top-level entries: $(ls -1 "$TEMP_DIR" 2>/dev/null | head -5 | tr '\n' ' ')"
      fi
    else
      log "    WARNING: failed to extract $ASSET_NAME"
    fi
  else
    log "    WARNING: failed to download $ASSET_NAME (no API). Will try API fallback..."
  fi

  # ------------------------------------------------------------
  # FALLBACK 1: GitHub API (/releases/latest, or the pre-release list on the
  # test channel) to find the same per-arch tarball asset by name.
  # ------------------------------------------------------------
  if [[ -z "${SRC_DIR:-}" ]]; then
    log "    Fetching via GitHub API fallback..."
    local API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    if [[ "$CHANNEL" == "test" ]]; then
      # the releases list (newest-first) so we can select the newest pre-release
      API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=20"
    fi
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
      # IMPORTANT: keep stderr separate so DOWNLOAD_URL stays clean.
      # Use a pipe here so stdin carries JSON only; `python3 - <<'PY' <<<"$REL_JSON"`
      # makes Python treat the JSON as code, which breaks on JSON booleans like `false`.
      DOWNLOAD_URL="$(
        printf '%s' "$REL_JSON" | CHANNEL="$CHANNEL" ASSET_NAME="$ASSET_NAME" python3 -c '
import json, os, sys
CHANNEL = os.environ.get("CHANNEL", "stable")
ASSET_NAME = os.environ.get("ASSET_NAME", "")

def asset_from(rel):
    assets = rel.get("assets") or []
    # 1) exact per-arch tarball match (preferred -- small, fast, arch-specific)
    for asset in assets:
        name = asset.get("name", "") or ""
        url = asset.get("browser_download_url", "") or ""
        if name == ASSET_NAME and url:
            return url
    # 2) legacy combined zip (older releases before per-arch tarballs existed)
    for asset in assets:
        name = (asset.get("name", "") or "").lower()
        url = asset.get("browser_download_url", "") or ""
        if name.startswith("dmxsmartlink") and name.endswith(".zip") and url:
            return url
    return rel.get("zipball_url", "") or ""

try:
    d = json.loads(sys.stdin.read() or "{}")
    if CHANNEL == "test" and isinstance(d, list):
        # the releases list is newest-first; take the newest pre-release
        for rel in d:
            if isinstance(rel, dict) and rel.get("prerelease"):
                print(asset_from(rel))
                raise SystemExit(0)
        print("")  # no pre-release -> stable fallback handled by caller
        raise SystemExit(0)
    if isinstance(d, dict) and d.get("message"):
        print("")
        raise SystemExit(0)
    print(asset_from(d) if isinstance(d, dict) else "")
except Exception:
    print("")
' 2>/dev/null
      )"

    # Test channel with no pre-release available: never leave the box without a
    # source -- fall back to the stable 'latest' asset.
    if [[ -z "$DOWNLOAD_URL" ]] && [[ "$CHANNEL" == "test" ]]; then
      log "    No pre-release found; falling back to stable latest."
      DOWNLOAD_URL="$LATEST_URL"
    fi
    fi

    if [[ -n "$DOWNLOAD_URL" ]]; then
      log "    Downloading release asset via API-derived URL: $DOWNLOAD_URL"
      if [[ "$DOWNLOAD_URL" == *.zip ]]; then
        # Legacy combined-zip path (older release, or per-arch asset missing).
        if curl -fL "$DOWNLOAD_URL" -o "$ZIP_PATH" 2>/dev/null && extract_zip_allowing_warnings "$ZIP_PATH" "$TEMP_DIR"; then
          local ROOT_DIR
          ROOT_DIR="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)"
          if [[ -d "$TEMP_DIR/$DIST_DIR" ]]; then
            SRC_DIR="$TEMP_DIR/$DIST_DIR"
            log "    Using extracted release folder (direct): $SRC_DIR"
          elif [[ -n "$ROOT_DIR" ]] && [[ -d "$ROOT_DIR/$DIST_DIR" ]]; then
            SRC_DIR="$ROOT_DIR/$DIST_DIR"
            log "    Using extracted release folder: $SRC_DIR"
          else
            log "    WARNING: directory $DIST_DIR not found in extracted zip"
            log "    Available directories: $(ls -1 "$TEMP_DIR" 2>/dev/null | head -5 | tr '\n' ' ')"
          fi
        else
          log "    WARNING: failed to download/extract zip fallback"
        fi
      else
        if curl -fL "$DOWNLOAD_URL" -o "$TARBALL_PATH" 2>/dev/null && tar -xzf "$TARBALL_PATH" -C "$TEMP_DIR" 2>/dev/null; then
          if [[ -d "$TEMP_DIR/$DIST_DIR" ]]; then
            SRC_DIR="$TEMP_DIR/$DIST_DIR"
            log "    Using extracted release folder: $SRC_DIR"
          else
            log "    WARNING: $DIST_DIR not found after extracting API-derived asset"
          fi
        else
          log "    WARNING: failed to download/extract API-derived asset"
        fi
      fi
    else
      log "    WARNING: API fallback did not produce a download URL"
    fi
  fi

  # Final failure if still no source directory
  if [[ -z "${SRC_DIR:-}" ]]; then
    log "ERROR: failed to download release asset."
    log "    Primary (no-API) tried:"
    log "    $LATEST_URL"
    log "    Fallback tried GitHub API:"
    log "    https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    log "    Check: https://github.com/${GITHUB_REPO}/releases"
    log "    Make sure the release has an asset named exactly: $ASSET_NAME"
    log "    (or, as a last resort, a combined dmxsmartlink.zip containing dist_pi5/, dist_ubuntu_intel/, etc.)"
    rm -rf "$TEMP_DIR" "$TARBALL_PATH" "$ZIP_PATH"
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
    --exclude="dev_mode" \
    --exclude="update_channel" \
    "$SRC_DIR/" "$TARGET_DIR/"
  log "    âœ“ Sync complete"

  # Clean up temp download directory
  rm -rf "$TEMP_DIR" "$TARBALL_PATH" "$ZIP_PATH"

  chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR"
  find "$TARGET_DIR" -type d -exec chmod 775 {} \;
  find "$TARGET_DIR" -type f -exec chmod 664 {} \;
  # Ensure .so files are executable (required for PyArmor runtime)
  find "$TARGET_DIR" -name "*.so" -exec chmod 755 {} \;

  # On the test channel, leave the box dev-enabled + pinned to test so future
  # Update Now runs keep pulling pre-releases. Both markers are cwd-relative user
  # data (rsync-excluded above), so they persist across upgrades.
  if [[ "$CHANNEL" == "test" ]]; then
    printf 'test\n' > "$TARGET_DIR/update_channel"
    : > "$TARGET_DIR/dev_mode"
    chown "$USER_NAME:$USER_NAME" "$TARGET_DIR/update_channel" "$TARGET_DIR/dev_mode"
    log "    Test channel: wrote dev_mode + update_channel=test"
  fi

  echo
}

install_docker() {
  log "------------------------------------------------------"
  log "STEP 3: Installing Docker (apt, then fallback to get.docker.com if needed)..."
  apt_update || true
  if ! apt_install docker.io; then
    log "    apt install docker.io failed or unavailable; trying Docker convenience scriptâ€¦"
  fi

  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
  fi

  systemctl enable docker
  systemctl start docker

  if ! command -v docker >/dev/null 2>&1; then
    echo "âŒ Docker CLI not found after installation attempts. Aborting."
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

  # yt-dlp from apt/distro is STALE and YouTube breaks it (nsig/SABR extraction errors), which
  # kills the YouTube URL light-show sync. Fetch the current standalone binary to /usr/local/bin
  # (ahead of the apt copy on PATH). Best-effort: if offline, the apt yt-dlp remains as fallback.
  if curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp 2>/dev/null; then
    chmod a+rx /usr/local/bin/yt-dlp 2>/dev/null || true
    log "yt-dlp: installed current standalone binary ($(/usr/local/bin/yt-dlp --version 2>/dev/null || echo '?'))"
  else
    log "yt-dlp: standalone fetch failed; keeping apt yt-dlp (may be stale for YouTube)"
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

  # Stream Deck (USB HID) support: hidapi-libusb backend + udev access for the service user.
  # (libhidapi-hidraw0 may coexist; the library only loads libhidapi-libusb.so.0. Never apt-remove it:
  #  apt would drag its reverse-dependencies out with it.)
  apt_install libhidapi-libusb0 libusb-1.0-0 || true
  cat > /etc/udev/rules.d/10-streamdeck.rules <<'EOF_SD'
# Elgato Stream Deck
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0fd9", MODE="0660", GROUP="plugdev", TAG+="uaccess"
# Mirabox StreamDock family (YoloLiv YoloDeck = 6603:1005), Ajazz (0300)
SUBSYSTEMS=="usb", ATTRS{idVendor}=="6603", MODE="0660", GROUP="plugdev", TAG+="uaccess"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="6602", MODE="0660", GROUP="plugdev", TAG+="uaccess"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="5548", MODE="0660", GROUP="plugdev", TAG+="uaccess"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="5500", MODE="0660", GROUP="plugdev", TAG+="uaccess"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="0300", MODE="0660", GROUP="plugdev", TAG+="uaccess"
# their keyboard interface (event node) — the hub grabs it so presses don't type
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="6603", MODE="0660", GROUP="plugdev"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="6602", MODE="0660", GROUP="plugdev"
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="5548", MODE="0660", GROUP="plugdev"
EOF_SD
  getent group plugdev >/dev/null 2>&1 || groupadd plugdev || true
  usermod -aG plugdev "$USER_NAME" 2>/dev/null || true
  udevadm control --reload-rules 2>/dev/null || true
  udevadm trigger 2>/dev/null || true

  systemctl enable bluetooth || true
  systemctl restart bluetooth || true

  # Quick hint for the operator:
  log "    â†’ Host Bluetooth stack should now be active (check with: hciconfig or bluetoothctl show)."
  echo
}

ensure_python() {
  log "------------------------------------------------------"
  log "STEP 5: Ensuring Python 3.x is available..."

  # 1) Prefer any available python3.x version
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
    log "Found $("$PYTHON_BIN" -V) â€” will use this for the venv."
    return 0
  fi

  # 2) Fallback: if python3.13 exists, use it
  if command -v python3.13 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3.13)"
    log "Found $("$PYTHON_BIN" -V) â€” will use this for the venv."
    return 0
  fi

  # If no Python 3.x is found
  echo "âŒ Python 3.x not found."
  echo "   This project REQUIRES Python 3.x. Please install Python 3.x, then rerun this script."
  exit 2
}

create_venv_and_install() {
  log "------------------------------------------------------"
  if [[ -f "$TARGET_DIR/main.dist/main.bin" ]]; then
    log "STEP 6: Nuitka standalone build detected â€” skipping app venv (binary is self-contained)."
    chmod 755 "$TARGET_DIR/main.dist/main.bin" 2>/dev/null || true
    echo
    return 0
  fi
  log "STEP 6: Creating venv on Python 3.x and installing depsâ€¦"
  log "    Using interpreter: $("$PYTHON_BIN" -V)"
  sudo -u "$USER_NAME" bash -lc "
    set -e
    cd '$TARGET_DIR'
    rm -rf .venv
    '$PYTHON_BIN' -m venv .venv
    source .venv/bin/activate
    pip install -U pip
    pip install -U Flask requests 'PyJWT[crypto]' pyarmor pyarmor.cli.core pyserial psutil numpy sounddevice streamdeck Pillow
    # aubio is optional. It is known to fail building on Python 3.13+ due to upstream C/Numpy API changes.
    PYVER=\$('\"$PYTHON_BIN\"' -c 'import sys; print(sys.version_info[0]*100 + sys.version_info[1])' 2>/dev/null || echo 0)
    if [ \"\$PYVER\" -ge 313 ]; then
      echo \"Skipping aubio install (optional; not compatible with Python 3.13+)\"
    else
      pip install -U aubio || true
    fi
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
    echo "âŒ docker CLI not found; install_docker must succeed before this step."
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
    log "    â†’ Using DBus socket from ${DBUS_HOST_DIR} -> /run/dbus:ro in container."
  else
    log "    âš  WARNING: No DBus system_bus_socket found; BLE plugins may not work in Docker."
  fi

  docker run -d \
    --name homebridge \
    --restart=always \
    --network host \
    ${DBUS_VOLUME} \
    -v "$CONFIG_DIR":/homebridge \
    homebridge/homebridge

  log "    â†’ Homebridge container started."
  log "    â†’ Visit http://<your-pi-or-ubuntu-ip>:8581 to finish Homebridge setup."
  echo
}

# ---- Home Assistant + Matter Server (companion containers) -----------------------------------
# Same footing as Homebridge: Docker containers on host networking, data under the user's home.
# Idempotent: creates what is missing, refreshes what exists (pull + recreate with the same
# arguments). Skipped, with a clear message, when Docker is absent or the disk is nearly full
# (the Home Assistant image is ~2.3 GB). The hub onboards Home Assistant itself on first start
# (homeassistant_setup.py): admin account, API token, local Govee + Matter integrations.
HA_IMAGE="ghcr.io/home-assistant/home-assistant:stable"
MATTER_IMAGE="ghcr.io/home-assistant-libs/python-matter-server:stable"
HA_MIN_FREE_MB=4500

_ha_free_mb() { df -Pm "$1" 2>/dev/null | awk 'NR==2{print $4}'; }

ensure_home_assistant() {
  log "------------------------------------------------------"
  log "Home Assistant + Matter Server containers..."
  if ! command -v docker >/dev/null 2>&1; then
    log "    ⚠ Docker not found; skipping Home Assistant"
    return 0
  fi
  local ha_dir="${HA_CONFIG_DIR:-/home/$USER_NAME/homeassistant-config}"
  local matter_dir="${MATTER_DATA_DIR:-/home/$USER_NAME/matter-data}"
  mkdir -p "$ha_dir" "$matter_dir"
  chown "$USER_NAME:$USER_NAME" "$ha_dir" "$matter_dir" 2>/dev/null || true
  local have_ha=0 have_matter=0
  docker ps -a --format '{{.Names}}' | grep -qx homeassistant && have_ha=1
  docker ps -a --format '{{.Names}}' | grep -qx matter-server && have_matter=1
  local free_mb
  free_mb="$(_ha_free_mb /var/lib/docker 2>/dev/null || _ha_free_mb /)"
  if [[ $have_ha -eq 0 ]] && [[ -n "$free_mb" ]] && (( free_mb < HA_MIN_FREE_MB )); then
    log "    ⚠ Only ${free_mb} MB free; Home Assistant needs ~${HA_MIN_FREE_MB} MB. Skipping (free space and re-run the update)."
    return 0
  fi
  local tz
  tz="$(cat /etc/timezone 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo UTC)"
  local dbus_dir dbus_vol=""
  dbus_dir="$( [[ -S /run/dbus/system_bus_socket ]] && echo /run/dbus || ( [[ -S /var/run/dbus/system_bus_socket ]] && echo /var/run/dbus ) || true )"
  [[ -n "$dbus_dir" ]] && dbus_vol="-v ${dbus_dir}:/run/dbus:ro"

  # The images are large (Home Assistant ~2.3 GB). When they are not on the box yet, pull and
  # start them in the BACKGROUND so the update itself finishes promptly; the hub's setup thread
  # waits for the container and onboards Home Assistant once it answers.
  # A fixed /tmp path can be unwritable for root when another user created it (fs.protected_regular),
  # so use a fresh temp file and keep the log with the hub's logs; never let this step abort the update.
  rm -f /tmp/dmxsl_ha_containers.sh 2>/dev/null || true
  local runner
  runner="$(mktemp /tmp/dmxsl_ha_containers.XXXXXX 2>/dev/null || echo /tmp/dmxsl_ha_containers.$$.sh)"
  local runner_log="/home/$USER_NAME/dmxsmartlink/logs/ha_containers.log"
  mkdir -p "$(dirname "$runner_log")" 2>/dev/null || true
  if ! cat > "$runner" <<EOF_HA
#!/bin/bash
docker pull "$HA_IMAGE" >/dev/null 2>&1 || true
docker rm -f homeassistant >/dev/null 2>&1 || true
docker run -d --name homeassistant --restart=unless-stopped --network host --privileged \
  -e TZ="$tz" -v "$ha_dir":/config "$HA_IMAGE" >/dev/null 2>&1
docker pull "$MATTER_IMAGE" >/dev/null 2>&1 || true
docker rm -f matter-server >/dev/null 2>&1 || true
docker run -d --name matter-server --restart=unless-stopped --network host \
  --security-opt apparmor=unconfined $dbus_vol -v "$matter_dir":/data \
  "$MATTER_IMAGE" --storage-path /data --log-level info >/dev/null 2>&1
EOF_HA
  then
    log "    ⚠ Could not write the Home Assistant container script ($runner); skipping Home Assistant this time"
    return 0
  fi
  chmod +x "$runner"
  if docker image inspect "$HA_IMAGE" >/dev/null 2>&1; then
    if bash "$runner"; then
      log "    ✓ Home Assistant + Matter Server containers $( [[ $have_ha -eq 1 ]] && echo refreshed || echo created ) (http://<hub-ip>:8123)"
    else
      log "    ⚠ Home Assistant / Matter Server container start reported an error (non-fatal)"
    fi
  else
    nohup bash "$runner" >"$runner_log" 2>&1 &
    log "    ⏳ Downloading Home Assistant (~2.3 GB) in the background; the hub finishes its setup once it is up"
  fi
  echo
}

setup_network_sudoers() {
  # Lets the web UI (Settings -> Network) switch Wi-Fi on/off, scan and connect through NetworkManager.
  local SUDO_FILE="/etc/sudoers.d/dmxsmartlink-network"
  local NMCLI RFKILL
  NMCLI="$(command -v nmcli || echo /usr/bin/nmcli)"
  RFKILL="$(command -v rfkill || echo /usr/sbin/rfkill)"
  cat > "$SUDO_FILE" <<EOF
$USER_NAME ALL=(root) NOPASSWD: $NMCLI, $RFKILL
EOF
  chmod 440 "$SUDO_FILE"
  visudo -cf "$SUDO_FILE" >/dev/null 2>&1 || rm -f "$SUDO_FILE"
  if command -v nmcli >/dev/null 2>&1; then
    log "    ✓ Wi-Fi / Ethernet control from the web UI enabled (NetworkManager)"
  else
    log "    ⚠ NetworkManager (nmcli) not found; Wi-Fi control in the web UI is unavailable on this hub"
  fi
}

install_kiosk() {
  # Boot-to-hub browser for a Pi with its own screen: Chromium opens the hub full screen, past the
  # self-signed certificate warning, touch friendly. Only where a desktop session and Chromium exist.
  local CHROME=""
  local c
  for c in chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1; then CHROME="$(command -v "$c")"; break; fi
  done
  if [[ -z "$CHROME" ]] || [[ ! -d /etc/xdg/autostart ]]; then
    log "    Kiosk: no desktop / Chromium on this hub; skipping (headless hub)"
    return 0
  fi
  cat > /usr/local/bin/dmxsmartlink-kiosk <<'EOF_KIOSK'
#!/bin/bash
# DMXSmartLink kiosk: shows the hub full screen on this Pi's screen. Follows KIOSK_ENABLED in the hub's
# Settings live: off closes the browser, on re-opens it. Started by the desktop session (xdg autostart).
HUB="${DMXSL_KIOSK_HUB:-https://127.0.0.1:5000}"
CHROME=""
for c in chromium chromium-browser; do command -v "$c" >/dev/null 2>&1 && { CHROME="$c"; break; }; done
[ -n "$CHROME" ] || exit 0
enabled() { curl -sk -m 3 "$HUB/api/kiosk/state" 2>/dev/null | grep -q '"enabled": *true'; }
PID=""
while true; do
  if enabled; then
    if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
      nice -n 10 "$CHROME" --kiosk --start-fullscreen --noerrdialogs --disable-infobars --no-first-run --password-store=basic \
        --ignore-certificate-errors --disable-session-crashed-bubble --disable-features=TranslateUI \
        --check-for-update-interval=31536000 --overscroll-history-navigation=0 --touch-events=enabled \
        --user-data-dir="$HOME/.config/dmxsmartlink-kiosk" "$HUB/" >/dev/null 2>&1 &
      PID=$!
    fi
  else
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; fi
    PID=""
  fi
  sleep 5
done
EOF_KIOSK
  chmod 755 /usr/local/bin/dmxsmartlink-kiosk
  cat > /etc/xdg/autostart/dmxsmartlink-kiosk.desktop <<'EOF_DESK'
[Desktop Entry]
Type=Application
Name=DMXSmartLink Hub (kiosk)
Comment=Opens the DMXSmartLink hub full screen on this Pi's screen
Exec=/usr/local/bin/dmxsmartlink-kiosk
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF_DESK
  log "    ✓ Kiosk installed: the hub opens full screen at boot (Settings → KIOSK_ENABLED turns it off)"
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
  log "STEP 10b: Configuring sudoers for updater launcher..."
  # Allows the web UI "Update Now" flow to invoke the root-owned update launcher.
  local SUDO_FILE="/etc/sudoers.d/dmx-updater"
  cat > "$SUDO_FILE" <<EOF
$USER_NAME ALL=(root) NOPASSWD: $ROOT_UPDATE_LAUNCHER
EOF
  chmod 440 "$SUDO_FILE"
  visudo -cf "$SUDO_FILE" || true
  echo
}

install_root_update_helpers() {
  log "------------------------------------------------------"
  log "STEP 10c: Installing root-owned update helpers..."

  if [[ ! -f "$TARGET_DIR/upgrade_pi5.sh" ]]; then
    log "    ⚠ upgrade_pi5.sh not found in $TARGET_DIR, skipping root updater helper install"
    echo
    return
  fi

  install -o root -g root -m 755 "$TARGET_DIR/upgrade_pi5.sh" "$ROOT_UPDATE_WORKER"

  cat > "$ROOT_UPDATE_LAUNCHER" <<EOF
#!/bin/bash
set -Eeuo pipefail

TARGET_DIR="/home/$USER_NAME/dmxsmartlink"
WORKER="$ROOT_UPDATE_WORKER"
LOG_PATH="\$TARGET_DIR/logs/update_worker.log"
SYSTEMD_RUN_BIN="\$(command -v systemd-run || echo /usr/bin/systemd-run)"
export DMXSMARTLINK_USER="$USER_NAME"
export DMXSMARTLINK_HOME_DIR="/home/$USER_NAME"
export DMXSMARTLINK_TARGET_DIR="\$TARGET_DIR"

mkdir -p "\$TARGET_DIR/logs"
touch "\$LOG_PATH"
chown $USER_NAME:$USER_NAME "\$TARGET_DIR/logs" "\$LOG_PATH" 2>/dev/null || true

STAMP="\$(date '+%Y-%m-%d %H:%M:%S')"
printf '\n=== Update worker started %s ===\n' "\$STAMP" >> "\$LOG_PATH"

exec "\$SYSTEMD_RUN_BIN" \
  --unit "dmxsmartlink-update-\$(date +%s)" \
  --collect \
  --property "WorkingDirectory=\$TARGET_DIR" \
  /bin/bash -lc 'export DMXSMARTLINK_USER="$USER_NAME"; export DMXSMARTLINK_HOME_DIR="/home/$USER_NAME"; export DMXSMARTLINK_TARGET_DIR="/home/$USER_NAME/dmxsmartlink"; cd "/home/$USER_NAME/dmxsmartlink" && exec /usr/local/sbin/dmxsmartlink-root-update >> "/home/$USER_NAME/dmxsmartlink/logs/update_worker.log" 2>&1'
EOF

  chmod 755 "$ROOT_UPDATE_LAUNCHER"
  chown root:root "$ROOT_UPDATE_LAUNCHER"
  log "    ✓ Root-owned update worker installed at $ROOT_UPDATE_WORKER"
  log "    ✓ Root-owned update launcher installed at $ROOT_UPDATE_LAUNCHER"
  echo
}

install_govee_plugin() {
  log "------------------------------------------------------"
  log "STEP 10: Installing Govee plugin into Homebridge container (with BLE deps)..."

  # Install build/runtime deps for noble stack inside the container
  docker exec -u root -e DEBIAN_FRONTEND=noninteractive -e NEEDRESTART_MODE=a homebridge \
    bash -lc "apt-get update -yq && apt-get install -yq --no-install-recommends git curl bluetooth bluez libbluetooth-dev libudev-dev pi-bluetooth || true"

  # Install the plugin (BEST-EFFORT). The DMXSmartLink dashboard does NOT require the
  # Govee plugin to run, so a plugin/npm hiccup must never abort the whole install --
  # otherwise the dmxsmartlink service below never gets created. The Homebridge image's
  # bundled @matter/node trips npm ENOTEMPTY on a plain install, so use --legacy-peer-deps
  # and, on failure, a clean retry (drop the conflicting @matter + npm cache). Report
  # HONESTLY -- only claim success when the package is actually present.
  _govee_present() { docker exec homebridge sh -lc "test -f /var/lib/homebridge/node_modules/@homebridge-plugins/homebridge-govee/package.json"; }
  docker exec homebridge sh -lc "cd /var/lib/homebridge && npm install --save --no-audit --no-fund --legacy-peer-deps '$GOVEE_PLUGIN'" >/dev/null 2>&1 || true
  if ! _govee_present; then
    log "    First attempt failed (npm conflict); clean retry..."
    docker exec -u root homebridge sh -lc "cd /var/lib/homebridge && rm -rf node_modules/@matter node_modules/@homebridge-plugins/homebridge-govee 2>/dev/null; npm cache clean --force >/dev/null 2>&1; npm install --save --no-audit --no-fund --legacy-peer-deps '$GOVEE_PLUGIN'" >/dev/null 2>&1 || true
  fi
  if _govee_present; then
    # Give node cap_net_raw so noble can open HCI sockets if needed
    docker exec -u root homebridge bash -lc 'setcap cap_net_raw+eip "$(eval readlink -f "$(which node)")" || true' || true
    log "    ✓ Govee plugin installed."
  else
    log "    ⚠ Govee plugin install FAILED (non-fatal) — dashboard still runs; add it later from the Homebridge UI (Plugins → search 'Govee')."
  fi
  docker restart homebridge >/dev/null 2>&1 || true
  echo
}

write_service() {
  local workdir="/home/$USER_NAME/dmxsmartlink"
  local exec_start venv_path

  if [[ -f "$workdir/main.dist/main.bin" ]]; then
    # Nuitka standalone build â€” run the self-contained binary directly (no venv).
    exec_start="$workdir/main.dist/main.bin"
    venv_path=""
  else
    # PyArmor build â€” run the obfuscated app under the venv interpreter.
    exec_start="$workdir/.venv/bin/python $workdir/main.py"
    venv_path="$workdir/.venv/bin:"
  fi

  log "------------------------------------------------------"
  log "STEP 11: Creating systemd service at $SERVICE_FILE..."
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=DMXSmartLink Dashboard Service
# time-sync.target matters on a Raspberry Pi: it has no RTC, so systemd restores the clock from
# fake-hwclock at boot and timesyncd then STEPS it to real time once the network is up -- by the
# length of the downtime. Starting before that step lands means any wall-clock duration measured
# across it is wrong. Wants= (not Requires=) so a hub with no internet still starts.
After=network.target time-sync.target docker.service
Wants=time-sync.target
Requires=docker.service

[Service]
User=$USER_NAME
WorkingDirectory=$workdir
ExecStartPre=/usr/bin/docker pull homebridge/homebridge
ExecStart=$exec_start
Restart=always
RestartSec=5
UMask=0002
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=$workdir
Environment=PATH=${venv_path}/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

[Install]
WantedBy=multi-user.target
EOF

  # Headless-safe audio: ensure a user PipeWire/Pulse session exists for the service user even
  # without a graphical login. Without it pw-cat/parec/pactl have no server and the media /
  # light-show audio pipeline is silent (confirmed on headless Ubuntu 24.04, 2026-07-03). Harmless
  # on the Pi (its desktop session already runs PipeWire; enable --now is then a no-op).
  loginctl enable-linger "$USER_NAME" 2>/dev/null || true
  _pw_uid="$(id -u "$USER_NAME" 2>/dev/null || echo '')"
  if [ -n "$_pw_uid" ]; then
    sudo -u "$USER_NAME" XDG_RUNTIME_DIR="/run/user/$_pw_uid" \
      systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
  fi

  systemctl daemon-reload
  systemctl enable dmxsmartlink.service
  systemctl restart dmxsmartlink.service
  echo
}

configure_passwordless_sudo() {
  log "------------------------------------------------------"
  log "STEP 12: Configuring passwordless sudo for service control..."

  local sudoers_file="/etc/sudoers.d/dmxsmartlink-restart"
  local expected_stop="$USER_NAME ALL=(ALL) NOPASSWD: /bin/systemctl stop dmxsmartlink.service"
  local expected_start="$USER_NAME ALL=(ALL) NOPASSWD: /bin/systemctl start dmxsmartlink.service"
  local expected_restart="$USER_NAME ALL=(ALL) NOPASSWD: /bin/systemctl restart dmxsmartlink.service"

  # Check if entries already exist
  if [ -f "$sudoers_file" ] && grep -qF "$expected_stop" "$sudoers_file" 2>/dev/null && grep -qF "$expected_start" "$sudoers_file" 2>/dev/null && grep -qF "$expected_restart" "$sudoers_file" 2>/dev/null; then
    log "    âœ“ Passwordless sudo already configured"
  else
    cat > "$sudoers_file" <<EOF
$expected_stop
$expected_start
$expected_restart
EOF
    chmod 0440 "$sudoers_file"
    log "    âœ“ Passwordless sudo configured for: systemctl stop/start/restart dmxsmartlink.service"
  fi
  echo
}

setup_reboot_sudoers() {
  log "------------------------------------------------------"
  log "STEP 12b: Configuring passwordless sudo for OS reboot..."

  local sudoers_file="/etc/sudoers.d/dmx-reboot"
  local expected_line="$USER_NAME ALL=(root) NOPASSWD: /usr/sbin/reboot, /sbin/reboot, /usr/bin/reboot, /bin/reboot"

  if [ -f "$sudoers_file" ] && grep -qF "$expected_line" "$sudoers_file" 2>/dev/null; then
    log "    ✓ Passwordless sudo already configured for reboot"
  else
    cat > "$sudoers_file" <<EOF
$expected_line
EOF
    chmod 0440 "$sudoers_file"
    visudo -cf "$sudoers_file" || true
    log "    ✓ Passwordless sudo configured for OS reboot"
  fi
  echo
}

# ========================== MAIN ==========================
log "âœ… STEP 1: Detected script directory: $SCRIPT_DIR (user = $USER_NAME)"

# Prerequisites-only mode: install just the runtime OS packages a fresh install
# would (base tooling + host Bluetooth/BLE), then exit. The Nuitka-conversion
# updater (upgrade_pi5.sh) invokes this so an old client picks up prerequisites
# its original install never had: the standalone binary bundles Python but still
# needs the system audio (portaudio/pipewire/ffmpeg) and BLE (bluez) packages at
# runtime. Idempotent (apt no-ops when already present); must run as root for apt.
if [[ "${1:-}" == "--prereqs-only" ]]; then
  if [[ "$(id -u)" -ne 0 ]]; then
    log "ERROR: --prereqs-only must run as root (apt installs)."
    exit 1
  fi
  log "Prerequisites-only mode: installing runtime OS prerequisites..."
  ensure_base_tooling
  install_ble_support_host
  log "Prerequisites installed."
  exit 0
fi

# --test-channel (dev only): install from the newest GitHub PRE-RELEASE instead of the
# public 'latest', and leave the box dev-enabled + pinned to the test channel (copy_project
# reads DMXSMARTLINK_CHANNEL and writes the markers). Scanned across all args so it can sit
# anywhere; equivalent to exporting DMXSMARTLINK_CHANNEL=test.
for _arg in "$@"; do
  if [[ "$_arg" == "--test-channel" ]]; then
    export DMXSMARTLINK_CHANNEL="test"
    log "Test channel selected: installing the newest pre-release (dev mode)."
  fi
done

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
  log "âŒ ERROR: main.py not found in $TARGET_DIR after download"
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
ensure_home_assistant           # Home Assistant + Matter Server containers (hub onboards HA itself)
write_service
configure_passwordless_sudo     # Allow service user to restart service without password
setup_reboot_sudoers            # Allow UI reboot without broad sudo access
setup_audio_sudoers             # Allow bluetoothctl/pactl for UI
install_root_update_helpers     # Install root-owned update launcher/worker
setup_update_sudoers            # Allow Update Now launcher without broad sudo access
setup_network_sudoers           # Wi-Fi / Ethernet control from the web UI (nmcli, rfkill)
install_kiosk                   # Pi with a screen: browser opens the hub full screen at boot

log "âœ… All steps complete."
log "Service status (last 30 lines):"
systemctl --no-pager -n 30 status dmxsmartlink.service || true
