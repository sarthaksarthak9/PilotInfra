#!/bin/bash

# VPS Migration Script
# Migrates laptop server setup to Hetzner/Vultr/DigitalOcean VPS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}VPS Migration Script${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# ============================
# CONFIGURATION
# ============================

read -p "VPS IP address: " VPS_IP
read -p "VPS SSH user (default: root): " VPS_USER
VPS_USER=${VPS_USER:-root}
read -p "VPS SSH port (default: 22): " VPS_PORT
VPS_PORT=${VPS_PORT:-22}

echo ""
echo -e "${YELLOW}Testing SSH connection...${NC}"

if ssh -p $VPS_PORT -o ConnectTimeout=5 ${VPS_USER}@${VPS_IP} "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ Cannot connect to VPS${NC}"
    echo "Make sure:"
    echo "  1. VPS is running"
    echo "  2. SSH key is added: ssh-copy-id -p $VPS_PORT ${VPS_USER}@${VPS_IP}"
    echo "  3. Firewall allows SSH"
    exit 1
fi

# ============================
# STEP 1: BACKUP LAPTOP DATA
# ============================

echo ""
echo -e "${BLUE}[1/8] Creating backup...${NC}"

if [ -f "./auto-backup.sh" ]; then
    ./auto-backup.sh
    BACKUP_FILE=$(ls -t ~/backups/backup_*.tar.gz | head -1)
    echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
else
    echo -e "${YELLOW}⚠ auto-backup.sh not found, skipping backup${NC}"
    BACKUP_FILE=""
fi

# ============================
# STEP 2: INSTALL DEPENDENCIES ON VPS
# ============================

echo ""
echo -e "${BLUE}[2/8] Installing dependencies on VPS...${NC}"

ssh -p $VPS_PORT ${VPS_USER}@${VPS_IP} << 'ENDSSH'
set -e

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
fi

echo "Installing Docker Compose..."
sudo apt install -y docker-compose-plugin

echo "Installing Go..."
if ! command -v go &> /dev/null; then
    cd /tmp
    wget -q https://go.dev/dl/go1.23.6.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.23.6.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
fi

echo "Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

echo "Installing PM2..."
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
fi

echo "Installing Caddy..."
if ! command -v caddy &> /dev/null; then
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install -y caddy
fi

echo "Installing monitoring tools..."
sudo apt install -y htop net-tools

echo "Configuring firewall..."
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "✓ Dependencies installed"
ENDSSH

echo -e "${GREEN}✓ VPS dependencies installed${NC}"

# ============================
# STEP 3: TRANSFER PROJECT CODE
# ============================

echo ""
echo -e "${BLUE}[3/8] Transferring project code...${NC}"

PROJECT_ROOT="$HOME/servers"

ssh -p $VPS_PORT ${VPS_USER}@${VPS_IP} "mkdir -p ~/servers"

for project in sparkles sparkles-web orchestai docs-portal; do
    if [ -d "$PROJECT_ROOT/$project" ]; then
        echo "  Transferring $project..."
        rsync -avz --progress -e "ssh -p $VPS_PORT" \
            --exclude 'node_modules' \
            --exclude '.git' \
            --exclude 'dist' \
            --exclude 'build' \
            --exclude 'bin' \
            "$PROJECT_ROOT/$project/" \
            ${VPS_USER}@${VPS_IP}:~/servers/$project/
        echo -e "${GREEN}  ✓ $project transferred${NC}"
    fi
done

# ============================
# STEP 4: TRANSFER DATABASES
# ============================

echo ""
echo -e "${BLUE}[4/8] Transferring databases...${NC}"

if [ ! -z "$BACKUP_FILE" ]; then
    echo "Uploading backup to VPS..."
    scp -P $VPS_PORT "$BACKUP_FILE" ${VPS_USER}@${VPS_IP}:~/backup.tar.gz
    
    ssh -p $VPS_PORT ${VPS_USER}@${VPS_IP} << 'ENDSSH'
cd ~
tar -xzf backup.tar.gz
echo "✓ Backup extracted"
ENDSSH
    
    echo -e "${GREEN}✓ Database backup transferred${NC}"
else
    echo -e "${YELLOW}⚠ No backup to transfer${NC}"
fi

# ============================
# STEP 5: SETUP DATABASES ON VPS
# ============================

echo ""
echo -e "${BLUE}[5/8] Setting up databases on VPS...${NC}"

ssh -p $VPS_PORT ${VPS_USER}@${VPS_IP} << 'ENDSSH'
cd ~/servers/sparkles

if [ -f "docker-compose.yml" ]; then
    echo "Starting databases..."
    docker compose up -d mongodb redis rabbitmq
    sleep 5
    
    # Restore MongoDB if backup exists
    if [ -d ~/*/databases/mongodb ]; then
        echo "Restoring MongoDB..."
        BACKUP_DIR=$(find ~ -type d -name "databases" | head -1)
        docker exec -i mongodb mongorestore "$BACKUP_DIR/mongodb"
        echo "✓ MongoDB restored"
    fi
    
    # Restore Redis if backup exists
    if [ -f ~/*/databases/redis_dump.rdb ]; then
        BACKUP_FILE=$(find ~ -type f -name "redis_dump.rdb" | head -1)
        docker cp "$BACKUP_FILE" redis:/data/dump.rdb
        docker restart redis
        echo "✓ Redis restored"
    fi
fi

cd ~/servers/orchestai
if [ -f "docker-compose.yml" ]; then
    docker compose up -d
fi

echo "✓ Databases running"
ENDSSH

echo -e "${GREEN}✓ Databases setup complete${NC}"

# ============================
# STEP 6: BUILD PROJECTS ON VPS
# ============================

echo ""
echo -e "${BLUE}[6/8] Building projects on VPS...${NC}"

ssh -p $VPS_PORT ${VPS_USER}@${VPS_IP} << 'ENDSSH'
export PATH=$PATH:/usr/local/go/bin

# Build Sparkles
echo "Building Sparkles..."
cd ~/servers/sparkles
mkdir -p bin

for svc in auth-service dashboard-service goals-service vault-service; do
    echo "  Building $svc..."
    cd services/$svc
    CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o ../../bin/$svc ./cmd/api/main.go
    cd ../..
done

# Build Sparkles-web
echo "Building Sparkles-web..."
cd ~/servers/sparkles-web
npm install --production
npm run build

# Build OrchestAI
echo "Building OrchestAI..."
cd ~/servers/orchestai
if [ -d "services" ]; then
    mkdir -p bin
    for svc in services/*/; do
        svc_name=$(basename $svc)
        echo "  Building $svc_name..."
        cd $svc
        CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o ../../bin/$svc_name ./cmd/
        cd ../..
    done
fi

if [ -d "frontend" ]; then
    cd frontend
    npm install --production
    npm run build
    cd ..
fi

# Build docs-portal
echo "Building docs-portal..."
cd ~/servers/docs-portal
npm install --production
npm run build

echo "✓ All projects built"
ENDSSH

echo -e "${GREEN}✓ Build complete${NC}"

# ============================
# STEP 7: START SERVICES ON VPS
# ============================

echo ""
echo -e "${BLUE}[7/8] Starting services on VPS...${NC}"

# Copy deployment script
scp -P $VPS_PORT ./laptop-deploy.sh ${VPS_USER}@${VPS_IP}:~/vps-deploy.sh

ssh -p $VPS_PORT ${VPS_USER}@${VPS_IP} << 'ENDSSH'
chmod +x ~/vps-deploy.sh

# Start Sparkles
cd ~/servers/sparkles
pm2 start bin/auth-service --name "sparkles-auth"
pm2 start bin/dashboard-service --name "sparkles-dashboard"
pm2 start bin/goals-service --name "sparkles-goals"
pm2 start bin/vault-service --name "sparkles-vault"

# Start Sparkles-web
cd ~/servers/sparkles-web
pm2 start npm --name "sparkles-web" -- run preview

# Start OrchestAI
cd ~/servers/orchestai
for binary in bin/*; do
    binary_name=$(basename $binary)
    pm2 start $binary --name "orchestai-$binary_name"
done

# Start docs-portal
cd ~/servers/docs-portal
pm2 start npm --name "docs-portal" -- run start

pm2 save
pm2 startup systemd -u $USER --hp $HOME | sudo bash

echo "✓ All services started"
ENDSSH

echo -e "${GREEN}✓ Services started${NC}"

# ============================
# STEP 8: CONFIGURE CADDY
# ============================

echo ""
echo -e "${BLUE}[8/8] Configuring reverse proxy...${NC}"

read -p "Your domain name (e.g., example.com): " DOMAIN

ssh -p $VPS_PORT ${VPS_USER}@${VPS_IP} << ENDSSH
sudo tee /etc/caddy/Caddyfile > /dev/null << 'EOF'
# Sparkles API
api.$DOMAIN {
    reverse_proxy /auth/* localhost:8081
    reverse_proxy /dashboard/* localhost:8082
    reverse_proxy /goals/* localhost:8083
    reverse_proxy /vault/* localhost:8084
}

# Sparkles Web
$DOMAIN {
    reverse_proxy localhost:5173
}

# docs-portal
docs.$DOMAIN {
    reverse_proxy localhost:3032
}

# OrchestAI
orchestai.$DOMAIN {
    reverse_proxy localhost:9000
}
EOF

sudo systemctl restart caddy
sudo systemctl enable caddy

echo "✓ Caddy configured"
ENDSSH

echo -e "${GREEN}✓ Reverse proxy configured${NC}"

# ============================
# COMPLETION
# ============================

echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}✓ Migration Complete!${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "Your services are now running on VPS:"
echo "  VPS IP: $VPS_IP"
echo "  Domain: $DOMAIN"
echo ""
echo "Access your apps:"
echo "  Sparkles API: https://api.$DOMAIN"
echo "  Sparkles Web: https://$DOMAIN"
echo "  docs-portal:  https://docs.$DOMAIN"
echo "  OrchestAI:    https://orchestai.$DOMAIN"
echo ""
echo "SSH to VPS:"
echo "  ssh -p $VPS_PORT ${VPS_USER}@${VPS_IP}"
echo ""
echo "Check services:"
echo "  pm2 status"
echo "  docker ps"
echo "  sudo systemctl status caddy"
echo ""
echo "Next steps:"
echo "  1. Update DNS A records to point to VPS IP"
echo "  2. Wait for DNS propagation (~5-30 min)"
echo "  3. Test all services"
echo "  4. Setup monitoring (see laptop-health-monitor.sh)"
echo ""
echo "Your laptop can now be shut down safely!"
echo ""
