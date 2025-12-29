#!/bin/bash
# upgrade_pi5.sh — DMXSmartLink upgrade script for Raspberry Pi 5
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
# Detect user from current directory or HOME
if [[ "$(pwd)" == /home/* ]]; then
  USER_NAME="$(basename "$(pwd)")"
else
  USER_NAME="${SUDO_USER:-${USER:-dmx}}"
fi
HOME_DIR="/home/$USER_NAME"
TARGET_DIR="$HOME_DIR/dmxsmartlink"
CONFIG_DIR="$HOME_DIR/homebridge-config"
DIST_DIR="dist_ubuntu_m4"  # Hardcoded for Apple Silicon M4

# ---------------- Custom Govee plugin repo ----------------
GOVEE_REPO="github:cybermancerr/homebridge-govee#latest"

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

log() { echo -e "$*"; }

# Check if installation exists
check_installation() {
  if [[ ! -d "$TARGET_DIR" ]]; then
    log "❌ DMXSmartLink installation not found at $TARGET_DIR"
    log "    Please run setup.sh first to install DMXSmartLink."
    exit 1
  fi
  
  if [[ ! -f "$TARGET_DIR/main.py" ]]; then
    log "❌ DMXSmartLink installation appears incomplete (main.py not found)"
    log "    Please run setup.sh to reinstall."
    exit 1
  fi
  
  log "✓ Found existing installation at $TARGET_DIR"
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
  if command -v curl >/dev/null 2>&1; then
    REL_JSON="$(curl -fsSL "$API_URL" 2>&1)"
    if [ $? -ne 0 ] || echo "$REL_JSON" | grep -q "404\|Not Found"; then
      log "    Latest release not found, trying tag 'DMXSmartLink'..."
      API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/tags/DMXSmartLink"
      REL_JSON="$(curl -fsSL "$API_URL" 2>&1)"
    fi
  fi
  
  local DOWNLOAD_URL=""
  if [[ -n "$REL_JSON" ]] && command -v python3 >/dev/null 2>&1; then
    DOWNLOAD_URL="$(python3 - <<PY
import json,sys
try:
    d=json.loads(sys.stdin.read() or "{}")
    if "message" in d:
        print("")
        raise SystemExit(0)
    assets=d.get("assets") or []
    for a in assets:
        u=a.get("browser_download_url","")
        n=a.get("name","").lower()
        if "dmxsmartlink" in n and n.endswith(".zip"):
            print(u); raise SystemExit(0)
    for a in assets:
        u=a.get("browser_download_url","")
        n=a.get("name","")
        if u.endswith(".zip") or n.endswith(".zip"):
            print(u); raise SystemExit(0)
    print(d.get("zipball_url",""))
except Exception:
    print("")
PY
<<<"$REL_JSON" 2>&1)"
  fi
  
  # Fallback to direct download
  if [[ -z "$DOWNLOAD_URL" ]] || [[ "$DOWNLOAD_URL" == "" ]]; then
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/DMXSmartLink/dmxsmartlink.zip"
  fi
  
  log "    Downloading release..."
  if ! curl -fL "$DOWNLOAD_URL" -o "$ZIP_PATH" 2>/dev/null; then
    log "❌ Failed to download release zip"
    rm -rf "$TEMP_DIR" "$ZIP_PATH"
    exit 1
  fi
  
  if ! unzip -q "$ZIP_PATH" -d "$TEMP_DIR" 2>/dev/null; then
    log "❌ Failed to extract zip file"
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
    log "❌ Directory $DIST_DIR not found in extracted zip"
    log "    Available directories in temp: $(ls -1 "$TEMP_DIR" 2>/dev/null | head -5 | tr '\n' ' ' || echo 'none')"
    if [[ -n "$ROOT_DIR" ]]; then
      log "    Root dir contents: $(ls -1 "$ROOT_DIR" 2>/dev/null | head -10 | tr '\n' ' ' || echo 'none')"
    fi
    rm -rf "$TEMP_DIR" "$ZIP_PATH"
    exit 1
  fi
  
  # Verify SRC_DIR exists and log contents for debugging
  if [[ ! -d "$SRC_DIR" ]]; then
    log "❌ Source directory $SRC_DIR does not exist"
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
  
  log "    Copying files from $DIST_DIR into $TARGET_DIR..."
  
  # Same file list as setup.sh (including config_loader.py and license_status.txt for reference)
  local items=(
    artnet_controller.py config_loader.py device_inventory.py device_registry.py group_init.py group_manager.py main.py
    license_status.txt HOMEBRIDGE_LICENSE.txt LICENSE.txt README.txt
  )
  
  # Backup preserved files before copying
  local BACKUP_DIR="$TARGET_DIR/.upgrade_backup_$$"
  mkdir -p "$BACKUP_DIR"
  for preserve_file in "${PRESERVE_FILES[@]}"; do
    if [[ -e "$TARGET_DIR/$preserve_file" ]]; then
      cp -a "$TARGET_DIR/$preserve_file" "$BACKUP_DIR/"
    fi
  done
  
  # Copy standard files (same logic as setup.sh, but skip preserved ones)
  for it in "${items[@]}"; do
    # Skip files that should be preserved
    if [[ " ${PRESERVE_FILES[@]} " =~ " ${it} " ]]; then
      continue
    fi
    
    # Use same logic as setup.sh: [ -e ] instead of [[ -e ]]
    if [ -e "$SRC_DIR/$it" ]; then
      if [ -d "$SRC_DIR/$it" ]; then
        rm -rf "$TARGET_DIR/$it"
        cp -a "$SRC_DIR/$it" "$TARGET_DIR/"
        log "    ✓ Updated directory: $it"
      else
        cp -a "$SRC_DIR/$it" "$TARGET_DIR/"
        log "    ✓ Updated file: $it"
      fi
    else
      log "    ⚠ $it not found in $DIST_DIR, skipping."
    fi
  done
  
  # Dynamically find and copy PyArmor Pro runtime folder (same logic as setup.sh)
  log "    Finding PyArmor Pro runtime folder..."
  local pyarmor_runtime=""
  for dir in "$SRC_DIR"/pyarmor_runtime_*; do
    if [ -d "$dir" ]; then
      pyarmor_runtime="$(basename "$dir")"
      rm -rf "$TARGET_DIR/$pyarmor_runtime"
      cp -a "$dir" "$TARGET_DIR/"
      log "    ✓ Copied PyArmor Pro runtime: $pyarmor_runtime"
      
      # Ensure .so file has correct permissions (executable and readable)
      if [ -f "$TARGET_DIR/$pyarmor_runtime/pyarmor_runtime.so" ]; then
        chmod 755 "$TARGET_DIR/$pyarmor_runtime/pyarmor_runtime.so"
        log "    ✓ Set permissions on pyarmor_runtime.so"
      fi
      break
    fi
  done
  
  if [ -z "$pyarmor_runtime" ]; then
    log "    ⚠ WARNING: No pyarmor_runtime_* folder found in $DIST_DIR"
  fi
  
  # Copy providers directory if it exists (same logic as setup.sh)
  if [ -d "$SRC_DIR/providers" ]; then
    rm -rf "$TARGET_DIR/providers"
    cp -a "$SRC_DIR/providers" "$TARGET_DIR/"
    log "    ✓ Copied directory: providers"
  fi
  
  # Restore preserved files and directories
  for preserve_file in "${PRESERVE_FILES[@]}"; do
    if [[ -e "$BACKUP_DIR/$preserve_file" ]]; then
      cp -a "$BACKUP_DIR/$preserve_file" "$TARGET_DIR/"
    fi
  done
  rm -rf "$BACKUP_DIR"
  
  # Save architecture marker for future upgrades
  echo "$DIST_DIR" > "$TARGET_DIR/.install_arch"
  chown "$USER_NAME:$USER_NAME" "$TARGET_DIR/.install_arch"
  
  # Set permissions
  chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR"
  find "$TARGET_DIR" -type d -exec chmod 775 {} \;
  find "$TARGET_DIR" -type f -exec chmod 664 {} \;
  find "$TARGET_DIR" -name "*.so" -exec chmod 755 {} \;
  
  log "    ✓ Files updated successfully"
}

# Update Python dependencies
update_python_deps() {
  log "------------------------------------------------------"
  log "STEP 2: Updating Python dependencies..."
  
  if [[ ! -d "$TARGET_DIR/.venv" ]]; then
    log "    ⚠ Virtual environment not found, creating new one..."
    if ! command -v python3 >/dev/null 2>&1; then
      log "❌ Python 3 not found"
      exit 2
    fi
    sudo -u "$USER_NAME" bash -lc "
      set -e
      cd '$TARGET_DIR'
      python3 -m venv .venv
      source .venv/bin/activate
      pip install -U pip
      pip install -U Flask requests 'PyJWT[crypto]' pyarmor pyarmor.cli.core
    "
  else
    log "    Updating packages in existing virtual environment..."
    if [[ -f "$TARGET_DIR/.venv/bin/python" ]]; then
      "$TARGET_DIR/.venv/bin/python" -m pip install -U pip setuptools wheel >/dev/null 2>&1 || true
      "$TARGET_DIR/.venv/bin/pip" install -U Flask requests 'PyJWT[crypto]' pyarmor pyarmor.cli.core >/dev/null 2>&1 || true
      log "    ✓ Dependencies updated"
    else
      log "    ⚠ Virtual environment python not found at $TARGET_DIR/.venv/bin/python"
    fi
  fi
  
  chmod -R +x "$TARGET_DIR/.venv/bin" 2>/dev/null || true
  chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR/.venv" 2>/dev/null || true
  log "    ✓ Python dependencies updated"
  echo
}

# Update Homebridge container and Govee plugin
update_homebridge() {
  log "------------------------------------------------------"
  log "STEP 3: Updating Homebridge container and Govee plugin..."
  
  if ! command -v docker >/dev/null 2>&1; then
    log "    ⚠ Docker not found, skipping Homebridge update"
    return
  fi
  
  # Pull latest Homebridge image
  docker pull homebridge/homebridge >/dev/null 2>&1 || true
  
  # Find existing container
  local container_name
  container_name="$(docker ps -a --format '{{.Names}}' | grep -i homebridge | head -n1 || true)"
  
  if [[ -z "$container_name" ]]; then
    log "    ⚠ Homebridge container not found, skipping update"
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
    log "    ⚠ Failed to recreate Homebridge container, trying with basic config..."
    # Fallback: try recreating with just the config directory (most important mount)
    if [[ -d "$CONFIG_DIR" ]]; then
      if docker run -d \
        --name "$container_name" \
        --restart="$restart_policy" \
        --network="$network_mode" \
        -v "$CONFIG_DIR:/homebridge" \
        "$image" >/dev/null 2>&1; then
        log "    ✓ Homebridge container recreated with basic config"
      else
        log "    ❌ Failed to recreate container even with basic config"
        return
      fi
    else
      log "    ❌ Config directory $CONFIG_DIR not found"
      return
    fi
  else
    log "    ✓ Homebridge container recreated"
  fi
  
  # Install Govee plugin (only if container exists)
  if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
    log "    Installing/updating Govee plugin..."
    docker exec -u root -e DEBIAN_FRONTEND=noninteractive -e NEEDRESTART_MODE=a "$container_name" \
      bash -lc "apt-get update -yq && apt-get install -yq --no-install-recommends git curl bluetooth bluez libbluetooth-dev libudev-dev pi-bluetooth || true" >/dev/null 2>&1 || true
    
    docker exec "$container_name" bash -lc "cd /homebridge && npm install '$GOVEE_REPO' || true" >/dev/null 2>&1 || true
    
    docker exec -u root "$container_name" bash -lc 'setcap cap_net_raw+eip "$(eval readlink -f "$(which node)")" || true' >/dev/null 2>&1 || true
    
    docker restart "$container_name" >/dev/null 2>&1
    log "    ✓ Govee plugin installed/updated"
  else
    log "    ⚠ Container not running, skipping Govee plugin installation"
  fi
  
  echo
}

# Restart DMXSmartLink service
restart_service() {
  log "------------------------------------------------------"
  log "STEP 4: Restarting DMXSmartLink service..."
  
  if systemctl is-active --quiet dmxsmartlink.service 2>/dev/null; then
    systemctl restart dmxsmartlink.service
    log "    ✓ Service restarted"
  elif systemctl is-enabled --quiet dmxsmartlink.service 2>/dev/null; then
    systemctl start dmxsmartlink.service
    log "    ✓ Service started"
  else
    log "    ⚠ Service not found or not enabled"
    log "    You may need to restart the service manually:"
    log "    sudo systemctl restart dmxsmartlink.service"
  fi
  echo
}

# ========================== MAIN ==========================
log "======================================================"
log "DMXSmartLink Upgrade Script (Apple Silicon M4)"
log "======================================================"
echo

# Check installation exists
check_installation

log "STEP 1: Downloading latest release..."

# Download and extract release
SRC_DIR=$(download_release "$DIST_DIR")

# Upgrade files
upgrade_files "$SRC_DIR"

# Cleanup temp files from download
rm -rf "/tmp/dmxsmartlink-upgrade-$$" "/tmp/dmxsmartlink-release-$$.zip" 2>/dev/null || true

# Update Python dependencies
update_python_deps

# Update Homebridge
update_homebridge

# Restart service
restart_service

log "======================================================"
log "✅ Upgrade complete!"
log "======================================================"
log ""
log "Configuration files have been preserved:"
for preserve_file in "${PRESERVE_FILES[@]}"; do
  if [[ -f "$TARGET_DIR/$preserve_file" ]]; then
    log "  ✓ $preserve_file"
  fi
done
log ""
log "Service status:"
systemctl --no-pager -n 5 status dmxsmartlink.service 2>/dev/null || log "  (Run 'sudo systemctl status dmxsmartlink.service' to check)"

