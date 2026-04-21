#!/bin/bash

# Multi-User Docker Container Manager
# Creates isolated Docker containers for each user with access control

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONTAINERS_DIR="/var/lib/user-containers"
USERS_DB="$CONTAINERS_DIR/users.db"
LOG_FILE="$CONTAINERS_DIR/access.log"

# Default container settings
DEFAULT_IMAGE="ubuntu:22.04"
DEFAULT_CPU_LIMIT="1.0"      # 100% of 1 CPU
DEFAULT_MEMORY_LIMIT="512m"   # 512 MB RAM
DEFAULT_DISK_LIMIT="5G"       # 5 GB disk

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

show_help() {
    echo -e "${BLUE}Multi-User Docker Container Manager${NC}"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Admin Commands:"
    echo "  init                    - Initialize system (run once)"
    echo "  setup-ssh               - Setup SSH gateway (port 2222)"
    echo "  create-user <username>  - Create new user with container"
    echo "  delete-user <username>  - Delete user and their container"
    echo "  list-users              - List all users and their containers"
    echo "  reset-password <user>   - Reset user's password (admin)"
    echo "  monitor                 - Monitor all containers"
    echo ""
    echo "Container Operations:"
    echo "  start <username>        - Start user's container"
    echo "  stop <username>         - Stop user's container"
    echo "  restart <username>      - Restart user's container"
    echo "  shell <username>        - Open shell in user's container"
    echo "  logs <username>         - View user's container logs"
    echo "  stats <username>        - Show container resource usage"
    echo ""
    echo "Options (for create-user):"
    echo "  --image <image>         - Docker image (default: ubuntu:22.04)"
    echo "  --cpu <limit>           - CPU limit (default: 1.0)"
    echo "  --memory <limit>        - Memory limit (default: 512m)"
    echo "  --disk <limit>          - Disk limit (default: 5G)"
    echo ""
    echo "User Access:"
    echo "  Users connect via SSH:  ssh -p 2222 username@your-server-ip"
    echo "  Change password:        passwd (inside container)"
    echo ""
    echo "Examples:"
    echo "  sudo $0 init"
    echo "  sudo $0 setup-ssh"
    echo "  sudo $0 create-user john --memory 1g --cpu 2.0"
    echo "  ssh -p 2222 john@server-ip  (user connects)"
    echo ""
}

# ============================
# INITIALIZATION
# ============================
init_system() {
    echo -e "${YELLOW}Initializing multi-user container system...${NC}"
    
    # Create directories
    sudo mkdir -p "$CONTAINERS_DIR"/{containers,users,logs}
    sudo touch "$USERS_DB"
    sudo touch "$LOG_FILE"
    
    # Create user database schema if not exists
    if [ ! -s "$USERS_DB" ]; then
        echo "# User Database - Format: username:container_id:password_hash:created_at:resources" | sudo tee "$USERS_DB" > /dev/null
    fi
    
    # Create dedicated network for containers
    if ! docker network inspect user-containers-net &> /dev/null; then
        docker network create --driver bridge user-containers-net
        log "Created Docker network: user-containers-net"
    fi
    
    # Set permissions
    sudo chmod 755 "$CONTAINERS_DIR"
    sudo chmod 644 "$USERS_DB"
    sudo chmod 644 "$LOG_FILE"
    
    echo -e "${GREEN}✓ System initialized${NC}"
    log "System initialized"
}

# ============================
# USER MANAGEMENT
# ============================
generate_password() {
    openssl rand -base64 12
}

hash_password() {
    echo -n "$1" | sha256sum | awk '{print $1}'
}

user_exists() {
    grep -q "^$1:" "$USERS_DB" 2>/dev/null
}

create_user() {
    USERNAME="$1"
    IMAGE="${2:-$DEFAULT_IMAGE}"
    CPU_LIMIT="${3:-$DEFAULT_CPU_LIMIT}"
    MEMORY_LIMIT="${4:-$DEFAULT_MEMORY_LIMIT}"
    DISK_LIMIT="${5:-$DEFAULT_DISK_LIMIT}"
    
    if user_exists "$USERNAME"; then
        echo -e "${RED}✗ User $USERNAME already exists${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Creating user: $USERNAME${NC}"
    
    # Generate password
    PASSWORD=$(generate_password)
    PASSWORD_HASH=$(hash_password "$PASSWORD")
    
    # Create container name
    CONTAINER_NAME="user-${USERNAME}-$(date +%s)"
    
    # Create user directory
    USER_DIR="$CONTAINERS_DIR/users/$USERNAME"
    sudo mkdir -p "$USER_DIR"/{home,data,logs}
    
    echo "  Container: $CONTAINER_NAME"
    echo "  Image: $IMAGE"
    echo "  CPU: $CPU_LIMIT cores"
    echo "  Memory: $MEMORY_LIMIT"
    echo "  Disk: $DISK_LIMIT"
    
    # Create and start container
    echo "  Creating container..."
    docker run -d \
        --name "$CONTAINER_NAME" \
        --hostname "$USERNAME-container" \
        --network user-containers-net \
        --cpus="$CPU_LIMIT" \
        --memory="$MEMORY_LIMIT" \
        --storage-opt size="$DISK_LIMIT" \
        -v "$USER_DIR/home:/home/$USERNAME" \
        -v "$USER_DIR/data:/data" \
        -e "USER=$USERNAME" \
        -e "USER_PASSWORD=$PASSWORD" \
        --label "user=$USERNAME" \
        --label "managed=true" \
        --restart unless-stopped \
        "$IMAGE" \
        sleep infinity
    
    # Setup user inside container
    docker exec "$CONTAINER_NAME" bash -c "
        # Create user
        useradd -m -s /bin/bash $USERNAME
        echo '$USERNAME:$PASSWORD' | chpasswd
        
        # Install sudo and passwd if not present
        if command -v apt-get &> /dev/null; then
            apt-get update -qq && apt-get install -y -qq sudo passwd > /dev/null 2>&1
        elif command -v yum &> /dev/null; then
            yum install -y -q sudo passwd > /dev/null 2>&1
        fi
        
        # Add user to sudoers (allow passwd command)
        usermod -aG sudo $USERNAME 2>/dev/null || true
        echo '$USERNAME ALL=(ALL) NOPASSWD: /usr/bin/passwd' > /etc/sudoers.d/$USERNAME
        chmod 440 /etc/sudoers.d/$USERNAME
        
        # Setup SSH
        mkdir -p /home/$USERNAME/.ssh
        chown -R $USERNAME:$USERNAME /home/$USERNAME
        chmod 700 /home/$USERNAME/.ssh
    " 2>/dev/null || true
    
    # DON'T create system user - SSH gateway will handle routing with dockergw user
    # The password database will be used for authentication
    
    # Save user to database
    echo "$USERNAME:$CONTAINER_NAME:$PASSWORD_HASH:$(date +%s):cpu=$CPU_LIMIT,mem=$MEMORY_LIMIT,disk=$DISK_LIMIT" | sudo tee -a "$USERS_DB" > /dev/null
    
    # Save password to file
    echo "$PASSWORD" | sudo tee "$USER_DIR/password.txt" > /dev/null
    sudo chmod 600 "$USER_DIR/password.txt"
    
    echo ""
    echo -e "${GREEN}✓ User created successfully${NC}"
    echo ""
    echo "─────────────────────────────────"
    echo "Username: $USERNAME"
    echo "Password: $PASSWORD"
    echo "Container: $CONTAINER_NAME"
    echo ""
    echo "User can connect via SSH:"
    echo "  ssh -p 2222 $USERNAME@$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'your-server-ip')"
    echo ""
    echo "Change password: Run 'passwd' inside container"
    echo ""
    echo "Admin commands:"
    echo "  Shell:  sudo $0 shell $USERNAME"
    echo "  Logs:   sudo $0 logs $USERNAME"
    echo "─────────────────────────────────"
    echo ""
    
    log "User created: $USERNAME (container: $CONTAINER_NAME)"
}

delete_user() {
    USERNAME="$1"
    
    if ! user_exists "$USERNAME"; then
        echo -e "${RED}✗ User $USERNAME does not exist${NC}"
        return 1
    fi
    
    read -p "Delete user $USERNAME and all data? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Cancelled"
        return 0
    fi
    
    echo -e "${YELLOW}Deleting user: $USERNAME${NC}"
    
    # Get container name
    CONTAINER_NAME=$(grep "^$USERNAME:" "$USERS_DB" | cut -d: -f2)
    
    # Stop and remove container
    if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        echo "  ✓ Container removed"
    fi
    
    # Remove user directory
    USER_DIR="$CONTAINERS_DIR/users/$USERNAME"
    if [ -d "$USER_DIR" ]; then
        sudo rm -rf "$USER_DIR"
        echo "  ✓ User data removed"
    fi
    
    # Remove from database
    sudo sed -i "/^$USERNAME:/d" "$USERS_DB"
    
    echo -e "${GREEN}✓ User deleted${NC}"
    log "User deleted: $USERNAME"
}

list_users() {
    echo -e "${BLUE}=== User Containers ===${NC}"
    echo ""
    printf "%-15s %-30s %-10s %-12s %s\n" "USERNAME" "CONTAINER" "STATUS" "UPTIME" "RESOURCES"
    echo "────────────────────────────────────────────────────────────────────────────────"
    
    while IFS=: read -r username container_name _ created_at resources; do
        if [ "$username" = "#"* ]; then
            continue
        fi
        
        # Get container status
        if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
            STATUS="${GREEN}running${NC}"
            UPTIME=$(docker ps --filter "name=$container_name" --format '{{.Status}}')
        else
            STATUS="${RED}stopped${NC}"
            UPTIME="N/A"
        fi
        
        printf "%-15s %-30s %-10s %-12s %s\n" "$username" "$container_name" "$(echo -e $STATUS)" "$UPTIME" "$resources"
        
    done < "$USERS_DB"
}

# ============================
# CONTAINER OPERATIONS
# ============================
get_container_name() {
    USERNAME="$1"
    if ! user_exists "$USERNAME"; then
        echo -e "${RED}✗ User $USERNAME does not exist${NC}" >&2
        return 1
    fi
    grep "^$USERNAME:" "$USERS_DB" | cut -d: -f2
}

start_container() {
    USERNAME="$1"
    CONTAINER=$(get_container_name "$USERNAME") || return 1
    
    if docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
        echo -e "${YELLOW}Container already running${NC}"
        return 0
    fi
    
    echo "Starting container for $USERNAME..."
    docker start "$CONTAINER"
    echo -e "${GREEN}✓ Container started${NC}"
    log "Container started: $USERNAME"
}

stop_container() {
    USERNAME="$1"
    CONTAINER=$(get_container_name "$USERNAME") || return 1
    
    echo "Stopping container for $USERNAME..."
    docker stop "$CONTAINER"
    echo -e "${GREEN}✓ Container stopped${NC}"
    log "Container stopped: $USERNAME"
}

restart_container() {
    USERNAME="$1"
    CONTAINER=$(get_container_name "$USERNAME") || return 1
    
    echo "Restarting container for $USERNAME..."
    docker restart "$CONTAINER"
    echo -e "${GREEN}✓ Container restarted${NC}"
    log "Container restarted: $USERNAME"
}

exec_in_container() {
    USERNAME="$1"
    shift
    COMMAND="$@"
    
    CONTAINER=$(get_container_name "$USERNAME") || return 1
    
    if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
        echo -e "${RED}✗ Container is not running${NC}"
        return 1
    fi
    
    docker exec -it -u "$USERNAME" "$CONTAINER" bash -c "$COMMAND"
    log "Command executed in $USERNAME container: $COMMAND"
}

open_shell() {
    USERNAME="$1"
    CONTAINER=$(get_container_name "$USERNAME") || return 1
    
    if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
        echo -e "${RED}✗ Container is not running. Starting...${NC}"
        start_container "$USERNAME"
        sleep 2
    fi
    
    echo -e "${GREEN}Opening shell for $USERNAME...${NC}"
    echo "Type 'exit' to leave the container shell"
    echo ""
    
    docker exec -it -u "$USERNAME" -w "/home/$USERNAME" "$CONTAINER" bash
    log "Shell opened: $USERNAME"
}

show_logs() {
    USERNAME="$1"
    LINES="${2:-50}"
    CONTAINER=$(get_container_name "$USERNAME") || return 1
    
    docker logs --tail "$LINES" -f "$CONTAINER"
}

show_stats() {
    USERNAME="$1"
    CONTAINER=$(get_container_name "$USERNAME") || return 1
    
    if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
        echo -e "${RED}✗ Container is not running${NC}"
        return 1
    fi
    
    docker stats --no-stream "$CONTAINER"
}

# ============================
# ACCESS CONTROL
# ============================
reset_password() {
    USERNAME="$1"
    CONTAINER=$(get_container_name "$USERNAME") || return 1
    
    NEW_PASSWORD=$(generate_password)
    PASSWORD_HASH=$(hash_password "$NEW_PASSWORD")
    
    # Update password in container
    docker exec "$CONTAINER" bash -c "echo '$USERNAME:$NEW_PASSWORD' | chpasswd"
    
    # Update database
    sudo sed -i "s/^$USERNAME:\([^:]*\):\([^:]*\):/$USERNAME:\1:$PASSWORD_HASH:/" "$USERS_DB"
    
    # Save to file
    USER_DIR="$CONTAINERS_DIR/users/$USERNAME"
    echo "$NEW_PASSWORD" | sudo tee "$USER_DIR/password.txt" > /dev/null
    sudo chmod 600 "$USER_DIR/password.txt"
    
    echo -e "${GREEN}✓ Password reset${NC}"
    echo "New password: $NEW_PASSWORD"
    log "Password reset: $USERNAME"
}

# ============================
# MONITORING
# ============================
monitor_all() {
    echo -e "${BLUE}=== Container Monitoring ===${NC}"
    echo ""
    
    # Get all managed containers
    CONTAINERS=$(docker ps --filter "label=managed=true" --format '{{.Names}}')
    
    if [ -z "$CONTAINERS" ]; then
        echo "No containers running"
        return 0
    fi
    
    docker stats --no-stream $CONTAINERS
}

# ============================
# SSH GATEWAY SETUP
# ============================
setup_ssh_gateway() {
    echo -e "${YELLOW}Setting up SSH gateway...${NC}"
    
    # Check if SSH is installed
    if ! command -v sshd &> /dev/null; then
        echo "Installing OpenSSH server..."
        if [ -f /etc/debian_version ]; then
            apt-get update && apt-get install -y openssh-server
        elif [ -f /etc/redhat-release ]; then
            yum install -y openssh-server
        else
            echo -e "${RED}Error: Unsupported OS${NC}"
            exit 1
        fi
    fi
    
    # Create SSH forced command script
    mkdir -p /usr/local/bin
    cat > /usr/local/bin/container-ssh-wrapper << 'SSHEOF'
#!/bin/bash

# SSH wrapper - routes user to their container

USERS_DB="/var/lib/user-containers/users.db"
USERNAME="$USER"

# Get user's container
if ! grep -q "^$USERNAME:" "$USERS_DB" 2>/dev/null; then
    echo "Error: Container access not configured"
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
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSH: $USERNAME -> $CONTAINER from $SSH_CLIENT" >> /var/lib/user-containers/logs/access.log

# Connect to container
exec docker exec -it -u "$USERNAME" -w "/home/$USERNAME" "$CONTAINER" bash -l
SSHEOF
    
    chmod +x /usr/local/bin/container-ssh-wrapper
    
    # Backup SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Configure SSH to use alternate port
    if ! grep -q "Port 2222" /etc/ssh/sshd_config; then
        echo "" >> /etc/ssh/sshd_config
        echo "# Container Gateway Configuration" >> /etc/ssh/sshd_config
        echo "Port 2222" >> /etc/ssh/sshd_config
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    fi
    
    # Restart SSH
    systemctl restart sshd || systemctl restart ssh
    
    echo ""
    echo -e "${GREEN}✓ SSH gateway configured${NC}"
    echo ""
    echo "Users can now connect via:"
    echo "  ssh -p 2222 username@$(hostname -I | awk '{print $1}')"
    echo ""
    echo "Password change: Users run 'passwd' inside their container"
    echo ""
}

# ============================
# MAIN
# ============================

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    exit 1
fi

# Check root/sudo
if [ "$EUID" -ne 0 ] && [ "$1" != "shell" ] && [ "$1" != "exec" ] && [ "$1" != "logs" ] && [ "$1" != "stats" ]; then
    echo -e "${YELLOW}Some commands require sudo privileges${NC}"
fi

# Parse command
COMMAND="$1"
shift || true

case "$COMMAND" in
    init)
        init_system
        ;;
    create-user)
        USERNAME="$1"
        shift
        
        # Parse options
        IMAGE="$DEFAULT_IMAGE"
        CPU="$DEFAULT_CPU_LIMIT"
        MEMORY="$DEFAULT_MEMORY_LIMIT"
        DISK="$DEFAULT_DISK_LIMIT"
        
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --image) IMAGE="$2"; shift 2 ;;
                --cpu) CPU="$2"; shift 2 ;;
                --memory) MEMORY="$2"; shift 2 ;;
                --disk) DISK="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        
        create_user "$USERNAME" "$IMAGE" "$CPU" "$MEMORY" "$DISK"
        ;;
    delete-user)
        delete_user "$1"
        ;;
    list-users)
        list_users
        ;;
    start)
        start_container "$1"
        ;;
    stop)
        stop_container "$1"
        ;;
    restart)
        restart_container "$1"
        ;;
    exec)
        exec_in_container "$@"
        ;;
    shell)
        open_shell "$1"
        ;;
    logs)
        show_logs "$1" "${2:-50}"
        ;;
    stats)
        show_stats "$1"
        ;;
    reset-password)
        reset_password "$1"
        ;;
    monitor)
        monitor_all
        ;;
    setup-ssh)
        setup_ssh_gateway
        ;;
    *)
        show_help
        ;;
esac
