#!/bin/bash

# SSH Gateway for Multi-User Docker Containers
# PASSWORD VERSION - Users login with username+password (no SSH keys needed)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

USERS_DB="/var/lib/user-containers/users.db"
SSHD_CONFIG="/etc/ssh/sshd_config"
GATEWAY_USER="dockergw"

# ============================
# HELP
# ============================
show_help() {
    echo -e "${BLUE}SSH Gateway for Container Access (PASSWORD VERSION)${NC}"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup           - Setup SSH gateway with password auth"
    echo "  list            - List all users"
    echo "  test <user>     - Test user's configuration"
    echo "  reset-password <user> - Reset user's password"
    echo ""
    echo "Features:"
    echo "  - Password-based SSH (no keys needed!)"
    echo "  - Single gateway user for all"
    echo "  - Users login: ssh user@server-ip"
    echo "  - Each user uses their container password"
    echo ""
    echo "After setup, users connect via:"
    echo "  ssh -p 2222 username@server-ip"
    echo "  ssh username@ssh.yourdomain.com -o ProxyCommand=\"cloudflared access ssh --hostname %h\""
    echo ""
}

# ============================
# SETUP SSH GATEWAY
# ============================
setup_gateway() {
    echo -e "${YELLOW}Setting up PASSWORD SSH gateway...${NC}"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: Must run as root${NC}"
        exit 1
    fi
    
    # Install dependencies
    if ! command -v sshd &> /dev/null; then
        echo "Installing OpenSSH server..."
        if [ -f /etc/debian_version ]; then
            apt-get update && apt-get install -y openssh-server libpam-pwdfile
        elif [ -f /etc/redhat-release ]; then
            yum install -y openssh-server
        else
            echo -e "${RED}Error: Unsupported OS${NC}"
            exit 1
        fi
    fi
    
    # Backup original PAM sshd config
    if [ ! -f /etc/pam.d/sshd.backup ]; then
        cp /etc/pam.d/sshd /etc/pam.d/sshd.backup
        echo "✓ Backed up PAM sshd config"
    fi
    
    # Modify SSH PAM config to use custom password checker
    # Insert our custom auth at the beginning
    sed -i '/^#%PAM-1.0/a # Custom container user authentication\nauth    [success=done new_authtok_reqd=done default=ignore]   pam_exec.so quiet /var/lib/user-containers/check-password.sh' /etc/pam.d/sshd
    echo "✓ Updated SSH PAM configuration"
    
    # Create password checker script
    cat > /var/lib/user-containers/check-password.sh << 'CHECKEOF'
#!/bin/bash

# Password checker for container users

USERS_DB="/var/lib/user-containers/users.db"

# Get username from PAM
USERNAME="$PAM_USER"

# Read password from stdin
read -r PASSWORD

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    exit 1
fi

# Check if user exists
if ! grep -q "^$USERNAME:" "$USERS_DB" 2>/dev/null; then
    exit 1
fi

# Get stored password hash
USER_DATA=$(grep "^$USERNAME:" "$USERS_DB")
STORED_HASH=$(echo "$USER_DATA" | cut -d: -f3)

# Hash provided password
PASSWORD_HASH=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')

# Compare
if [ "$PASSWORD_HASH" = "$STORED_HASH" ]; then
    exit 0
else
    exit 1
fi
CHECKEOF
    chmod +x /var/lib/user-containers/check-password.sh
    echo "✓ Created password checker"
    
    # Create routing script
    cat > /var/lib/user-containers/ssh-router-password.sh << 'ROUTEREOF'
#!/bin/bash

# SSH Router with Password Auth

USERS_DB="/var/lib/user-containers/users.db"

# Get username from SSH
USERNAME="$USER"

# If no username, this is initial connection - prompt
if [ -z "$USERNAME" ] || [ "$USERNAME" = "dockergw" ]; then
    echo "Container Login"
    echo ""
    read -p "Username: " USERNAME
    read -sp "Password: " PASSWORD
    echo ""
    
    # Verify credentials
    if ! grep -q "^$USERNAME:" "$USERS_DB" 2>/dev/null; then
        echo "Error: User not found"
        exit 1
    fi
    
    USER_DATA=$(grep "^$USERNAME:" "$USERS_DB")
    STORED_HASH=$(echo "$USER_DATA" | cut -d: -f3)
    PASSWORD_HASH=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')
    
    if [ "$PASSWORD_HASH" != "$STORED_HASH" ]; then
        echo "Error: Invalid password"
        exit 1
    fi
fi

# Get user's container
if ! grep -q "^$USERNAME:" "$USERS_DB" 2>/dev/null; then
    echo "Error: User not found"
    exit 1
fi

USER_DATA=$(grep "^$USERNAME:" "$USERS_DB")
CONTAINER=$(echo "$USER_DATA" | cut -d: -f2)

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
    echo "Starting your container..."
    docker start "$CONTAINER" > /dev/null 2>&1
    sleep 2
fi

# Log access
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH: $USERNAME -> $CONTAINER" >> /var/lib/user-containers/logs/access.log

# Connect to container
echo "Welcome $USERNAME!"
exec docker exec -it "$CONTAINER" /bin/bash
ROUTEREOF
    
    chmod +x /var/lib/user-containers/ssh-router-password.sh
    echo "✓ Created SSH router"
    
    # Create users and add to docker group
    # We need individual Linux users for SSH password auth
    echo "✓ System users will be created automatically when adding container users"
    
    # Backup sshd_config
    if [ ! -f "${SSHD_CONFIG}.backup" ]; then
        cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup"
        echo "✓ Backed up SSH config"
    fi
    
    # Configure SSH for password auth
    # Remove old config if exists
    sed -i '/# Container Gateway Configuration/,/# End Container Gateway/d' "$SSHD_CONFIG" 2>/dev/null || true
    
    # Find the line number of the first Match block (if any)
    FIRST_MATCH=$(grep -n "^Match " "$SSHD_CONFIG" | head -1 | cut -d: -f1)
    
    if [ -n "$FIRST_MATCH" ]; then
        # There's an existing Match block, insert our config BEFORE it
        {
            # Lines before the first Match block
            head -n $((FIRST_MATCH - 1)) "$SSHD_CONFIG"
            
            # Our global configuration
            cat << 'GLOBALEOF'

# Container Gateway Configuration (Password Auth)
Port 2222
PasswordAuthentication yes
PubkeyAuthentication no
PermitRootLogin no
ChallengeResponseAuthentication yes
UsePAM yes

GLOBALEOF
            
            # The rest of the file (including Match blocks)
            tail -n +$FIRST_MATCH "$SSHD_CONFIG"
            
            # Our Match block at the very end
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
        # No Match blocks exist, just append everything
        cat >> "$SSHD_CONFIG" << 'SSHEOF'

# Container Gateway Configuration (Password Auth)
Port 2222
PasswordAuthentication yes
PubkeyAuthentication no
PermitRootLogin no
ChallengeResponseAuthentication yes
UsePAM yes

# All container users route through ForceCommand
Match User *,!root
    ForceCommand /var/lib/user-containers/ssh-router-password.sh
    PermitTTY yes
# End Container Gateway
SSHEOF
    fi
    
    echo "✓ Configured SSH with password auth"
    
    # Test SSH config
    if ! sshd -t; then
        echo -e "${RED}Error: Invalid SSH configuration${NC}"
        exit 1
    fi
    
    # Restart SSH
    systemctl restart sshd || systemctl restart ssh
    echo "✓ SSH service restarted"
    
    echo ""
    echo -e "${GREEN}✓ PASSWORD SSH gateway setup complete${NC}"
    echo ""
    echo "How it works:"
    echo "  1. User connects: ssh -p 2222 username@server-ip"
    echo "  2. SSH prompts for password"
    echo "  3. Password checked against users.db"
    echo "  4. User routed to their container"
    echo ""
    echo "Next: Create users with ./multi-user-containers.sh create-user <username>"
    echo "Users will automatically have SSH password access!"
    echo ""
}

# ============================
# SYNC USERS (called by multi-user-containers.sh)
# ============================
sync_user() {
    USERNAME="$1"
    PASSWORD="$2"
    
    if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
        return 1
    fi
    
    # Create Linux user if doesn't exist
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m -s /bin/bash "$USERNAME"
        # Add to docker group
        usermod -aG docker "$USERNAME"
    fi
    
    # Set password
    echo "$USERNAME:$PASSWORD" | chpasswd
    
    return 0
}

# ============================
# LIST SSH USERS
# ============================
list_ssh_users() {
    echo -e "${BLUE}=== SSH Users (Password Auth) ===${NC}"
    echo ""
    
    if [ ! -f "$USERS_DB" ]; then
        echo "No users found"
        return 0
    fi
    
    printf "%-15s %-30s %-15s\n" "USERNAME" "CONTAINER" "SSH ENABLED"
    echo "─────────────────────────────────────────────────────────────"
    
    while IFS=: read -r username container _; do
        if id "$username" &>/dev/null; then
            SSH_STATUS="✓ Yes"
        else
            SSH_STATUS="✗ No (run sync)"
        fi
        printf "%-15s %-30s %-15s\n" "$username" "$container" "$SSH_STATUS"
    done < "$USERS_DB"
    
    echo ""
    echo "Users connect with: ssh -p 2222 username@server-ip"
    echo ""
}

# ============================
# RESET PASSWORD
# ============================
reset_password() {
    USERNAME="$1"
    
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}Error: Username required${NC}"
        echo "Usage: $0 reset-password <username>"
        exit 1
    fi
    
    # Check user exists
    if ! grep -q "^$USERNAME:" "$USERS_DB" 2>/dev/null; then
        echo -e "${RED}Error: User not found${NC}"
        exit 1
    fi
    
    # Generate new password
    NEW_PASSWORD=$(openssl rand -base64 12)
    PASSWORD_HASH=$(echo -n "$NEW_PASSWORD" | sha256sum | awk '{print $1}')
    
    # Update database
    sed -i "s/^$USERNAME:\([^:]*\):[^:]*:/$USERNAME:\1:$PASSWORD_HASH:/" "$USERS_DB"
    
    # Update Linux user password
    if id "$USERNAME" &>/dev/null; then
        echo "$USERNAME:$NEW_PASSWORD" | chpasswd
    fi
    
    # Update password file
    USER_DIR="/var/lib/user-containers/users/$USERNAME"
    echo "$NEW_PASSWORD" > "$USER_DIR/password.txt"
    chmod 600 "$USER_DIR/password.txt"
    
    echo ""
    echo -e "${GREEN}✓ Password reset for $USERNAME${NC}"
    echo ""
    echo "New password: $NEW_PASSWORD"
    echo ""
    echo "User can login with:"
    echo "  ssh -p 2222 $USERNAME@$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'server-ip')"
    echo ""
}

# ============================
# TEST
# ============================
test_ssh_config() {
    USERNAME="$1"
    
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}Error: Username required${NC}"
        echo "Usage: $0 test <username>"
        exit 1
    fi
    
    echo -e "${YELLOW}Testing password SSH for $USERNAME...${NC}"
    echo ""
    
    # Check user exists in DB
    if ! grep -q "^$USERNAME:" "$USERS_DB" 2>/dev/null; then
        echo -e "${RED}✗ User not in database${NC}"
        exit 1
    else
        echo -e "${GREEN}✓ User exists in database${NC}"
    fi
    
    # Check Linux user
    if id "$USERNAME" &>/dev/null; then
        echo -e "${GREEN}✓ Linux user exists${NC}"
    else
        echo -e "${RED}✗ Linux user missing (will be created on first login)${NC}"
    fi
    
    # Check container
    USER_DATA=$(grep "^$USERNAME:" "$USERS_DB")
    CONTAINER=$(echo "$USER_DATA" | cut -d: -f2)
    
    if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
        echo -e "${GREEN}✓ Container running${NC}"
    else
        echo -e "${YELLOW}⚠️  Container not running (will start on login)${NC}"
    fi
    
    # Check password
    if [ -f "/var/lib/user-containers/users/$USERNAME/password.txt" ]; then
        PASSWORD=$(cat "/var/lib/user-containers/users/$USERNAME/password.txt")
        echo -e "${GREEN}✓ Password: $PASSWORD${NC}"
    else
        echo -e "${RED}✗ Password file missing${NC}"
    fi
    
    echo ""
    echo "User connects with:"
    echo "  ssh -p 2222 $USERNAME@$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'server-ip')"
    echo "  Password: $PASSWORD"
    echo ""
}

# ============================
# MAIN
# ============================
case "${1:-}" in
    setup)
        setup_gateway
        ;;
    sync-user)
        sync_user "$2" "$3"
        ;;
    list)
        list_ssh_users
        ;;
    reset-password)
        reset_password "$2"
        ;;
    test)
        test_ssh_config "$2"
        ;;
    *)
        show_help
        ;;
esac
