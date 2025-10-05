#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="$(basename "$SCRIPT_DIR")"
HOME_DIR="$SCRIPT_DIR"

if [ ! -f "$SCRIPT_DIR/main.py" ]; then
  echo "ERROR: Cannot find main.py in $SCRIPT_DIR. Please place setup.sh in your user’s home directory (where main.py lives)."
  exit 1
fi

echo "✅ STEP 1: Detected script directory: $SCRIPT_DIR (user = $USER_NAME)"
echo

TARGET_DIR="$HOME_DIR/dmxsmartlink"
echo "✅ STEP 2: Creating target folder: $TARGET_DIR"
mkdir -p "$TARGET_DIR"
chown "$USER_NAME:$USER_NAME" "$TARGET_DIR"

echo "    Moving only selected files/folders into $TARGET_DIR..."
for ITEM in \
  "device_inventory.py" \
  "group_init.py" \
  "group_manager.py" \
  "HOMEBRIDGE_LICENSE.txt" \
  "artnet_controller.py" \
  "config.py" \
  "license_status.txt" \
  "main.py" \
  "README.txt" \
  "pyarmor_runtime_000000"
do
  if [ -e "$SCRIPT_DIR/$ITEM" ]; then
    mv "$SCRIPT_DIR/$ITEM" "$TARGET_DIR/"
  else
    echo "WARNING: $ITEM not found, skipping."
  fi
done

echo "    Setting ownership of everything under $TARGET_DIR → $USER_NAME:$USER_NAME"
chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR"
echo

echo "------------------------------------------------------"
echo "STEP 3: Installing Docker..."
apt-get update
apt-get install -y docker.io
echo

echo "------------------------------------------------------"
echo "STEP 4: Enabling universe repo & installing Python3 + required packages..."
apt-get install -y software-properties-common

if grep -qi 'ubuntu' /etc/os-release; then
  echo "Detected Ubuntu: enabling 'universe' repository..."
  add-apt-repository universe -y
else
  echo "Not Ubuntu: skipping 'universe' repository step."
fi

apt-get update
apt-get install -y python3-pip python3-flask python3-requests python3-jwt
echo

echo "------------------------------------------------------"
echo "STEP 5: Enabling & starting Docker service..."
systemctl enable docker
systemctl start docker
echo

echo "------------------------------------------------------"
echo "STEP 6: Adding user '$USER_NAME' to the Docker group (might need logout/login)..."
usermod -aG docker "$USER_NAME"
echo

echo "------------------------------------------------------"
echo "STEP 7: Pulling Homebridge Docker image..."
docker pull homebridge/homebridge
echo

echo "------------------------------------------------------"
echo "STEP 8: Starting Homebridge container on ports 8581/9000..."
CONFIG_DIR="/home/$USER_NAME/homebridge-config"
mkdir -p "$CONFIG_DIR"
chown "$USER_NAME:$USER_NAME" "$CONFIG_DIR"

docker run -d \
  --name homebridge \
  --restart=always \
  -p 8581:8581 \
  -p 9000:9000 \
  -v "$CONFIG_DIR":/homebridge \
  homebridge/homebridge

echo "    → Homebridge container started."
echo "    → You can browse to https://<your-host-IP>:8581 to finish Homebridge setup."
echo

echo "Waiting 20 seconds for Homebridge to initialize..."
sleep 20
echo

SERVICE_FILE="/etc/systemd/system/dmxsmartlink.service"
echo "------------------------------------------------------"
echo "STEP 9: Creating systemd service at $SERVICE_FILE..."
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=DMXSmartLink Dashboard Service
After=network.target docker.service
Requires=docker.service

[Service]
User=$USER_NAME
WorkingDirectory=/home/$USER_NAME/dmxsmartlink
# Pull the latest Homebridge image before starting
ExecStartPre=/usr/bin/docker pull homebridge/homebridge
ExecStart=/usr/bin/python3 /home/$USER_NAME/dmxsmartlink/main.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon and enabling dmxsmartlink.service..."
systemctl daemon-reload
systemctl enable dmxsmartlink.service
systemctl start dmxsmartlink.service
echo

echo "------------------------------------------------------"
echo "STEP 10: Setting up patch for homebridge-govee platform.js..."
PATCH_SCRIPT="$TARGET_DIR/homebridge-patch.sh"
PATCH_SERVICE="/etc/systemd/system/homebridge-govee-patch.service"

docker exec -u root homebridge bash -c "cd /var/lib/homebridge && npm install github:cybermancerr/homebridge-govee#latest"

cat <<EOF > "$PATCH_SCRIPT"
#!/bin/bash
set -e

SCRIPT_USER="$USER_NAME"
TMP_FILE="/tmp/platform.js"
URL="https://raw.githubusercontent.com/cybermancerr/homebridge-govee/latest/lib/platform.js"

# Wait up to 60s for homebridge container to be running
for i in {1..30}; do
    if docker ps --format '{{.Names}}' | grep -q "^homebridge\$"; then
        echo "✅ Homebridge container is running."
        break
    fi
    echo "⏳ Waiting for Homebridge container to start..."
    sleep 2
done

echo "🔷 Downloading platform.js from GitHub…"
curl -fsSL "\$URL" -o "\$TMP_FILE"

if [[ ! -s "\$TMP_FILE" ]]; then
    echo "❌ Failed to download platform.js or file is empty!"
    exit 1
fi

echo "🔷 Copying platform.js into Homebridge container…"
docker cp "\$TMP_FILE" homebridge:/homebridge/node_modules/@homebridge-plugins/homebridge-govee/lib/platform.js

echo "✅ Patched platform.js applied."
rm -f "\$TMP_FILE"
EOF

chmod +x "$PATCH_SCRIPT"

echo "Creating systemd service to run patch script on boot..."
cat <<EOF > "$PATCH_SERVICE"
[Unit]
Description=Patch homebridge-govee platform.js after boot
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash $PATCH_SCRIPT

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon and enabling homebridge-govee-patch.service..."
systemctl daemon-reload
systemctl enable homebridge-govee-patch.service
systemctl start homebridge-govee-patch.service
echo
reboot