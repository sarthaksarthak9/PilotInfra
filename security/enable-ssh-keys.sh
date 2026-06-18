#!/bin/bash

echo "=== Enabling SSH Key Authentication for Container Gateway ==="
echo ""

KEY_NAME="container-gateway"

echo "This script will:"
echo "  1. Generate an SSH key pair on your Mac"
echo "  2. Copy the public key to the server"
echo "  3. Disable password authentication for 'containers' user"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi
echo ""

echo "Step 1: Generate SSH Key"
echo "-------------------------"
echo "Run this command on your Mac:"
echo ""
echo "  ssh-keygen -t ed25519 -f ~/.ssh/$KEY_NAME -C \"container-gateway\""
echo ""
read -p "Press Enter when done..."
echo ""

echo "Step 2: Copy Public Key to Server"
echo "----------------------------------"
echo "Run this command on your Mac:"
echo ""
echo "  ssh-copy-id -i ~/.ssh/$KEY_NAME containers@ssh.aryangoyal.space"
echo "  (Enter password: gateway123 or whatever you changed it to)"
echo ""
read -p "Press Enter when done..."
echo ""

echo "Step 3: Test SSH Key Works"
echo "--------------------------"
echo "Run this command on your Mac:"
echo ""
echo "  ssh -i ~/.ssh/$KEY_NAME containers@ssh.aryangoyal.space"
echo ""
echo "You should be able to login WITHOUT a password."
echo ""
read -p "Did it work? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "❌ SSH key doesn't work yet. Don't disable passwords!"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Make sure you ran ssh-copy-id successfully"
    echo "  2. Check the public key was added:"
    echo "     sudo cat /home/containers/.ssh/authorized_keys"
    exit 1
fi
echo ""

echo "Step 4: Disable Password Authentication"
echo "---------------------------------------"
echo "Now that SSH keys work, we'll disable password auth for 'containers' user."
echo ""

# Backup SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-keys-$(date +%s)

# Update Match block for containers user
sudo sed -i '/^Match User containers/,/^[^[:space:]]/{
    /ForceCommand/!{
        /PermitTTY/i\    PasswordAuthentication no\n    PubkeyAuthentication yes
    }
}' /etc/ssh/sshd_config

# Alternative: Recreate the Match block cleanly
sudo sed -i '/# Simple Container Gateway/,/^$/d' /etc/ssh/sshd_config
cat << 'EOF' | sudo tee -a /etc/ssh/sshd_config > /dev/null

# Simple Container Gateway - SSH Key Only
Match User containers
    PasswordAuthentication no
    PubkeyAuthentication yes
    ForceCommand /home/containers/gateway.sh
    PermitTTY yes
EOF

echo "✓ Updated SSH config"
echo ""

# Verify config
if sudo sshd -t; then
    echo "✓ SSH config is valid"
else
    echo "✗ SSH config error - restoring backup"
    sudo cp /etc/ssh/sshd_config.backup-keys-* /etc/ssh/sshd_config
    exit 1
fi
echo ""

# Restart SSH
sudo systemctl restart sshd || sudo systemctl restart ssh
echo "✓ SSH restarted"
echo ""

echo "=== SSH Keys Enabled ==="
echo ""
echo "✅ Password authentication disabled for 'containers' user"
echo "✅ SSH key authentication required"
echo ""
echo "Connect from your Mac:"
echo "  ssh -i ~/.ssh/$KEY_NAME containers@ssh.aryangoyal.space"
echo ""
echo "Or add to ~/.ssh/config on your Mac:"
echo "  Host container-gateway"
echo "    HostName ssh.aryangoyal.space"
echo "    User containers"
echo "    IdentityFile ~/.ssh/$KEY_NAME"
echo "    ProxyCommand cloudflared access ssh --hostname %h"
echo ""
echo "Then connect with: ssh container-gateway"
echo ""
echo "⚠️  IMPORTANT: Keep your SSH key safe!"
echo "    Backup ~/.ssh/$KEY_NAME to a secure location"
