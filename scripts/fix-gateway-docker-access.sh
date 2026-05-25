#!/bin/bash

echo "=== Fixing Container Gateway Issues ==="
echo ""

# 1. Add containers user to docker group
echo "1. Adding containers user to docker group..."
sudo usermod -aG docker containers
echo "✓ Added to docker group"
echo ""

# 2. Fix gateway script to skip comments
echo "2. Fixing gateway script to skip comments..."
cat << 'EOF' | sudo tee /home/containers/gateway.sh > /dev/null
#!/bin/bash

clear
echo "╔══════════════════════════════════════╗"
echo "║   Container Gateway                  ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Available containers:"
echo ""

# Show available containers - skip comment lines
grep -v "^#" /var/lib/user-containers/users.db | while IFS=: read username container hash timestamp resources; do
    [ -n "$username" ] && echo "  • $username"
done

echo ""
read -p "Username: " TARGET_USER
read -s -p "Password: " TARGET_PASS
echo ""

# Check credentials
DB_LINE=$(grep "^${TARGET_USER}:" /var/lib/user-containers/users.db 2>/dev/null)
if [ -z "$DB_LINE" ]; then
    echo "Error: User not found"
    sleep 2
    exit 1
fi

STORED_HASH=$(echo "$DB_LINE" | cut -d: -f3)
CONTAINER=$(echo "$DB_LINE" | cut -d: -f2)
INPUT_HASH=$(echo -n "$TARGET_PASS" | sha256sum | awk '{print $1}')

if [ "$INPUT_HASH" != "$STORED_HASH" ]; then
    echo "Error: Invalid password"
    sleep 2
    exit 1
fi

# Connect to container
echo "Connecting to $CONTAINER..."
exec docker exec -it "$CONTAINER" /bin/bash
EOF

sudo chmod +x /home/containers/gateway.sh
echo "✓ Fixed gateway script"
echo ""

echo "3. Testing Docker access for containers user..."
if sudo -u containers docker ps &>/dev/null; then
    echo "✓ Docker access works"
else
    echo "⚠ May need to logout/login for group to take effect"
    echo "  Or restart SSH: sudo systemctl restart sshd"
fi
echo ""

echo "=== Fixes Applied ==="
echo ""
echo "Test again from your Mac:"
echo "  ssh containers@ssh.aryangoyal.space"
echo "  Password: gateway123"
echo "  Username: ary"
echo "  Password: TestPass123"
