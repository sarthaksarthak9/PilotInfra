#!/bin/bash

echo "=== Setting Up Simple Password Gateway ==="
echo ""

# Create a single gateway user that everyone uses
GATEWAY_USER="containers"
GATEWAY_PASS="gateway123"  # Change this!

echo "1. Creating gateway user..."
if ! id "$GATEWAY_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash "$GATEWAY_USER"
    echo "$GATEWAY_USER:$GATEWAY_PASS" | sudo chpasswd
    echo "✓ Created user: $GATEWAY_USER"
    echo "  Password: $GATEWAY_PASS"
else
    echo "✓ User already exists"
fi
echo ""

# Create the gateway script that asks which container
cat << 'EOF' | sudo tee /home/containers/gateway.sh > /dev/null
#!/bin/bash

clear
echo "╔══════════════════════════════════════╗"
echo "║   Container Gateway                  ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Which container do you want to access?"
echo ""

# Show available containers
cat /var/lib/user-containers/users.db | while IFS=: read username container hash timestamp resources; do
    echo "  • $username"
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
sudo chown root:root /home/containers/gateway.sh
echo "✓ Created gateway script"
echo ""

# Update SSH config to use normal authentication
echo "2. Updating SSH configuration..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-simple-$(date +%s)

# Remove old container routing
sudo sed -i '/# Container Gateway Match Block/,/# End Container Gateway/d' /etc/ssh/sshd_config
sudo sed -i '/# Simple Container Gateway/,/^$/d' /etc/ssh/sshd_config

# Add simple gateway user block - ONLY for containers user
# System users like aryan will work normally
cat << 'EOF' | sudo tee -a /etc/ssh/sshd_config > /dev/null

# Simple Container Gateway - only applies to 'containers' user
# System users (aryan, root, etc.) work normally
Match User containers
    ForceCommand /home/containers/gateway.sh
    PermitTTY yes
EOF

echo "✓ Updated SSH config"
echo "✓ System user 'aryan' will work normally"
echo "✓ User 'containers' will use gateway"
echo ""

# Use normal PAM (no custom auth needed!)
echo "3. Restoring standard PAM..."
if [ -f /etc/pam.d/sshd.backup-orig ]; then
    sudo cp /etc/pam.d/sshd.backup-orig /etc/pam.d/sshd
    echo "✓ Restored original PAM config"
elif [ -f /etc/pam.d/sshd.backup-* ]; then
    LATEST_BACKUP=$(ls -t /etc/pam.d/sshd.backup-* | head -1)
    sudo cp "$LATEST_BACKUP" /etc/pam.d/sshd
    echo "✓ Restored PAM from backup"
fi
echo ""

# Test SSH config
if sudo sshd -t; then
    echo "✓ SSH config valid"
else
    echo "✗ SSH config error!"
    exit 1
fi
echo ""

# Restart SSH
sudo systemctl restart sshd || sudo systemctl restart ssh
echo "✓ SSH restarted"
echo ""

echo "=== Simple Gateway Ready! ==="
echo ""
echo "System user access (normal SSH):"
echo "  ssh aryan@ssh.aryangoyal.space"
echo "  (Use your normal system password)"
echo ""
echo "Container access (via gateway):"
echo "  ssh containers@ssh.aryangoyal.space"
echo "  Password: $GATEWAY_PASS"
echo "  Then enter container username and password"
echo ""
echo "To create container users:"
echo "  sudo ~/Desktop/linux-server-setup/scripts/ssh-gateway.sh create USERNAME PASSWORD"
