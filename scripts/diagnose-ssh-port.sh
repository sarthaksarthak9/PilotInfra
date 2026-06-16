#!/bin/bash

echo "=== Checking why SSH isn't on port 2222 ==="
echo ""

echo "1. Check if port 2222 is already in use:"
sudo lsof -i :2222 2>/dev/null || echo "  Port 2222 is free"
echo ""

echo "2. Check current SSH listening ports:"
sudo netstat -tlnp 2>/dev/null | grep sshd || sudo ss -tlnp 2>/dev/null | grep sshd
echo ""

echo "3. Check SSH service status:"
sudo systemctl status sshd 2>/dev/null || sudo systemctl status ssh 2>/dev/null
echo ""

echo "4. Check SSH logs for Port errors:"
sudo journalctl -u sshd -u ssh -n 50 --no-pager | grep -i "port\|bind\|listen\|error"
echo ""

echo "5. Test SSH config:"
sudo sshd -t -f /etc/ssh/sshd_config
echo ""

echo "6. Check for duplicate Port directives:"
sudo grep "^Port " /etc/ssh/sshd_config
echo ""

echo "7. Check ListenAddress directives:"
sudo grep "^ListenAddress" /etc/ssh/sshd_config
