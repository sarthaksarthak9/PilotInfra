#!/bin/bash

echo "=== Fixing PAM to Allow Virtual Users ==="
echo ""

# Backup PAM config
sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.backup-$(date +%s)
echo "✓ Backed up /etc/pam.d/sshd"
echo ""

# Create new PAM config that allows virtual users
cat << 'EOF' | sudo tee /etc/pam.d/sshd > /dev/null
# PAM configuration for SSH with virtual container users

# Authentication phase
auth    sufficient   pam_exec.so expose_authtok quiet /var/lib/user-containers/check-password.sh
@include common-auth

# Account phase - allow virtual users
account sufficient   pam_exec.so /var/lib/user-containers/check-user-exists.sh
account required     pam_permit.so

# Session phase
session required     pam_permit.so
session optional     pam_loginuid.so
session optional     pam_keyinit.so force revoke
EOF

echo "✓ Updated /etc/pam.d/sshd"
echo ""

# Create user existence checker script
cat << 'EOF' | sudo tee /var/lib/user-containers/check-user-exists.sh > /dev/null
#!/bin/bash
# Check if virtual user exists in database

USERNAME="${PAM_USER}"

if [ -z "$USERNAME" ]; then
    exit 1
fi

# Check if user exists in database
if grep -q "^${USERNAME}:" /var/lib/user-containers/users.db 2>/dev/null; then
    exit 0  # User exists
else
    exit 1  # User doesn't exist
fi
EOF

sudo chmod +x /var/lib/user-containers/check-user-exists.sh
echo "✓ Created user existence checker"
echo ""

# Show the new config
echo "New PAM configuration:"
echo "----------------------"
sudo cat /etc/pam.d/sshd
echo ""

# Restart SSH
echo "Restarting SSH service..."
sudo systemctl restart sshd || sudo systemctl restart ssh
sleep 2
echo "✓ SSH restarted"
echo ""

echo "=== Fix Complete ==="
echo ""
echo "Test from localhost:"
echo "  ssh -p 2222 ary@localhost"
echo "  Password: TestPass123"
echo ""
echo "If this still fails, check logs:"
echo "  sudo tail -f /var/log/auth.log"
