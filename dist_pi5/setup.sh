#!/bin/bash
# setup.sh — DMXSmartLink installer (flat layout, Raspberry Pi OS/Ubuntu)
# - Uses ONLY Python 3.12 (builds CPython 3.12.6 if missing)
# - venv-only installs (PEP-668 safe)
# - Installs Flask, requests, PyJWT[crypto], PyArmor
# - Copies flat project (incl. pyarmor_runtime_000000/)
# - Regenerates PyArmor runtime for py312
# - Verifies obfuscated payload imports under py312
# - Installs Docker (+ fallback via get.docker.com) + Homebridge + Govee plugin
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

# ---------------- CPython 3.12 ----------------
PY_PREFIX="/usr/local"
PY312_VER="3.12.6"
PY312_BIN="$PY_PREFIX/bin/python3.12"

# ---------------- Custom Govee plugin repo ----------------
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

  # Enable and start Docker
  systemctl enable docker
  systemctl start docker

  # Final verification
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
  log "STEP 4: Installing base tooling (venv + build deps for CPython if needed)..."
  apt_update
  apt_install python3 python3-venv python3-pip curl ca-certificates build-essential wget openssl
  echo
}

build_cpython312_if_needed() {
  if command -v "$PY312_BIN" >/dev/null 2>&1; then
    log "Found $("$PY312_BIN" -V) — will use this for the venv."
    return 0
  fi

  log "------------------------------------------------------"
  log "STEP 5: Building Python ${PY312_VER} from source (not found on system)…"
  apt_update
  apt_install \
    libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
    libreadline-dev libsqlite3-dev libffi-dev libbz2-dev liblzma-dev \
    tk-dev uuid-dev

  local td
  td="$(mktemp -d)"
  pushd "$td" >/dev/null
  wget -q "https://www.python.org/ftp/python/${PY312_VER}/Python-${PY312_VER}.tgz"
  tar xf "Python-${PY312_VER}.tgz"
  cd "Python-${PY312_VER}"
  ./configure --prefix="$PY_PREFIX" --enable-optimizations --with-ensurepip=install
  make -j"$(nproc)"
  make altinstall
  popd >/dev/null
  rm -rf "$td"

  if ! command -v "$PY312_BIN" >/dev/null 2>&1; then
    echo "❌ Failed to install Python ${PY312_VER}"
    exit 2
  fi
  log "✅ Installed $("$PY312_BIN" -V)"
  echo
}

create_venv_and_install() {
  log "------------------------------------------------------"
  log "STEP 6: Creating venv on Python 3.12 and installing deps…"
  sudo -u "$USER_NAME" bash -lc "
    set -e
    cd '$TARGET_DIR'
    rm -rf .venv
    '$PY312_BIN' -m venv .venv
    source .venv/bin/activate
    pip install -U pip
    pip install -U Flask requests 'PyJWT[crypto]' pyarmor pyarmor.cli.core
  "
  echo
}

regenerate_pyarmor_runtime_py312() {
  log "------------------------------------------------------"
  log "STEP 7: Regenerating PyArmor runtime for Python 3.12 and replacing any mismatched runtime…"
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

verify_import_under_312() {
  log "------------------------------------------------------"
  log "STEP 8: Verifying obfuscated payload imports under Python 3.12…"
  "$TARGET_DIR/.venv/bin/python" - <<PY
import sys, importlib, traceback
sys.path.insert(0, "$TARGET_DIR")
try:
    importlib.import_module("main")
    print("✅ IMPORT_OK: main imports under Python 3.12")
except RuntimeError as e:
    s = str(e)
    print("❌ IMPORT_FAIL:", s)
    if "this Python version is not supported" in s:
        print("HINT: These files were likely obfuscated for a different Python minor (e.g., 3.11 or 3.13).")
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

start_homebridge() {
  log "------------------------------------------------------"
  log "STEP 10: Pulling Homebridge Docker image..."
  if ! command -v docker >/dev/null 2%; then
    echo "❌ docker CLI not found; install_docker must succeed before this step."
    exit 11
  fi
  docker pull homebridge/homebridge
  echo

  log "------------------------------------------------------"
  log "STEP 11: Starting Homebridge container on ports 8581/9000..."
  mkdir -p "$CONFIG_DIR"
  chown "$USER_NAME:$USER_NAME" "$CONFIG_DIR"

  if docker ps -a --format '{{.Names}}' | grep -q '^homebridge$'; then
    log "Existing 'homebridge' container found; removing to recreate..."
    docker rm -f homebridge || true
  fi

  docker run -d \
    --name homebridge \
    --restart=always \
    -p 8581:8581 \
    -p 9000:9000 \
    -v "$CONFIG_DIR":/homebridge \
    homebridge/homebridge

  log "    → Homebridge container started."
  log "    → Visit http://<your-pi-ip>:8581 to finish Homebridge setup."
  echo
  sleep 5
}

install_govee_plugin() {
  log "------------------------------------------------------"
  log "STEP 12: Installing custom Govee plugin from Git into Homebridge container..."
  docker exec -u root -e DEBIAN_FRONTEND=noninteractive -e NEEDRESTART_MODE=a homebridge \
    bash -lc "apt-get update -yq && apt-get install -yq --no-install-recommends git curl || true" || true
  docker exec homebridge bash -lc "cd /homebridge && npm install '$GOVEE_REPO' || true"
  docker exec homebridge bash -lc "cd /homebridge && npm ls --depth=0 || true"
  docker restart homebridge >/dev/null
  log "    → Custom Govee plugin installed and Homebridge restarted."
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
build_cpython312_if_needed
create_venv_and_install
regenerate_pyarmor_runtime_py312
verify_import_under_312
install_docker
add_user_to_docker
start_homebridge
install_govee_plugin
write_service

log "✅ All steps complete."
log "Service status (last 30 lines):"
systemctl --no-pager -n 30 status dmxsmartlink.service || true
