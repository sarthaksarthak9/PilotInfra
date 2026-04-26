#!/bin/bash

# Fix SSH Socket Activation Issue
# Switch from socket activation to direct service mode

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Fixing SSH Socket Activation Issue...${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root${NC}"
    exit 1
fi

echo "1. Stopping and disabling ssh.socket..."
systemctl stop ssh.socket 2>/dev/null || true
systemctl disable ssh.socket 2>/dev/null || true
systemctl mask ssh.socket 2>/dev/null || true
echo -e "${GREEN}✓ Socket disabled${NC}"
echo ""

echo "2. Configuring SSH service for direct mode..."
# Create or update service override
mkdir -p /etc/systemd/system/ssh.service.d/
cat > /etc/systemd/system/ssh.service.d/override.conf << 'EOF'
[Unit]
# Don't want socket activation
After=network.target auditd.service
ConditionPathExists=!/etc/ssh/sshd_not_to_be_run

[Service]
# Use sshd_config Port directive
ExecStart=
ExecStart=/usr/sbin/sshd -D
Restart=on-failure
RestartSec=5s
EOF
echo -e "${GREEN}✓ Service override created${NC}"
echo ""

echo "3. Reloading systemd..."
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd reloaded${NC}"
echo ""

echo "4. Restarting SSH service..."
systemctl restart ssh.service
sleep 2
echo -e "${GREEN}✓ SSH service restarted${NC}"
echo ""

echo "5. Checking SSH status..."
if systemctl is-active --quiet ssh.service; then
    echo -e "${GREEN}✓ SSH service is running${NC}"
else
    echo -e "${RED}✗ SSH service failed to start${NC}"
    systemctl status ssh.service
    exit 1
fi
echo ""

echo "6. Verifying port 2222..."
if ss -tlnp 2>/dev/null | grep -q ":2222"; then
    echo -e "${GREEN}✓ SSH is now listening on port 2222!${NC}"
    ss -tlnp | grep ":2222"
elif netstat -tlnp 2>/dev/null | grep -q ":2222"; then
    echo -e "${GREEN}✓ SSH is now listening on port 2222!${NC}"
    netstat -tlnp | grep ":2222"
else
    echo -e "${RED}✗ SSH still not on port 2222${NC}"
    echo ""
    echo "Current listening ports:"
    ss -tlnp 2>/dev/null | grep sshd || netstat -tlnp 2>/dev/null | grep sshd
    echo ""
    echo "Check logs:"
    echo "  sudo journalctl -u ssh.service -n 30"
fi
echo ""

echo -e "${GREEN}=== Fix Complete ===${NC}"
echo ""
echo "Test connection:"
echo "  ssh -p 2222 john@localhost"
echo "  ssh john@ssh.yourdomain.com -o ProxyCommand=\"cloudflared access ssh --hostname %h\""
