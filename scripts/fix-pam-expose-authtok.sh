#!/bin/bash

# Fix PAM pam_exec to expose authentication token

echo "Fixing PAM configuration..."

# Backup
sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.backup3

# Fix the pam_exec line to include expose_authtok
sudo sed -i 's|auth.*pam_exec.so.*check-password.sh|auth    sufficient   pam_exec.so expose_authtok quiet /var/lib/user-containers/check-password.sh|' /etc/pam.d/sshd

echo "Updated PAM configuration:"
sudo grep "pam_exec" /etc/pam.d/sshd

echo ""
echo "Restarting SSH..."
sudo systemctl restart ssh

echo ""
echo "✓ Fixed! Now try:"
echo "  ssh -p 2222 ary@localhost"
echo "  Password: TestPass123"
