#!/bin/bash

# SSH Gateway Debug Tool
# Helps diagnose SSH password authentication issues

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== SSH Gateway Debug Tool ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root (use sudo)${NC}"
    exit 1
fi

# Check 1: Users database
echo -e "${YELLOW}1. Checking users database...${NC}"
if [ -f /var/lib/user-containers/users.db ]; then
    echo -e "${GREEN}✓ Database exists${NC}"
    USER_COUNT=$(wc -l < /var/lib/user-containers/users.db)
    echo "  Users found: $USER_COUNT"
    echo ""
    echo "  Users list:"
    while IFS=: read -r username container hash rest; do
        echo "    - $username → $container"
    done < /var/lib/user-containers/users.db
else
    echo -e "${RED}✗ Database not found at /var/lib/user-containers/users.db${NC}"
fi
echo ""

# Check 2: Password checker script
echo -e "${YELLOW}2. Checking password checker...${NC}"
if [ -f /var/lib/user-containers/check-password.sh ]; then
    echo -e "${GREEN}✓ Password checker exists${NC}"
    if [ -x /var/lib/user-containers/check-password.sh ]; then
        echo -e "${GREEN}✓ Password checker is executable${NC}"
    else
        echo -e "${RED}✗ Password checker is NOT executable${NC}"
        echo "  Fix: sudo chmod +x /var/lib/user-containers/check-password.sh"
    fi
else
    echo -e "${RED}✗ Password checker not found${NC}"
fi
echo ""

# Check 3: SSH router script
echo -e "${YELLOW}3. Checking SSH router...${NC}"
if [ -f /var/lib/user-containers/ssh-router-password.sh ]; then
    echo -e "${GREEN}✓ SSH router exists${NC}"
    if [ -x /var/lib/user-containers/ssh-router-password.sh ]; then
        echo -e "${GREEN}✓ SSH router is executable${NC}"
    else
        echo -e "${RED}✗ SSH router is NOT executable${NC}"
        echo "  Fix: sudo chmod +x /var/lib/user-containers/ssh-router-password.sh"
    fi
else
    echo -e "${RED}✗ SSH router not found${NC}"
fi
echo ""

# Check 4: PAM configuration
echo -e "${YELLOW}4. Checking PAM configuration...${NC}"
if [ -f /etc/pam.d/sshd-containers ]; then
    echo -e "${GREEN}✓ PAM config exists${NC}"
    cat /etc/pam.d/sshd-containers
else
    echo -e "${RED}✗ PAM config not found${NC}"
fi
echo ""

# Check 5: SSH configuration
echo -e "${YELLOW}5. Checking SSH configuration...${NC}"
if sshd -t 2>/dev/null; then
    echo -e "${GREEN}✓ SSH config is valid${NC}"
else
    echo -e "${RED}✗ SSH config has errors:${NC}"
    sshd -t
fi

echo ""
echo "  Password authentication:"
if grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
    echo -e "    ${GREEN}✓ Enabled${NC}"
else
    echo -e "    ${RED}✗ Disabled${NC}"
fi

echo ""
echo "  PAM enabled:"
if grep -q "^UsePAM yes" /etc/ssh/sshd_config; then
    echo -e "    ${GREEN}✓ Enabled${NC}"
else
    echo -e "    ${RED}✗ Disabled${NC}"
fi

echo ""
echo "  ForceCommand configured:"
if grep -q "ForceCommand /var/lib/user-containers/ssh-router-password.sh" /etc/ssh/sshd_config; then
    echo -e "    ${GREEN}✓ Found${NC}"
else
    echo -e "    ${RED}✗ Not found${NC}"
fi
echo ""

# Check 6: SSH service
echo -e "${YELLOW}6. Checking SSH service...${NC}"
if systemctl is-active --quiet sshd || systemctl is-active --quiet ssh; then
    echo -e "${GREEN}✓ SSH service is running${NC}"
else
    echo -e "${RED}✗ SSH service is NOT running${NC}"
fi

echo ""
echo "  Listening on port 2222:"
if netstat -tlnp 2>/dev/null | grep -q ":2222"; then
    echo -e "    ${GREEN}✓ Yes${NC}"
    netstat -tlnp | grep ":2222"
else
    echo -e "    ${RED}✗ Not listening on port 2222${NC}"
    echo "    Currently listening on:"
    netstat -tlnp | grep sshd
fi
echo ""

# Check 7: Docker containers
echo -e "${YELLOW}7. Checking Docker containers...${NC}"
CONTAINER_COUNT=$(docker ps --filter "label=managed=true" --format '{{.Names}}' 2>/dev/null | wc -l)
echo "  Running containers: $CONTAINER_COUNT"
if [ $CONTAINER_COUNT -gt 0 ]; then
    docker ps --filter "label=managed=true" --format 'table {{.Names}}\t{{.Status}}\t{{.Labels}}'
fi
echo ""

# Check 8: Recent auth logs
echo -e "${YELLOW}8. Recent SSH authentication attempts...${NC}"
if [ -f /var/log/auth.log ]; then
    echo "  Last 10 SSH-related log entries:"
    tail -20 /var/log/auth.log | grep -i "sshd\|pam" | tail -10
else
    echo -e "${RED}✗ Auth log not found${NC}"
fi
echo ""

# Test password verification
echo -e "${YELLOW}9. Test password verification...${NC}"
read -p "Enter username to test (or press Enter to skip): " TEST_USER
if [ -n "$TEST_USER" ]; then
    if grep -q "^$TEST_USER:" /var/lib/user-containers/users.db 2>/dev/null; then
        read -sp "Enter password: " TEST_PASS
        echo ""
        
        STORED_HASH=$(grep "^$TEST_USER:" /var/lib/user-containers/users.db | cut -d: -f3)
        TEST_HASH=$(echo -n "$TEST_PASS" | sha256sum | awk '{print $1}')
        
        echo "  Stored hash:   $STORED_HASH"
        echo "  Password hash: $TEST_HASH"
        
        if [ "$TEST_HASH" = "$STORED_HASH" ]; then
            echo -e "  ${GREEN}✓ Password matches!${NC}"
        else
            echo -e "  ${RED}✗ Password does NOT match${NC}"
        fi
    else
        echo -e "${RED}✗ User '$TEST_USER' not found in database${NC}"
    fi
fi
echo ""

echo -e "${BLUE}=== Debug Complete ===${NC}"
echo ""
echo "Common fixes:"
echo "1. If password doesn't match, reset it:"
echo "   sudo ./multi-user-containers.sh reset-password <username>"
echo ""
echo "2. If SSH config invalid, re-run setup:"
echo "   sudo ./ssh-gateway.sh setup"
echo ""
echo "3. If port not listening, restart SSH:"
echo "   sudo systemctl restart sshd || sudo systemctl restart ssh"
echo ""
echo "4. View live SSH logs:"
echo "   sudo tail -f /var/log/auth.log"
