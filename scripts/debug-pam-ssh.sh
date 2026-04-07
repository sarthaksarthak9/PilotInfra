#!/bin/bash

# Debug PAM + SSH Integration

echo "=== PAM SSH Integration Debug ==="
echo ""

echo "1. Current PAM sshd configuration:"
echo "-----------------------------------"
head -30 /etc/pam.d/sshd
echo ""

echo "2. Check if our pam_exec is actually being invoked:"
echo "---------------------------------------------------"
echo "Looking for pam_exec in logs during last SSH attempt..."
sudo grep "pam_exec" /var/log/auth.log | tail -5
echo ""

echo "3. Check what PAM modules are being called:"
echo "--------------------------------------------"
sudo grep "PAM\|pam" /var/log/auth.log | tail -10
echo ""

echo "4. Check if password authentication is happening:"
echo "-------------------------------------------------"
sudo grep "password" /var/log/auth.log | tail -10
echo ""

echo "5. Check SSH config for PAM:"
echo "----------------------------"
sudo grep -i "pam\|challenge" /etc/ssh/sshd_config | grep -v "^#"
echo ""

echo "6. Test with debug logging enabled:"
echo "-----------------------------------"
echo "Run this to see detailed auth flow:"
echo "  sudo /usr/sbin/sshd -d -p 2223 -f /etc/ssh/sshd_config"
echo "Then in another terminal:"
echo "  ssh -p 2223 ary@localhost"
