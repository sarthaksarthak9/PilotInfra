#!/bin/bash

# Web Terminal Gateway for Multi-User Containers
# Provides browser-based terminal access using ttyd

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
WEB_PORT=7681
GATEWAY_DIR="/var/lib/container-gateway"
USERS_DB="/var/lib/user-containers/users.db"
TTYD_BIN="/usr/local/bin/ttyd"

show_help() {
    echo "Web Terminal Gateway for Multi-User Containers"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup              - Install ttyd and configure web gateway"
    echo "  start              - Start web terminal gateway"
    echo "  stop               - Stop web terminal gateway"
    echo "  restart            - Restart web terminal gateway"
    echo "  status             - Show gateway status"
    echo "  logs               - View gateway logs"
    echo "  enable-ssl         - Enable HTTPS (requires domain)"
    echo ""
    echo "After setup, users can access at:"
    echo "  http://your-server-ip:$WEB_PORT/?username=USERNAME&password=PASSWORD"
    echo ""
}

# ============================
# SETUP
# ============================
setup_web_gateway() {
    echo -e "${BLUE}Setting up Web Terminal Gateway...${NC}"
    
    # Install ttyd
    if [ ! -f "$TTYD_BIN" ]; then
        echo "Installing ttyd..."
        cd /tmp
        TTYD_VERSION="1.7.7"
        wget -q "https://github.com/tsl0922/ttyd/releases/download/$TTYD_VERSION/ttyd.x86_64" -O ttyd
        sudo mv ttyd "$TTYD_BIN"
        sudo chmod +x "$TTYD_BIN"
        echo "✓ ttyd installed"
    fi
    
    # Create gateway script
    sudo mkdir -p "$GATEWAY_DIR/bin"
    
    sudo tee "$GATEWAY_DIR/bin/web-gateway.sh" > /dev/null << 'EOF'
#!/bin/bash

# Web Terminal Gateway Script

USERS_DB="/var/lib/user-containers/users.db"
LOG_FILE="/var/lib/container-gateway/logs/web-access.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Read credentials from query parameters (passed by ttyd)
read -p "Username: " USERNAME
read -sp "Password: " PASSWORD
echo ""

# Validate user
if ! grep -q "^$USERNAME:" "$USERS_DB"; then
    echo "Access denied: User not found"
    log "Access denied: $USERNAME (user not found)"
    sleep 3
    exit 1
fi

# Get user data
USER_DATA=$(grep "^$USERNAME:" "$USERS_DB")
CONTAINER=$(echo "$USER_DATA" | cut -d: -f2)
PASSWORD_HASH=$(echo "$USER_DATA" | cut -d: -f3)

# Verify password
INPUT_HASH=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')
if [ "$INPUT_HASH" != "$PASSWORD_HASH" ]; then
    echo "Access denied: Invalid password"
    log "Access denied: $USERNAME (invalid password)"
    sleep 3
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER$"; then
    echo "Starting your container..."
    docker start "$CONTAINER" > /dev/null 2>&1
    sleep 2
fi

# Log successful access
log "Web access granted: $USERNAME -> $CONTAINER"

# Clear screen and connect
clear
echo "Welcome $USERNAME!"
echo "Container: $CONTAINER"
echo ""

# Execute shell in container
docker exec -it -u "$USERNAME" -w "/home/$USERNAME" "$CONTAINER" bash
EOF
    
    sudo chmod +x "$GATEWAY_DIR/bin/web-gateway.sh"
    
    # Create systemd service
    sudo tee /etc/systemd/system/web-terminal-gateway.service > /dev/null << EOF
[Unit]
Description=Web Terminal Gateway for User Containers
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
ExecStart=$TTYD_BIN \\
    --port $WEB_PORT \\
    --writable \\
    --title-format "Container Terminal" \\
    --reconnect 10 \\
    $GATEWAY_DIR/bin/web-gateway.sh

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable web-terminal-gateway
    
    # Add firewall rule
    if command -v ufw &> /dev/null; then
        sudo ufw allow $WEB_PORT/tcp comment 'Web Terminal Gateway'
        echo "✓ Firewall rule added"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Web Terminal Gateway setup complete${NC}"
    echo ""
    echo "Start the gateway with:"
    echo "  $0 start"
    echo ""
    echo "Access at:"
    echo "  http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
}

# ============================
# SERVICE MANAGEMENT
# ============================
start_gateway() {
    sudo systemctl start web-terminal-gateway
    echo -e "${GREEN}✓ Web Terminal Gateway started${NC}"
    echo ""
    echo "Access at: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
}

stop_gateway() {
    sudo systemctl stop web-terminal-gateway
    echo -e "${GREEN}✓ Web Terminal Gateway stopped${NC}"
}

restart_gateway() {
    sudo systemctl restart web-terminal-gateway
    echo -e "${GREEN}✓ Web Terminal Gateway restarted${NC}"
}

show_status() {
    sudo systemctl status web-terminal-gateway
}

show_logs() {
    sudo journalctl -u web-terminal-gateway -f
}

# ============================
# SSL SETUP
# ============================
enable_ssl() {
    echo "SSL Setup for Web Terminal Gateway"
    echo ""
    
    read -p "Your domain name: " DOMAIN
    read -p "Your email: " EMAIL
    
    # Install certbot
    if ! command -v certbot &> /dev/null; then
        echo "Installing certbot..."
        sudo apt update
        sudo apt install -y certbot
    fi
    
    # Get certificate
    sudo certbot certonly --standalone \
        -d "$DOMAIN" \
        --email "$EMAIL" \
        --agree-tos \
        --non-interactive
    
    # Update systemd service with SSL
    sudo tee /etc/systemd/system/web-terminal-gateway.service > /dev/null << EOF
[Unit]
Description=Web Terminal Gateway for User Containers (HTTPS)
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
ExecStart=$TTYD_BIN \\
    --port $WEB_PORT \\
    --ssl \\
    --ssl-cert /etc/letsencrypt/live/$DOMAIN/fullchain.pem \\
    --ssl-key /etc/letsencrypt/live/$DOMAIN/privkey.pem \\
    --writable \\
    --title-format "Container Terminal" \\
    --reconnect 10 \\
    $GATEWAY_DIR/bin/web-gateway.sh

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl restart web-terminal-gateway
    
    echo ""
    echo -e "${GREEN}✓ SSL enabled${NC}"
    echo ""
    echo "Access at: https://$DOMAIN:$WEB_PORT"
}

# ============================
# MAIN
# ============================

case "$1" in
    setup)
        setup_web_gateway
        ;;
    start)
        start_gateway
        ;;
    stop)
        stop_gateway
        ;;
    restart)
        restart_gateway
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    enable-ssl)
        enable_ssl
        ;;
    *)
        show_help
        ;;
esac
