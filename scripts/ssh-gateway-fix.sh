#!/bin/bash

# SSH Gateway Fix Script
# Cleans up conflicting SSH configs and properly configures PAM

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SSHD_CONFIG="/etc/ssh/sshd_config"

echo -e "${YELLOW}Fixing SSH Gateway Configuration...${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root${NC}"
    exit 1
fi

# 1. Backup current config
echo "1. Backing up current SSH config..."
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.before-fix.$(date +%s)"
echo -e "${GREEN}✓ Backup created${NC}"
echo ""

# 2. Clean up SSH config - remove ALL old container gateway configs
echo "2. Cleaning SSH config..."
sed -i '/# Container Gateway Config/,/^$/d' "$SSHD_CONFIG"
sed -i '/# Container Gateway Configuration/,/# End Container Gateway/d' "$SSHD_CONFIG"
sed -i '/# Container Gateway Match Block/,/# End Container Gateway/d' "$SSHD_CONFIG"
sed -i '/Match User container-gateway/,/^$/d' "$SSHD_CONFIG"

# Remove duplicate Port entries
sed -i '/^Port 2222/d' "$SSHD_CONFIG"
echo -e "${GREEN}✓ Removed old configurations${NC}"
echo ""

# 3. Add clean configuration
echo "3. Adding clean SSH configuration..."

# Find where to insert (before any Match blocks)
FIRST_MATCH=$(grep -n "^Match " "$SSHD_CONFIG" | head -1 | cut -d: -f1)

if [ -n "$FIRST_MATCH" ]; then
    # Insert before first Match block
    {
        head -n $((FIRST_MATCH - 1)) "$SSHD_CONFIG"
        cat << 'GLOBALEOF'

# Container Gateway Configuration
Port 2222
PasswordAuthentication yes
PubkeyAuthentication no
PermitRootLogin no
ChallengeResponseAuthentication yes
UsePAM yes

GLOBALEOF
        tail -n +$FIRST_MATCH "$SSHD_CONFIG"
        cat << 'MATCHEOF'

# Container Gateway Match Block
Match User *,!root
    ForceCommand /var/lib/user-containers/ssh-router-password.sh
    PermitTTY yes
# End Container Gateway
MATCHEOF
    } > "${SSHD_CONFIG}.tmp"
    mv "${SSHD_CONFIG}.tmp" "$SSHD_CONFIG"
else
    # No Match blocks, append
    cat >> "$SSHD_CONFIG" << 'SSHEOF'

# Container Gateway Configuration
Port 2222
PasswordAuthentication yes
PubkeyAuthentication no
PermitRootLogin no
ChallengeResponseAuthentication yes
UsePAM yes

# Container Gateway Match Block
Match User *,!root
    ForceCommand /var/lib/user-containers/ssh-router-password.sh
    PermitTTY yes
# End Container Gateway
SSHEOF
fi

echo -e "${GREEN}✓ Added clean configuration${NC}"
echo ""

# 4. Configure PAM
echo "4. Configuring PAM authentication..."

# Backup PAM sshd config
if [ ! -f /etc/pam.d/sshd.backup ]; then
    cp /etc/pam.d/sshd /etc/pam.d/sshd.backup
    echo -e "${GREEN}✓ Backed up PAM config${NC}"
fi

# Check if our custom auth is already there
if ! grep -q "/var/lib/user-containers/check-password.sh" /etc/pam.d/sshd; then
    # Add custom password checker at the beginning of auth stack
    # This will try our custom database first, then fall back to system auth
    sed -i '/@include common-auth/i # Custom container user authentication\nauth    sufficient   pam_exec.so quiet /var/lib/user-containers/check-password.sh' /etc/pam.d/sshd
    echo -e "${GREEN}✓ Added custom password authentication${NC}"
else
    echo -e "${YELLOW}⚠ Custom auth already configured${NC}"
fi
echo ""

# 5. Verify configuration
echo "5. Verifying SSH configuration..."
if sshd -t 2>/dev/null; then
    echo -e "${GREEN}✓ SSH configuration is valid${NC}"
else
    echo -e "${RED}✗ SSH configuration has errors:${NC}"
    sshd -t
    exit 1
fi
echo ""

# 6. Restart SSH
echo "6. Restarting SSH service..."
systemctl restart sshd || systemctl restart ssh
if systemctl is-active --quiet sshd || systemctl is-active --quiet ssh; then
    echo -e "${GREEN}✓ SSH service restarted successfully${NC}"
else
    echo -e "${RED}✗ SSH service failed to start${NC}"
    exit 1
fi
echo ""

# 7. Verify port
echo "7. Verifying SSH is listening on port 2222..."
sleep 2
if netstat -tlnp 2>/dev/null | grep -q ":2222"; then
    echo -e "${GREEN}✓ SSH listening on port 2222${NC}"
    netstat -tlnp | grep ":2222"
else
    echo -e "${RED}✗ SSH not listening on port 2222${NC}"
    echo "Check SSH logs: sudo journalctl -u sshd -n 50"
fi
echo ""

echo -e "${GREEN}=== Fix Complete ===${NC}"
echo ""
echo "Test connection with:"
echo "  ssh -p 2222 john@localhost"
echo "  ssh john@ssh.yourdomain.com -o ProxyCommand=\"cloudflared access ssh --hostname %h\""
echo ""
echo "View PAM configuration:"
echo "  sudo head -20 /etc/pam.d/sshd"
echo ""
echo "View SSH configuration:"
echo "  sudo grep -A 20 'Container Gateway' /etc/ssh/sshd_config"
