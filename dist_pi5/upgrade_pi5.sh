#!/bin/bash
# upgrade_pi5.sh â€” DMXSmartLink upgrade script for Raspberry Pi 5
# Run from: /home/dmx/ (or dmx user's home directory)
# Usage: sudo bash upgrade_pi5.sh
# - Updates code files from latest GitHub release
# - Preserves configuration files (config.json, devices.json, groups.json, license files, etc.)
# - Updates Python dependencies if needed
# - Updates Homebridge container and Govee plugin
# - Does NOT reinstall Docker or system packages (assumes already installed)
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
# Detect user/paths from explicit environment first, then fall back to cwd.
if [[ -n "${DMXSMARTLINK_USER:-}" ]]; then
  USER_NAME="$DMXSMARTLINK_USER"
elif [[ "$(pwd)" == /home/*/dmxsmartlink* ]]; then
  USER_NAME="$(basename "$(dirname "$(pwd)")")"
elif [[ "$(pwd)" == /home/* ]]; then
  USER_NAME="$(basename "$(pwd)")"
else
  USER_NAME="${SUDO_USER:-${USER:-dmx}}"
fi
HOME_DIR="${DMXSMARTLINK_HOME_DIR:-/home/$USER_NAME}"
TARGET_DIR="${DMXSMARTLINK_TARGET_DIR:-$HOME_DIR/dmxsmartlink}"
CONFIG_DIR="$HOME_DIR/homebridge-config"
SYSTEMCTL_BIN="$(command -v systemctl || echo /bin/systemctl)"
REBOOT_BIN="$(command -v reboot || echo /usr/sbin/reboot)"
ROOT_UPDATE_WORKER="/usr/local/sbin/dmxsmartlink-root-update"
ROOT_UPDATE_LAUNCHER="/usr/local/sbin/dmxsmartlink-update-launcher"
SERVICE_STOPPED=0
RESTART_DONE=0

detect_dist_dir() {
  if [[ -f "$TARGET_DIR/.install_arch" ]]; then
    local saved_arch
    saved_arch="$(cat "$TARGET_DIR/.install_arch" 2>/dev/null || true)"
    if [[ -n "$saved_arch" ]]; then
      echo "$saved_arch"
      return
    fi
  fi

  local arch
  arch="$(uname -m 2>/dev/null || echo '')"
  if [[ "$arch" == "x86_64" ]]; then
    echo "dist_ubuntu_intel"
    return
  fi

  if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
    local model=""
    if [[ -r /proc/device-tree/model ]]; then
      model="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"
    fi
    if echo "$model" | grep -qi "Raspberry Pi"; then
      echo "dist_pi5"
    else
      echo "dist_ubuntu_m4"
    fi
    return
  fi

  echo "dist_pi5"
}

DIST_DIR="$(detect_dist_dir)"

# ---------------- Official Govee plugin repo ----------------
GOVEE_PLUGIN="@homebridge-plugins/homebridge-govee@latest"
GOVEE_REPO="github:homebridge-plugins/homebridge-govee#latest"

# Files to preserve during upgrade (same as in main.py)
PRESERVE_FILES=(
  "config.json"
  "devices.json"
  "groups.json"
  "license_status.txt"
  "cert.pem"
  "key.pem"
  "artnet.log"
  "artnet.pid"
  "update_settings.json"
  "logging_settings.json"
  ".install_arch"
  "HOMEBRIDGE_LICENSE.txt"
  "LICENSE.txt"
)

log() { echo -e "$*" >&2; }

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

refresh_root_update_worker_from_release() {
  local SRC_DIR="$1"
  local worker_src="$SRC_DIR/upgrade_pi5.sh"

  if [[ -f "$worker_src" ]]; then
    install -o root -g root -m 755 "$worker_src" "$ROOT_UPDATE_WORKER" || true
    log "    Refreshed root update worker at $ROOT_UPDATE_WORKER"
  fi
}

refresh_root_update_launcher() {
  cat > "$ROOT_UPDATE_LAUNCHER" <<EOF
#!/bin/bash
set -Eeuo pipefail

TARGET_DIR="$TARGET_DIR"
WORKER="$ROOT_UPDATE_WORKER"
LOG_PATH="\$TARGET_DIR/logs/update_worker.log"
SYSTEMD_RUN_BIN="\$(command -v systemd-run || echo /usr/bin/systemd-run)"
export DMXSMARTLINK_USER="$USER_NAME"
export DMXSMARTLINK_HOME_DIR="$HOME_DIR"
export DMXSMARTLINK_TARGET_DIR="$TARGET_DIR"

mkdir -p "\$TARGET_DIR/logs"
touch "\$LOG_PATH"
chown $USER_NAME:$USER_NAME "\$TARGET_DIR/logs" "\$LOG_PATH" 2>/dev/null || true

STAMP="\$(date '+%Y-%m-%d %H:%M:%S')"
printf '\n=== Update worker started %s ===\n' "\$STAMP" >> "\$LOG_PATH"

exec "\$SYSTEMD_RUN_BIN" \
  --unit "dmxsmartlink-update-\$(date +%s)" \
  --collect \
  --property "WorkingDirectory=\$TARGET_DIR" \
  /bin/bash -lc 'export DMXSMARTLINK_USER="$USER_NAME"; export DMXSMARTLINK_HOME_DIR="$HOME_DIR"; export DMXSMARTLINK_TARGET_DIR="$TARGET_DIR"; cd "$TARGET_DIR" && exec /usr/local/sbin/dmxsmartlink-root-update >> "$TARGET_DIR/logs/update_worker.log" 2>&1'
EOF

  chmod 755 "$ROOT_UPDATE_LAUNCHER"
  chown root:root "$ROOT_UPDATE_LAUNCHER"
  log "    Refreshed root update launcher at $ROOT_UPDATE_LAUNCHER"
}

ensure_reboot_sudoers() {
  local sudoers_file="/etc/sudoers.d/dmx-reboot"
  local expected_line="$USER_NAME ALL=(root) NOPASSWD: /usr/sbin/reboot, /sbin/reboot, /usr/bin/reboot, /bin/reboot"

  if [[ -f "$sudoers_file" ]] && grep -qF "$expected_line" "$sudoers_file" 2>/dev/null; then
    log "    Reboot sudoers already configured"
    return
  fi

  cat > "$sudoers_file" <<EOF
$expected_line
EOF
  chmod 440 "$sudoers_file"
  visudo -cf "$sudoers_file" >/dev/null 2>&1 || true
  log "    Configured reboot sudoers at $sudoers_file"
}

stop_service_for_upgrade() {
  log "------------------------------------------------------"
  log "STEP 1b: Stopping DMXSmartLink service before file sync..."

  if "$SYSTEMCTL_BIN" is-active --quiet dmxsmartlink.service 2>/dev/null; then
    "$SYSTEMCTL_BIN" stop dmxsmartlink.service
    SERVICE_STOPPED=1
    log "    Ã¢Å“â€œ dmxsmartlink.service stopped"
  else
    log "    Ã¢Å¡Â  dmxsmartlink.service was not active"
  fi
  echo
}

cleanup_on_exit() {
  local rc=$?
  if [[ $SERVICE_STOPPED -eq 1 && $RESTART_DONE -eq 0 ]]; then
    log "    Ã¢Å¡Â  Upgrade exited early, attempting to bring dmxsmartlink.service back up..."
    if "$SYSTEMCTL_BIN" start dmxsmartlink.service >/dev/null 2>&1; then
      log "    Ã¢Å“â€œ dmxsmartlink.service restarted after interrupted upgrade"
    else
      log "    Ã¢ÂÅ’ Could not restart dmxsmartlink.service automatically after interrupted upgrade"
    fi
  fi
  trap - EXIT
  exit "$rc"
}

trap cleanup_on_exit EXIT

# Check if installation exists
check_installation() {
  if [[ ! -d "$TARGET_DIR" ]]; then
    log "âŒ DMXSmartLink installation not found at $TARGET_DIR"
    log "    Please run setup.sh first to install DMXSmartLink."
    exit 1
  fi
  
  if [[ ! -f "$TARGET_DIR/main.py" ]]; then
    log "âŒ DMXSmartLink installation appears incomplete (main.py not found)"
    log "    Please run setup.sh to reinstall."
    exit 1
  fi
  
  log "âœ“ Found existing installation at $TARGET_DIR"
}

# Download and extract latest release
download_release() {
  local TEMP_DIR="/tmp/dmxsmartlink-upgrade-$$"
  local ZIP_PATH="/tmp/dmxsmartlink-release-$$.zip"
  local GITHUB_REPO="WhiteCrowSecurity/DMXSmartLink"
  
  rm -rf "$TEMP_DIR" "$ZIP_PATH"
  mkdir -p "$TEMP_DIR"
  
  log "    Using architecture: $DIST_DIR"
  log "    Fetching latest release zip..."
  
  # Try GitHub API first
  local API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
  local REL_JSON=""
  local API_ERROR=""
  if command -v curl >/dev/null 2>&1; then
    if ! REL_JSON="$(curl -fsSL "$API_URL" 2>/dev/null)"; then
      log "    Latest release lookup failed, trying tag 'DMXSmartLink'..."
      API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/tags/DMXSmartLink"
      if ! REL_JSON="$(curl -fsSL "$API_URL" 2>/dev/null)"; then
        API_ERROR="api_failed"
      fi
    fi
  else
    API_ERROR="no_curl"
  fi
  
  local DOWNLOAD_URL=""
  if [[ -z "$API_ERROR" ]] && [[ -n "$REL_JSON" ]] && command -v python3 >/dev/null 2>&1; then
    DOWNLOAD_URL="$(
      printf '%s' "$REL_JSON" | python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read() or "{}")
    if isinstance(d, dict) and d.get("message"):
        print("")
        raise SystemExit(0)

    assets = d.get("assets") or []
    for asset in assets:
        url = asset.get("browser_download_url", "") or ""
        name = (asset.get("name", "") or "").lower()
        if "dmxsmartlink" in name and name.endswith(".zip") and url:
            print(url)
            raise SystemExit(0)

    for asset in assets:
        url = asset.get("browser_download_url", "") or ""
        name = asset.get("name", "") or ""
        if (url.endswith(".zip") or name.endswith(".zip")) and url:
            print(url)
            raise SystemExit(0)

    print(d.get("zipball_url", "") or "")
except Exception:
    print("")
' 2>/dev/null
    )"
  fi
  
  # Fallback to direct download
  if [[ -z "$DOWNLOAD_URL" ]] || [[ "$DOWNLOAD_URL" == "" ]]; then
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/dmxsmartlink.zip"
  fi
  
  log "    Downloading release..."
  if ! curl -fL "$DOWNLOAD_URL" -o "$ZIP_PATH" 2>/dev/null; then
    log "âŒ Failed to download release zip"
    rm -rf "$TEMP_DIR" "$ZIP_PATH"
    exit 1
  fi
  
  if ! extract_zip_allowing_warnings "$ZIP_PATH" "$TEMP_DIR"; then
    log "âŒ Failed to extract zip file"
    rm -rf "$TEMP_DIR" "$ZIP_PATH"
    exit 1
  fi
  
  # Find extracted directory (same logic as setup.sh)
  local ROOT_DIR
  ROOT_DIR="$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  local SRC_DIR=""
  
  if [[ -n "$ROOT_DIR" ]] && [[ -d "$ROOT_DIR/$DIST_DIR" ]]; then
    SRC_DIR="$ROOT_DIR/$DIST_DIR"
    log "    Using extracted release folder: $SRC_DIR"
  elif [[ -d "$TEMP_DIR/$DIST_DIR" ]]; then
    SRC_DIR="$TEMP_DIR/$DIST_DIR"
    log "    Using extracted release folder (direct): $SRC_DIR"
  else
    log "âŒ Directory $DIST_DIR not found in extracted zip"
    log "    Available directories in temp: $(ls -1 "$TEMP_DIR" 2>/dev/null | head -5 | tr '\n' ' ' || echo 'none')"
    if [[ -n "$ROOT_DIR" ]]; then
      log "    Root dir contents: $(ls -1 "$ROOT_DIR" 2>/dev/null | head -10 | tr '\n' ' ' || echo 'none')"
    fi
    rm -rf "$TEMP_DIR" "$ZIP_PATH"
    exit 1
  fi
  
  # Verify SRC_DIR exists and log contents for debugging
  if [[ ! -d "$SRC_DIR" ]]; then
    log "âŒ Source directory $SRC_DIR does not exist"
    rm -rf "$TEMP_DIR" "$ZIP_PATH"
    exit 1
  fi
  
  log "    Source directory verified: $SRC_DIR"
  log "    Contents: $(ls -1 "$SRC_DIR" 2>/dev/null | head -10 | tr '\n' ' ' || echo 'empty')"
  
  echo "$SRC_DIR"
}

# Upgrade files while preserving configuration
upgrade_files() {
  local SRC_DIR="$1"
  
  log "    Syncing all release files from $DIST_DIR into $TARGET_DIR..."
  if ! command -v rsync >/dev/null 2>&1; then
    apt_update
    apt_install rsync
  fi

  # Copy the full release payload, but never touch the existing venv or
  # generated caches. User/project data not present in the release is left
  # alone because we intentionally do not use --delete here.
  rsync -a \
    --exclude=".venv/" \
    --exclude="__pycache__/" \
    --exclude=".install_arch" \
    "$SRC_DIR/" "$TARGET_DIR/"
  
  # Save architecture marker for future upgrades
  echo "$DIST_DIR" > "$TARGET_DIR/.install_arch"
  chown "$USER_NAME:$USER_NAME" "$TARGET_DIR/.install_arch"
  
  # Set permissions
  chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR"
  find "$TARGET_DIR" -type d -exec chmod 775 {} \;
  find "$TARGET_DIR" -type f -exec chmod 664 {} \;
  find "$TARGET_DIR" -name "*.so" -exec chmod 755 {} \;
  
  log "    âœ“ Files updated successfully"
}
# Update Python dependencies
update_python_deps() {
  log "------------------------------------------------------"
  log "STEP 2: Updating Python dependencies..."
  
  if [[ ! -d "$TARGET_DIR/.venv" ]]; then
    log "    âš  Virtual environment not found, creating new one..."
    if ! command -v python3 >/dev/null 2>&1; then
      log "âŒ Python 3 not found"
      exit 2
    fi
    sudo -u "$USER_NAME" bash -lc "
      set -e
      cd '$TARGET_DIR'
      python3 -m venv .venv
      source .venv/bin/activate
      pip install -U pip
      pip install -U Flask requests 'PyJWT[crypto]' pyarmor pyarmor.cli.core pyserial
    "
  else
    log "    Updating packages in existing virtual environment..."
    if [[ -f "$TARGET_DIR/.venv/bin/python" ]]; then
      "$TARGET_DIR/.venv/bin/python" -m pip install -U pip setuptools wheel >/dev/null 2>&1 || true
      "$TARGET_DIR/.venv/bin/pip" install -U Flask requests 'PyJWT[crypto]' pyarmor pyarmor.cli.core pyserial >/dev/null 2>&1 || true
      log "    âœ“ Dependencies updated"
    else
      log "    âš  Virtual environment python not found at $TARGET_DIR/.venv/bin/python"
    fi
  fi
  
  chmod -R +x "$TARGET_DIR/.venv/bin" 2>/dev/null || true
  chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR/.venv" 2>/dev/null || true
  log "    âœ“ Python dependencies updated"
  echo
}

# Update Homebridge container and Govee plugin
update_homebridge() {
  log "------------------------------------------------------"
  log "STEP 3: Updating Homebridge container and Govee plugin..."
  
  if ! command -v docker >/dev/null 2>&1; then
    log "    âš  Docker not found, skipping Homebridge update"
    return
  fi
  
  # Pull latest Homebridge image
  docker pull homebridge/homebridge >/dev/null 2>&1 || true
  
  # Find existing container
  local container_name
  container_name="$(docker ps -a --format '{{.Names}}' | grep -i homebridge | head -n1 || true)"
  
  if [[ -z "$container_name" ]]; then
    log "    âš  Homebridge container not found, skipping update"
    return
  fi
  
  log "    Found Homebridge container: $container_name"
  
  # Stop container
  docker stop "$container_name" >/dev/null 2>&1 || true
  
  # Get container config
  local image
  local restart_policy
  local network_mode
  local binds
  local env_vars
  
  image="$(docker inspect -f '{{.Config.Image}}' "$container_name" 2>/dev/null || echo "homebridge/homebridge")"
  if [[ "$image" == homebridge/homebridge* ]]; then
    image="homebridge/homebridge"
  fi
  restart_policy="$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$container_name" 2>/dev/null || echo "always")"
  network_mode="$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$container_name" 2>/dev/null || echo "host")"
  
  # Extract volume mounts with options (e.g., :ro)
  binds=()
  local mounts_json
  mounts_json="$(docker inspect -f '{{json .Mounts}}' "$container_name" 2>/dev/null || echo "[]")"
  if command -v python3 >/dev/null 2>&1 && [[ "$mounts_json" != "[]" ]]; then
    while IFS= read -r mount_spec; do
      if [[ -n "$mount_spec" ]] && [[ "$mount_spec" != "null" ]]; then
        binds+=("-v" "$mount_spec")
      fi
    done < <(python3 -c "
import json, sys
try:
    mounts = json.load(sys.stdin)
    for m in mounts:
        src = m.get('Source', '')
        dst = m.get('Destination', '')
        opts = []
        if m.get('RW') == False:
            opts.append('ro')
        if opts:
            print(f\"{src}:{dst}:{':'.join(opts)}\")
        else:
            print(f\"{src}:{dst}\")
except:
    pass
" <<< "$mounts_json" 2>/dev/null || true)
  fi
  
  # Extract environment variables (skip PATH, HOME, etc.)
  env_vars=()
  while IFS= read -r env; do
    if [[ -n "$env" ]] && [[ "$env" != PATH=* ]] && [[ "$env" != HOME=* ]]; then
      env_vars+=("-e" "$env")
    fi
  done < <(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$container_name" 2>/dev/null | grep -v '^$' || true)
  
  # Remove old container
  docker rm "$container_name" >/dev/null 2>&1 || true
  
  # Recreate container with same config
  if ! docker run -d \
    --name "$container_name" \
    --restart="$restart_policy" \
    --network="$network_mode" \
    "${binds[@]}" \
    "${env_vars[@]}" \
    "$image" >/dev/null 2>&1; then
    # If recreation failed, try with debug output
    log "    âš  Failed to recreate Homebridge container, trying with basic config..."
    # Fallback: try recreating with just the config directory (most important mount)
    if [[ -d "$CONFIG_DIR" ]]; then
      if docker run -d \
        --name "$container_name" \
        --restart="$restart_policy" \
        --network="$network_mode" \
        -v "$CONFIG_DIR:/homebridge" \
        "$image" >/dev/null 2>&1; then
        log "    âœ“ Homebridge container recreated with basic config"
      else
        log "    âŒ Failed to recreate container even with basic config"
        return
      fi
    else
      log "    âŒ Config directory $CONFIG_DIR not found"
      return
    fi
  else
    log "    âœ“ Homebridge container recreated"
  fi
  
  # Install Govee plugin (only if container exists)
  if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    log "    Installing/updating Govee plugin..."
    docker exec -u root -e DEBIAN_FRONTEND=noninteractive -e NEEDRESTART_MODE=a "$container_name" \
      bash -lc "apt-get update -yq && apt-get install -yq --no-install-recommends git curl bluetooth bluez libbluetooth-dev libudev-dev pi-bluetooth || true" >/dev/null 2>&1 || true
    
    docker exec "$container_name" sh -lc "if command -v hb-service >/dev/null 2>&1; then hb-service --docker add '$GOVEE_PLUGIN'; elif command -v npm >/dev/null 2>&1; then cd /homebridge && npm install --save --force '$GOVEE_REPO'; else echo 'Neither hb-service nor npm is available in the Homebridge container.' >&2; exit 127; fi" >/dev/null 2>&1
    
    docker exec -u root "$container_name" bash -lc 'setcap cap_net_raw+eip "$(eval readlink -f "$(which node)")" || true' >/dev/null 2>&1 || true
    
    docker restart "$container_name" >/dev/null 2>&1
    log "    âœ“ Govee plugin installed/updated"
  else
    log "    âš  Container not running, skipping Govee plugin installation"
  fi
  
  echo
}

# Restart DMXSmartLink service
restart_service() {
  log "------------------------------------------------------"
  log "STEP 4: Restarting DMXSmartLink service..."
  
  if "$SYSTEMCTL_BIN" is-active --quiet dmxsmartlink.service 2>/dev/null; then
    "$SYSTEMCTL_BIN" restart dmxsmartlink.service
    RESTART_DONE=1
    log "    âœ“ Service restarted"
  elif "$SYSTEMCTL_BIN" is-enabled --quiet dmxsmartlink.service 2>/dev/null; then
    "$SYSTEMCTL_BIN" start dmxsmartlink.service
    RESTART_DONE=1
    log "    âœ“ Service started"
  else
    log "    âš  Service not found or not enabled"
    log "    You may need to restart the service manually:"
    log "    sudo systemctl restart dmxsmartlink.service"
  fi
  echo
}

request_system_reboot() {
  log "------------------------------------------------------"
  log "STEP 4: Rebooting system to finish update..."

  sync || true
  if "$REBOOT_BIN"; then
    RESTART_DONE=1
    log "    Reboot initiated"
    echo
    return 0
  fi

  log "    Could not trigger system reboot, falling back to service restart"
  echo
  return 1
}

# ========================== MAIN ==========================
log "======================================================"
log "DMXSmartLink Upgrade Script (Raspberry Pi 5)"
log "======================================================"
echo

# Check installation exists
check_installation

log "STEP 1: Downloading latest release..."

# Download and extract release
SRC_DIR=$(download_release "$DIST_DIR")
refresh_root_update_worker_from_release "$SRC_DIR"
refresh_root_update_launcher
ensure_reboot_sudoers
stop_service_for_upgrade

# Upgrade files
upgrade_files "$SRC_DIR"

# Cleanup temp files from download
rm -rf "/tmp/dmxsmartlink-upgrade-$$" "/tmp/dmxsmartlink-release-$$.zip" 2>/dev/null || true

# Update Python dependencies
update_python_deps

# Update Homebridge
update_homebridge

if request_system_reboot; then
  exit 0
fi

# Restart service only if reboot could not be triggered
restart_service

log "======================================================"
log "âœ… Upgrade complete!"
log "======================================================"
log ""
log "Configuration files have been preserved:"
for preserve_file in "${PRESERVE_FILES[@]}"; do
  if [[ -f "$TARGET_DIR/$preserve_file" ]]; then
    log "  âœ“ $preserve_file"
  fi
done
log ""
log "Service status:"
"$SYSTEMCTL_BIN" --no-pager -n 5 status dmxsmartlink.service 2>/dev/null || log "  (Run 'sudo systemctl status dmxsmartlink.service' to check)"
