#!/bin/bash

# Complete Multi-User Docker Container Setup
# Run this script to set everything up at once

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Multi-User Docker Container Setup - Complete Setup  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root (use sudo)${NC}"
    exit 1
fi

# ============================
# STEP 1: Fix SSH Socket
# ============================
echo -e "${YELLOW}[1/8] Fixing SSH Socket Activation...${NC}"
systemctl stop ssh.socket 2>/dev/null || true
systemctl disable ssh.socket 2>/dev/null || true
systemctl mask ssh.socket 2>/dev/null || true

mkdir -p /etc/systemd/system/ssh.service.d/
cat > /etc/systemd/system/ssh.service.d/override.conf << 'EOF'
[Unit]
After=network.target auditd.service
ConditionPathExists=!/etc/ssh/sshd_not_to_be_run

[Service]
ExecStart=
ExecStart=/usr/sbin/sshd -D
Restart=on-failure
RestartSec=5s
EOF

systemctl daemon-reload
systemctl restart ssh.service
sleep 2
echo -e "${GREEN}✓ SSH socket fixed${NC}"
echo ""

# ============================
# STEP 2: Verify SSH Port 2222
# ============================
echo -e "${YELLOW}[2/8] Verifying SSH on port 2222...${NC}"
if ss -tlnp 2>/dev/null | grep -q ":2222" || netstat -tlnp 2>/dev/null | grep -q ":2222"; then
    echo -e "${GREEN}✓ SSH listening on port 2222${NC}"
    ss -tlnp 2>/dev/null | grep ":2222" || netstat -tlnp 2>/dev/null | grep ":2222"
else
    echo -e "${RED}✗ SSH not on port 2222${NC}"
    echo "Current SSH ports:"
    ss -tlnp 2>/dev/null | grep sshd || netstat -tlnp 2>/dev/null | grep sshd
    echo ""
    echo "Check SSH config: sudo grep ^Port /etc/ssh/sshd_config"
    exit 1
fi
echo ""

# ============================
# STEP 3: Verify PAM Configuration
# ============================
echo -e "${YELLOW}[3/8] Verifying PAM configuration...${NC}"
if grep -q "/var/lib/user-containers/check-password.sh" /etc/pam.d/sshd; then
    echo -e "${GREEN}✓ PAM custom authentication configured${NC}"
else
    echo -e "${RED}✗ PAM not configured${NC}"
    exit 1
fi
echo ""

# ============================
# STEP 4: Test Password Checker
# ============================
echo -e "${YELLOW}[4/8] Testing password authentication...${NC}"
if [ -x /var/lib/user-containers/check-password.sh ]; then
    echo -e "${GREEN}✓ Password checker is executable${NC}"
else
    echo -e "${RED}✗ Password checker not found or not executable${NC}"
    exit 1
fi

if [ -f /var/lib/user-containers/users.db ]; then
    USER_COUNT=$(wc -l < /var/lib/user-containers/users.db)
    echo -e "${GREEN}✓ Users database exists ($USER_COUNT users)${NC}"
else
    echo -e "${RED}✗ Users database not found${NC}"
    exit 1
fi
echo ""

# ============================
# STEP 5: List Existing Users
# ============================
echo -e "${YELLOW}[5/8] Existing users:${NC}"
while IFS=: read -r username container hash timestamp resources; do
    if [ -n "$username" ] && [ "$username" != "#"* ]; then
        CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "stopped")
        echo "  • $username → $container [$CONTAINER_STATUS]"
    fi
done < /var/lib/user-containers/users.db
echo ""

# ============================
# STEP 6: Test Local Connection
# ============================
echo -e "${YELLOW}[6/8] Testing local SSH connection...${NC}"
echo ""
echo "Available users for testing:"
while IFS=: read -r username container hash timestamp resources; do
    if [ -n "$username" ] && [ "$username" != "#"* ]; then
        echo "  Username: $username"
        # Get password from user directory if available
        if [ -f "/var/lib/user-containers/users/$username/password.txt" ]; then
            PASSWORD=$(cat "/var/lib/user-containers/users/$username/password.txt")
            echo "  Password: $PASSWORD"
        fi
        echo ""
    fi
done < /var/lib/user-containers/users.db

echo -e "${BLUE}Test connection manually:${NC}"
echo "  ssh -p 2222 <username>@localhost"
echo ""
echo -e "${YELLOW}Press Enter to continue...${NC}"
read -r
echo ""

# ============================
# STEP 7: Show Cloudflare Tunnel Command
# ============================
echo -e "${YELLOW}[7/8] Cloudflare Tunnel Connection${NC}"
echo ""
echo "From your Mac/remote machine:"
echo -e "${BLUE}  ssh <username>@ssh.aryangoyal.space \\${NC}"
echo -e "${BLUE}    -o ProxyCommand=\"cloudflared access ssh --hostname %h\"${NC}"
echo ""

# ============================
# STEP 8: Setup Complete - Show Summary
# ============================
echo -e "${YELLOW}[8/8] Setup Complete!${NC}"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✓ Multi-User System Ready!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📋 Quick Reference:${NC}"
echo ""
echo -e "${YELLOW}Create User:${NC}"
echo "  sudo ./multi-user-containers.sh create-user <username>"
echo ""
echo -e "${YELLOW}List Users:${NC}"
echo "  sudo ./multi-user-containers.sh list-users"
echo ""
echo -e "${YELLOW}Reset Password:${NC}"
echo "  sudo ./multi-user-containers.sh reset-password <username>"
echo ""
echo -e "${YELLOW}Delete User:${NC}"
echo "  sudo ./multi-user-containers.sh delete-user <username>"
echo ""
echo -e "${YELLOW}Monitor Containers:${NC}"
echo "  sudo ./multi-user-containers.sh monitor"
echo ""
echo -e "${YELLOW}Debug Issues:${NC}"
echo "  sudo ./ssh-debug.sh"
echo ""

echo -e "${BLUE}🔗 User Connections:${NC}"
echo ""
echo -e "${YELLOW}Local (on server):${NC}"
echo "  ssh -p 2222 <username>@localhost"
echo ""
echo -e "${YELLOW}Remote (via Cloudflare):${NC}"
echo "  ssh <username>@ssh.aryangoyal.space \\"
echo "    -o ProxyCommand=\"cloudflared access ssh --hostname %h\""
echo ""
echo -e "${YELLOW}Add to ~/.ssh/config:${NC}"
cat << 'SSHCONFIG'
  Host myserver
      HostName ssh.aryangoyal.space
      User <username>
      ProxyCommand cloudflared access ssh --hostname %h
  
  Then use: ssh myserver
SSHCONFIG
echo ""

echo -e "${BLUE}📊 System Status:${NC}"
echo ""
echo "SSH Service:"
systemctl status ssh.service --no-pager -l | head -5
echo ""
echo "Listening Ports:"
ss -tlnp 2>/dev/null | grep ":2222" || netstat -tlnp 2>/dev/null | grep ":2222"
echo ""
echo "Running Containers:"
docker ps --filter "label=managed=true" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -10
echo ""

echo -e "${GREEN}✨ All done! Your multi-user Docker system is ready.${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Test local SSH: ssh -p 2222 john@localhost"
echo "  2. Test Cloudflare: ssh john@ssh.aryangoyal.space (from Mac)"
echo "  3. Create more users: sudo ./multi-user-containers.sh create-user alice"
echo ""
