#!/bin/bash

SYSTEM_USER="${1:-aryan}"

echo "=== Allowing System User '$SYSTEM_USER' to Bypass Container Router ==="
echo ""

# Backup SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-$(date +%s)
echo "✓ Backed up SSH config"
echo ""

# Find the Match block and update it
echo "Updating SSH configuration..."

# Remove old Match block
sudo sed -i '/# Container Gateway Match Block/,/# End Container Gateway/d' /etc/ssh/sshd_config

# Add new Match block that excludes system user
cat << 'EOF' | sudo tee -a /etc/ssh/sshd_config > /dev/null

# Container Gateway Match Block
Match User *,!root,!SYSTEM_USER_PLACEHOLDER
    ForceCommand /var/lib/user-containers/ssh-router-password.sh
    PermitTTY yes
# End Container Gateway
EOF

# Replace placeholder with actual username
sudo sed -i "s/SYSTEM_USER_PLACEHOLDER/$SYSTEM_USER/g" /etc/ssh/sshd_config

echo "✓ Updated Match block to exclude: root, $SYSTEM_USER"
echo ""

# Show the configuration
echo "New SSH configuration:"
echo "----------------------"
sudo grep -A 3 "# Container Gateway Match Block" /etc/ssh/sshd_config
echo ""

# Test configuration
echo "Testing SSH configuration..."
if sudo sshd -t; then
    echo "✓ SSH configuration is valid"
else
    echo "✗ SSH configuration has errors!"
    exit 1
fi
echo ""

# Restart SSH
echo "Restarting SSH service..."
sudo systemctl restart sshd || sudo systemctl restart ssh
echo "✓ SSH restarted"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Now you can:"
echo "  • Login as system user:    ssh $SYSTEM_USER@ssh.aryangoyal.space"
echo "  • Login to containers:     ssh ary@ssh.aryangoyal.space"
echo "                             ssh john@ssh.aryangoyal.space"
echo ""
echo "System user '$SYSTEM_USER' will get normal shell access to the host."
echo "Container users will be routed to their Docker containers."
