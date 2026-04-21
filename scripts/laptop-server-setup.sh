#!/bin/bash

# Complete Laptop Server Setup Script
# For: Sparkles + OrchestAI + docs-portal
# Tested on: Ubuntu 22.04/24.04

set -e

echo "================================"
echo "Laptop Server Setup - Starting"
echo "================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================
# 1. SYSTEM UPDATES
# ============================
echo -e "${YELLOW}[1/10] Updating system...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git build-essential net-tools htop lm-sensors

# ============================
# 2. DOCKER INSTALLATION
# ============================
echo -e "${YELLOW}[2/10] Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# ============================
# 3. DOCKER COMPOSE
# ============================
echo -e "${YELLOW}[3/10] Installing Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    sudo apt install -y docker-compose-plugin
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
else
    echo -e "${GREEN}✓ Docker Compose already installed${NC}"
fi

# ============================
# 4. GO INSTALLATION
# ============================
echo -e "${YELLOW}[4/10] Installing Go 1.23...${NC}"
if ! command -v go &> /dev/null; then
    cd /tmp
    wget https://go.dev/dl/go1.23.6.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.23.6.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
    export PATH=$PATH:/usr/local/go/bin
    echo -e "${GREEN}✓ Go installed${NC}"
else
    echo -e "${GREEN}✓ Go already installed${NC}"
fi

# ============================
# 5. NODE.JS INSTALLATION
# ============================
echo -e "${YELLOW}[5/10] Installing Node.js 20...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
    echo -e "${GREEN}✓ Node.js installed${NC}"
else
    echo -e "${GREEN}✓ Node.js already installed${NC}"
fi

# ============================
# 6. PM2 INSTALLATION
# ============================
echo -e "${YELLOW}[6/10] Installing PM2...${NC}"
if ! command -v pm2 &> /dev/null; then
    sudo npm install -g pm2
    pm2 startup systemd -u $USER --hp $HOME
    echo -e "${GREEN}✓ PM2 installed${NC}"
else
    echo -e "${GREEN}✓ PM2 already installed${NC}"
fi

# ============================
# 7. CADDY INSTALLATION
# ============================
echo -e "${YELLOW}[7/10] Installing Caddy...${NC}"
if ! command -v caddy &> /dev/null; then
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install caddy
    echo -e "${GREEN}✓ Caddy installed${NC}"
else
    echo -e "${GREEN}✓ Caddy already installed${NC}"
fi

# ============================
# 8. CLOUDFLARED (Tunnel)
# ============================
echo -e "${YELLOW}[8/10] Installing Cloudflare Tunnel...${NC}"
if ! command -v cloudflared &> /dev/null; then
    cd /tmp
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
    echo -e "${GREEN}✓ Cloudflared installed${NC}"
else
    echo -e "${GREEN}✓ Cloudflared already installed${NC}"
fi

# ============================
# 9. POWER MANAGEMENT
# ============================
echo -e "${YELLOW}[9/10] Configuring power management...${NC}"

# Disable sleep/hibernation
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Configure lid behavior
sudo bash -c 'cat > /etc/systemd/logind.conf << EOF
[Login]
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
LidSwitchIgnoreInhibited=no
EOF'

sudo systemctl restart systemd-logind

# Install TLP for battery management
sudo apt install -y tlp tlp-rdw
sudo bash -c 'cat >> /etc/tlp.conf << EOF
# Battery charge thresholds (60-80% for longevity)
START_CHARGE_THRESH_BAT0=60
STOP_CHARGE_THRESH_BAT0=80
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=performance
EOF'

sudo tlp start

echo -e "${GREEN}✓ Power management configured${NC}"

# ============================
# 10. MONITORING SETUP
# ============================
echo -e "${YELLOW}[10/10] Setting up monitoring...${NC}"

# Temperature monitoring
sudo sensors-detect --auto

# Create monitoring script
cat > ~/server-monitor.sh << 'MONITOR_EOF'
#!/bin/bash
LOGFILE="$HOME/server-monitor.log"

# Get temps
TEMP=$(sensors | grep 'Core 0' | awk '{print $3}' | tr -d '+°C' || echo "0")

# Get memory usage
MEM=$(free -m | awk 'NR==2{printf "%.0f", $3*100/$2}')

# Get disk usage
DISK=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')

# Log
echo "$(date '+%Y-%m-%d %H:%M:%S') | CPU: ${TEMP}°C | RAM: ${MEM}% | Disk: ${DISK}%" >> $LOGFILE

# Alert if critical
if (( $(echo "$TEMP > 85" | bc -l 2>/dev/null || echo "0") )); then
    echo "CRITICAL: CPU temp ${TEMP}°C" | wall
fi

if [ "$MEM" -gt 90 ]; then
    echo "CRITICAL: RAM usage ${MEM}%" | wall
fi
MONITOR_EOF

chmod +x ~/server-monitor.sh

# Run every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * $HOME/server-monitor.sh") | crontab -

echo -e "${GREEN}✓ Monitoring configured${NC}"

# ============================
# FIREWALL SETUP
# ============================
echo -e "${YELLOW}Configuring firewall...${NC}"
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable
echo -e "${GREEN}✓ Firewall configured${NC}"

# ============================
# CREATE PROJECT DIRECTORY
# ============================
echo -e "${YELLOW}Creating project directories...${NC}"
mkdir -p ~/servers/{sparkles,orchestai,docs-portal}
mkdir -p ~/backups
mkdir -p ~/.cloudflared

echo -e "${GREEN}✓ Directories created${NC}"

# ============================
# COMPLETION
# ============================
echo ""
echo "================================"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo "================================"
echo ""
echo "Next steps:"
echo "1. Reboot: sudo reboot"
echo "2. Clone your projects to ~/servers/"
echo "3. Setup Cloudflare Tunnel (see cloudflare-setup.sh)"
echo "4. Deploy apps with deployment scripts"
echo ""
echo "Monitoring:"
echo "  - View temps: sensors"
echo "  - View logs: tail -f ~/server-monitor.log"
echo "  - Check services: pm2 status"
echo ""
echo -e "${YELLOW}⚠️  REBOOT REQUIRED for all changes to take effect${NC}"
