#!/bin/bash

# Cloudflare Tunnel Setup for Laptop Server
# This bypasses the need for port forwarding and gives you HTTPS automatically

set -e

echo "=================================="
echo "Cloudflare Tunnel Setup"
echo "=================================="
echo ""
echo "This will:"
echo "  1. Create a secure tunnel from your laptop to Cloudflare"
echo "  2. Give you a public domain with auto-SSL"
echo "  3. Bypass port forwarding (works with WiFi!)"
echo "  4. Protect against DDoS"
echo ""
echo "Prerequisites:"
echo "  - Cloudflare account (free)"
echo "  - Domain added to Cloudflare (or use their free subdomain)"
echo ""
read -p "Press Enter to continue..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================
# 1. LOGIN TO CLOUDFLARE
# ============================
echo -e "${YELLOW}Step 1: Login to Cloudflare${NC}"
echo "This will open a browser window..."
cloudflared tunnel login

if [ ! -f ~/.cloudflared/cert.pem ]; then
    echo "Login failed! Please try again."
    exit 1
fi

echo -e "${GREEN}✓ Logged in successfully${NC}"

# ============================
# 2. CREATE TUNNEL
# ============================
echo ""
echo -e "${YELLOW}Step 2: Creating tunnel${NC}"
read -p "Enter tunnel name (e.g., laptop-server): " TUNNEL_NAME

cloudflared tunnel create $TUNNEL_NAME

# Get tunnel ID
TUNNEL_ID=$(cloudflared tunnel list | grep $TUNNEL_NAME | awk '{print $1}')

if [ -z "$TUNNEL_ID" ]; then
    echo "Failed to create tunnel!"
    exit 1
fi

echo -e "${GREEN}✓ Tunnel created: $TUNNEL_ID${NC}"

# ============================
# 3. CONFIGURE DOMAINS
# ============================
echo ""
echo -e "${YELLOW}Step 3: Configure domains${NC}"
echo "Enter your domains (or use Cloudflare's free .trycloudflare.com)"
echo ""

read -p "Enter main domain (e.g., example.com) or press Enter for free subdomain: " MAIN_DOMAIN

if [ -z "$MAIN_DOMAIN" ]; then
    echo "Using Cloudflare's free tunnel domain..."
    USE_FREE_DOMAIN=true
else
    # Setup DNS routes
    echo "Setting up DNS routes..."
    
    read -p "Subdomain for Sparkles API (e.g., api): " API_SUBDOMAIN
    read -p "Subdomain for Sparkles Web (e.g., www or app): " WEB_SUBDOMAIN
    read -p "Subdomain for docs-portal (e.g., docs): " DOCS_SUBDOMAIN
    read -p "Subdomain for OrchestAI (e.g., orchestai): " ORCH_SUBDOMAIN
    
    # Create DNS records
    cloudflared tunnel route dns $TUNNEL_NAME ${API_SUBDOMAIN}.${MAIN_DOMAIN}
    cloudflared tunnel route dns $TUNNEL_NAME ${WEB_SUBDOMAIN}.${MAIN_DOMAIN}
    cloudflared tunnel route dns $TUNNEL_NAME ${DOCS_SUBDOMAIN}.${MAIN_DOMAIN}
    cloudflared tunnel route dns $TUNNEL_NAME ${ORCH_SUBDOMAIN}.${MAIN_DOMAIN}
    
    echo -e "${GREEN}✓ DNS routes configured${NC}"
fi

# ============================
# 4. CREATE CONFIG FILE
# ============================
echo ""
echo -e "${YELLOW}Step 4: Creating tunnel configuration${NC}"

CREDS_FILE=~/.cloudflared/${TUNNEL_ID}.json

if [ "$USE_FREE_DOMAIN" = true ]; then
    # Simple config for free domain
    cat > ~/.cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: $CREDS_FILE

# No hostname = use free .trycloudflare.com domain
ingress:
  - service: http://localhost:5000
EOF
    
    echo -e "${GREEN}✓ Config created for free domain${NC}"
    echo ""
    echo "Your apps will be available at:"
    echo "  https://[random].trycloudflare.com"
    echo ""
    echo "Run this to start: cloudflared tunnel run $TUNNEL_NAME"
    
else
    # Full config with custom domains
    cat > ~/.cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: $CREDS_FILE

ingress:
  # Sparkles API (4 microservices)
  - hostname: ${API_SUBDOMAIN}.${MAIN_DOMAIN}
    path: /auth/*
    service: http://localhost:8081
  - hostname: ${API_SUBDOMAIN}.${MAIN_DOMAIN}
    path: /dashboard/*
    service: http://localhost:8082
  - hostname: ${API_SUBDOMAIN}.${MAIN_DOMAIN}
    path: /goals/*
    service: http://localhost:8083
  - hostname: ${API_SUBDOMAIN}.${MAIN_DOMAIN}
    path: /vault/*
    service: http://localhost:8084
  
  # Sparkles Web (static frontend)
  - hostname: ${WEB_SUBDOMAIN}.${MAIN_DOMAIN}
    service: http://localhost:5173
  
  # docs-portal (Next.js)
  - hostname: ${DOCS_SUBDOMAIN}.${MAIN_DOMAIN}
    service: http://localhost:3032
  
  # OrchestAI
  - hostname: ${ORCH_SUBDOMAIN}.${MAIN_DOMAIN}
    service: http://localhost:9000
  
  # Catch-all
  - service: http_status:404
EOF

    echo -e "${GREEN}✓ Config created${NC}"
    echo ""
    echo "Your domains:"
    echo "  Sparkles API: https://${API_SUBDOMAIN}.${MAIN_DOMAIN}"
    echo "  Sparkles Web: https://${WEB_SUBDOMAIN}.${MAIN_DOMAIN}"
    echo "  docs-portal:  https://${DOCS_SUBDOMAIN}.${MAIN_DOMAIN}"
    echo "  OrchestAI:    https://${ORCH_SUBDOMAIN}.${MAIN_DOMAIN}"
fi

# ============================
# 5. INSTALL AS SERVICE
# ============================
echo ""
echo -e "${YELLOW}Step 5: Installing as system service${NC}"

sudo cloudflared service install

echo -e "${GREEN}✓ Service installed${NC}"

# ============================
# 6. START TUNNEL
# ============================
echo ""
echo -e "${YELLOW}Step 6: Starting tunnel${NC}"

sudo systemctl start cloudflared
sudo systemctl enable cloudflared

sleep 3

if systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}✓ Tunnel is running!${NC}"
else
    echo "Failed to start tunnel. Check logs: sudo journalctl -u cloudflared -f"
    exit 1
fi

# ============================
# COMPLETION
# ============================
echo ""
echo "=================================="
echo -e "${GREEN}✓ Cloudflare Tunnel Setup Complete!${NC}"
echo "=================================="
echo ""
echo "Commands:"
echo "  Check status:  sudo systemctl status cloudflared"
echo "  View logs:     sudo journalctl -u cloudflared -f"
echo "  Restart:       sudo systemctl restart cloudflared"
echo "  Stop:          sudo systemctl stop cloudflared"
echo ""
echo "Next steps:"
echo "  1. Start your applications (Sparkles, OrchestAI, docs)"
echo "  2. Access via the domains above"
echo "  3. Tunnel handles SSL automatically!"
echo ""
echo "Config file: ~/.cloudflared/config.yml"
echo "Tunnel ID: $TUNNEL_ID"
echo ""

if [ "$USE_FREE_DOMAIN" = true ]; then
    echo "To see your free domain URL, run:"
    echo "  sudo journalctl -u cloudflared -n 50 | grep trycloudflare.com"
fi
