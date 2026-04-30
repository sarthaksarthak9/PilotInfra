#!/bin/bash

echo "=== Fixing Cloudflare Tunnel to use Port 2222 ==="
echo ""

# Check which config the service uses
SERVICE_CONFIG=$(systemctl cat cloudflared | grep -oP '(?<=--config )[^ ]+' || echo "/etc/cloudflared/config.yml")
echo "Service is using config: $SERVICE_CONFIG"
echo ""

# Update the system config
echo "1. Updating $SERVICE_CONFIG..."
if [ -f "$SERVICE_CONFIG" ]; then
    sudo cp "$SERVICE_CONFIG" "${SERVICE_CONFIG}.backup-$(date +%s)"
    echo "✓ Backed up to ${SERVICE_CONFIG}.backup-$(date +%s)"
    
    # Replace port 22 with 2222 in ssh service line
    sudo sed -i 's|ssh://localhost:22|ssh://localhost:2222|g' "$SERVICE_CONFIG"
    echo "✓ Updated SSH port to 2222"
else
    echo "✗ Config file not found: $SERVICE_CONFIG"
    exit 1
fi
echo ""

# Show the updated config
echo "2. Updated configuration:"
echo "-------------------------"
sudo cat "$SERVICE_CONFIG"
echo ""

# Restart the service
echo "3. Restarting cloudflared service..."
sudo systemctl restart cloudflared
sleep 2
echo "✓ Service restarted"
echo ""

# Check status
echo "4. Service status:"
echo "------------------"
sudo systemctl status cloudflared --no-pager -l | head -20
echo ""

# Watch for errors
echo "5. Checking recent logs (last 10 lines):"
echo "-----------------------------------------"
sleep 3
sudo journalctl -u cloudflared --no-pager -n 10
echo ""

echo "=== Fix Complete ==="
echo ""
echo "Test from your Mac:"
echo "  ssh -v aryan@ssh.aryangoyal.space -o ProxyCommand=\"cloudflared access ssh --hostname %h\""
echo ""
echo "Monitor logs:"
echo "  sudo journalctl -u cloudflared -f"
