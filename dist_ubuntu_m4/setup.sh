#!/bin/bash
# setup.sh — DMXSmartLink installer (flat layout, Raspberry Pi OS/Ubuntu)
# - Uses any installed Python 3.x for the venv
# - No CPython-from-source builds
# - venv-only installs (PEP-668 safe)
# - Installs Flask, requests, PyJWT[crypto], PyArmor
# - Copies flat project (incl. pyarmor_runtime_000000/)
# - Regenerates PyArmor runtime for Python 3.x
# - Verifies obfuscated payload imports under Python 3.x
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

require_entrypoint() {
  if [[ -f "$SCRIPT_DIR/main.py" ]]; then
    echo "main.py"
  else
    echo "ERROR: main.py not found in $SCRIPT_DIR" >&2
    exit 1
  fi
}

copy_project() {
  log "✅ STEP 2: Ensuring target folder: $TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  chown "$USER_NAME:$USER_NAME" "$TARGET_DIR"

  log "    Copying selected files/folders into $TARGET_DIR..."
  local items=(
    artnet_controller.py config.py device_inventory.py group_init.py group_manager.py main.py
    license_status.txt HOMEBRIDGE_LICENSE.txt LICENSE.txt README.txt
    pyarmor_runtime_000000
  )
  for it in "${items[@]}"; do
    [[ -e "$SCRIPT_DIR/$it" ]] || { log "    - $it not found, skipping."; continue; }
    if [[ -d "$SCRIPT_DIR/$it" ]]; then
      rm -rf "$TARGET_DIR/$it"
      cp -a "$SCRIPT_DIR/$it" "$TARGET_DIR/"
    else
      cp -a "$SCRIPT_DIR/$it" "$TARGET_DIR/"
    fi
  done

  chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR"
  find "$TARGET_DIR" -type d -exec chmod 775 {} \;
  find "$TARGET_DIR" -type f -exec chmod 664 {} \;

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
  apt_install python3 python3-venv python3-pip curl ca-certificates build-essential wget openssl
  echo
}

# ---------- Host-side BLE prerequisites (Pi 5 / Raspberry Pi OS / Ubuntu) ----------
install_ble_support_host() {
  log "------------------------------------------------------"
  log "STEP 4b: Installing host Bluetooth / BLE dependencies..."
  # These follow the Homebridge Bluetooth wiki recommendations.
  # pi-bluetooth will simply be ignored on non-Raspberry Pi distros.
  apt_update
  apt_install bluetooth bluez libbluetooth-dev libudev-dev || true
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
    pip install -U Flask requests 'PyJWT[crypto]' pyarmor pyarmor.cli.core
  "
  echo
}

regenerate_pyarmor_runtime_py313() {
  log "------------------------------------------------------"
  log "STEP 7: Regenerating PyArmor runtime for Python 3.x and replacing any mismatched runtime…"
  sudo -u "$USER_NAME" bash -lc "
    set -e
    cd '$TARGET_DIR'
    source .venv/bin/activate
    pyarmor gen runtime -O build/runtime_local || true
    if [ -d build/runtime_local/pyarmor_runtime_000000 ]; then
      rm -rf pyarmor_runtime_000000
      cp -a build/runtime_local/pyarmor_runtime_000000 .
    fi
  "
  chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR"
  find "$TARGET_DIR" -type d -exec chmod 775 {} \;
  find "$TARGET_DIR" -type f -exec chmod 664 {} \;
  echo
}

verify_import_under_python() {
  log "------------------------------------------------------"
  log "STEP 8: Verifying obfuscated payload imports under Python 3.x…"
  "$TARGET_DIR/.venv/bin/python" - <<PY
import sys, importlib, traceback
sys.path.insert(0, "$TARGET_DIR")
print("    Running import test under:", sys.version)
try:
    importlib.import_module("main")
    print("✅ IMPORT_OK: main imports under Python", sys.version)
except RuntimeError as e:
    s = str(e)
    print("❌ IMPORT_FAIL:", s)
    if "this Python version is not supported" in s:
        print("HINT: These files were likely obfuscated for a different Python minor.")
        print("      This installer is pinned to Python 3.x; make sure the obfuscation target matches.")
        raise SystemExit(3)
    raise
except Exception as e:
    print("❌ IMPORT_FAIL:", repr(e))
    traceback.print_exc()
    raise
PY
  echo
}

add_user_to_docker() {
  log "------------------------------------------------------"
  log "STEP 9: Adding user '$USER_NAME' to the docker group..."
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
  log "STEP 10: Pulling Homebridge Docker image..."
  if ! command -v docker >/dev/null 2>&1; then
    echo "❌ docker CLI not found; install_docker must succeed before this step."
    exit 11
  fi
  docker pull homebridge/homebridge
  echo

  log "------------------------------------------------------"
  log "STEP 11: Starting Homebridge container on ports 8581/9000 with BLE support..."
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

install_govee_plugin() {
  log "------------------------------------------------------"
  log "STEP 12: Installing Govee plugin into Homebridge container (with BLE deps)..."

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
  log "STEP 13: Creating systemd service at $SERVICE_FILE..."
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

# ========================== MAIN ==========================
log "✅ STEP 1: Detected script directory: $SCRIPT_DIR (user = $USER_NAME)"
echo

ENTRYPOINT_REL="$(require_entrypoint)"
copy_project
ensure_base_tooling
install_ble_support_host        # Host-side BLE support (Pi OS + Ubuntu)
ensure_python
create_venv_and_install
regenerate_pyarmor_runtime_py313
verify_import_under_python
install_docker
add_user_to_docker
start_homebridge                # Starts with DBus exposed into container
install_govee_plugin            # Installs plugin + BLE deps + setcap inside container
write_service

log "✅ All steps complete."
log "Service status (last 30 lines):"
systemctl --no-pager -n 30 status dmxsmartlink.service || true
