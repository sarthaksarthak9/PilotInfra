#!/bin/bash

# Unified Deployment Script for Laptop Server
# Deploys: Sparkles + OrchestAI + docs-portal

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$HOME/servers"
SPARKLES_DIR="$PROJECT_ROOT/sparkles"
ORCHESTAI_DIR="$PROJECT_ROOT/orchestai"
DOCS_DIR="$PROJECT_ROOT/docs-portal"
SPARKLES_WEB_DIR="$PROJECT_ROOT/sparkles-web"

show_help() {
    echo "Laptop Server Deployment Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup      - Clone projects and setup databases"
    echo "  build      - Build all projects"
    echo "  start      - Start all services"
    echo "  stop       - Stop all services"
    echo "  restart    - Restart all services"
    echo "  status     - Show status of all services"
    echo "  logs       - Show logs for all services"
    echo "  clean      - Stop and clean all services"
    echo "  update     - Pull latest code and restart"
    echo ""
    echo "Individual project commands:"
    echo "  start-sparkles    - Start only Sparkles"
    echo "  start-orchestai   - Start only OrchestAI"
    echo "  start-docs        - Start only docs-portal"
    echo ""
}

# ============================
# SETUP FUNCTION
# ============================
setup_projects() {
    echo -e "${BLUE}Setting up projects...${NC}"
    
    mkdir -p $PROJECT_ROOT
    cd $PROJECT_ROOT
    
    # Clone repositories (update URLs as needed)
    echo -e "${YELLOW}Cloning repositories...${NC}"
    
    if [ ! -d "$SPARKLES_DIR" ]; then
        read -p "Enter Sparkles GitHub URL: " SPARKLES_URL
        git clone $SPARKLES_URL sparkles
    fi
    
    if [ ! -d "$SPARKLES_WEB_DIR" ]; then
        read -p "Enter Sparkles-web GitHub URL: " SPARKLES_WEB_URL
        git clone $SPARKLES_WEB_URL sparkles-web
    fi
    
    if [ ! -d "$ORCHESTAI_DIR" ]; then
        read -p "Enter OrchestAI GitHub URL: " ORCHESTAI_URL
        git clone $ORCHESTAI_URL orchestai
    fi
    
    if [ ! -d "$DOCS_DIR" ]; then
        read -p "Enter docs-portal GitHub URL: " DOCS_URL
        git clone $DOCS_URL docs-portal
    fi
    
    echo -e "${GREEN}✓ Repositories cloned${NC}"
    
    # Setup databases
    echo -e "${YELLOW}Starting databases...${NC}"
    
    cd $SPARKLES_DIR
    if [ -f "docker-compose.yml" ]; then
        docker compose up -d mongodb redis rabbitmq
        sleep 5
        echo -e "${GREEN}✓ Sparkles databases started${NC}"
    fi
    
    cd $ORCHESTAI_DIR
    if [ -f "docker-compose.yml" ]; then
        docker compose up -d
        sleep 3
        echo -e "${GREEN}✓ OrchestAI databases started${NC}"
    fi
    
    echo -e "${GREEN}✓ Setup complete${NC}"
}

# ============================
# BUILD FUNCTION
# ============================
build_all() {
    echo -e "${BLUE}Building all projects...${NC}"
    
    # Build Sparkles
    if [ -d "$SPARKLES_DIR" ]; then
        echo -e "${YELLOW}Building Sparkles...${NC}"
        cd $SPARKLES_DIR
        
        # Build binaries
        for svc in auth-service dashboard-service goals-service vault-service; do
            echo "  Building $svc..."
            cd services/$svc
            CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o ../../bin/$svc ./cmd/api/main.go
            cd ../..
        done
        
        echo -e "${GREEN}✓ Sparkles built${NC}"
    fi
    
    # Build Sparkles-web
    if [ -d "$SPARKLES_WEB_DIR" ]; then
        echo -e "${YELLOW}Building Sparkles-web...${NC}"
        cd $SPARKLES_WEB_DIR
        npm install
        npm run build
        echo -e "${GREEN}✓ Sparkles-web built${NC}"
    fi
    
    # Build OrchestAI
    if [ -d "$ORCHESTAI_DIR" ]; then
        echo -e "${YELLOW}Building OrchestAI...${NC}"
        cd $ORCHESTAI_DIR
        
        # Build Go services (adjust based on your structure)
        if [ -d "services" ]; then
            for svc in services/*/; do
                svc_name=$(basename $svc)
                echo "  Building $svc_name..."
                cd $svc
                CGO_ENABLED=0 go build -ldflags="-s -w" -trimpath -o ../../bin/$svc_name ./cmd/
                cd ../..
            done
        fi
        
        # Build frontends if they exist
        if [ -d "frontend" ]; then
            cd frontend
            npm install
            npm run build
            cd ..
        fi
        
        if [ -d "internal-frontend" ]; then
            cd internal-frontend
            npm install
            npm run build
            cd ..
        fi
        
        echo -e "${GREEN}✓ OrchestAI built${NC}"
    fi
    
    # Build docs-portal
    if [ -d "$DOCS_DIR" ]; then
        echo -e "${YELLOW}Building docs-portal...${NC}"
        cd $DOCS_DIR
        npm install
        npm run build
        echo -e "${GREEN}✓ docs-portal built${NC}"
    fi
    
    echo -e "${GREEN}✓ All projects built${NC}"
}

# ============================
# START FUNCTIONS
# ============================
start_sparkles() {
    echo -e "${YELLOW}Starting Sparkles services...${NC}"
    cd $SPARKLES_DIR
    
    # Start databases if not running
    docker compose up -d mongodb redis rabbitmq
    
    # Start backend services with PM2
    pm2 start bin/auth-service --name "sparkles-auth" -- -port 8081
    pm2 start bin/dashboard-service --name "sparkles-dashboard" -- -port 8082
    pm2 start bin/goals-service --name "sparkles-goals" -- -port 8083
    pm2 start bin/vault-service --name "sparkles-vault" -- -port 8084
    
    # Start frontend with PM2
    cd $SPARKLES_WEB_DIR
    pm2 start npm --name "sparkles-web" -- run preview -- --port 5173
    
    echo -e "${GREEN}✓ Sparkles started${NC}"
}

start_orchestai() {
    echo -e "${YELLOW}Starting OrchestAI services...${NC}"
    cd $ORCHESTAI_DIR
    
    # Start databases
    docker compose up -d
    
    # Start backend services (adjust based on your structure)
    if [ -d "bin" ]; then
        for binary in bin/*; do
            binary_name=$(basename $binary)
            pm2 start $binary --name "orchestai-$binary_name"
        done
    fi
    
    # Start frontends
    if [ -d "frontend" ]; then
        cd frontend
        pm2 start npm --name "orchestai-frontend" -- start
        cd ..
    fi
    
    if [ -d "internal-frontend" ]; then
        cd internal-frontend
        pm2 start npm --name "orchestai-internal" -- start
        cd ..
    fi
    
    echo -e "${GREEN}✓ OrchestAI started${NC}"
}

start_docs() {
    echo -e "${YELLOW}Starting docs-portal...${NC}"
    cd $DOCS_DIR
    pm2 start npm --name "docs-portal" -- run start
    echo -e "${GREEN}✓ docs-portal started${NC}"
}

start_all() {
    echo -e "${BLUE}Starting all services...${NC}"
    start_sparkles
    start_orchestai
    start_docs
    pm2 save
    echo -e "${GREEN}✓ All services started${NC}"
}

# ============================
# STOP FUNCTION
# ============================
stop_all() {
    echo -e "${YELLOW}Stopping all services...${NC}"
    pm2 stop all
    pm2 delete all
    
    # Stop databases
    cd $SPARKLES_DIR && docker compose down
    cd $ORCHESTAI_DIR && docker compose down
    
    echo -e "${GREEN}✓ All services stopped${NC}"
}

# ============================
# STATUS FUNCTION
# ============================
show_status() {
    echo -e "${BLUE}=== Service Status ===${NC}"
    pm2 status
    
    echo ""
    echo -e "${BLUE}=== Database Status ===${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo ""
    echo -e "${BLUE}=== System Resources ===${NC}"
    echo "CPU Temperature:"
    sensors | grep 'Core 0' || echo "  N/A"
    echo ""
    echo "Memory Usage:"
    free -h
    echo ""
    echo "Disk Usage:"
    df -h /
}

# ============================
# LOGS FUNCTION
# ============================
show_logs() {
    if [ -z "$1" ]; then
        pm2 logs
    else
        pm2 logs "$1"
    fi
}

# ============================
# UPDATE FUNCTION
# ============================
update_all() {
    echo -e "${BLUE}Updating all projects...${NC}"
    
    # Stop services
    stop_all
    
    # Pull latest code
    echo -e "${YELLOW}Pulling latest code...${NC}"
    
    cd $SPARKLES_DIR && git pull
    cd $SPARKLES_WEB_DIR && git pull
    cd $ORCHESTAI_DIR && git pull
    cd $DOCS_DIR && git pull
    
    # Rebuild
    build_all
    
    # Restart
    start_all
    
    echo -e "${GREEN}✓ Update complete${NC}"
}

# ============================
# MAIN SCRIPT
# ============================

case "$1" in
    setup)
        setup_projects
        ;;
    build)
        build_all
        ;;
    start)
        start_all
        ;;
    start-sparkles)
        start_sparkles
        ;;
    start-orchestai)
        start_orchestai
        ;;
    start-docs)
        start_docs
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 2
        start_all
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    clean)
        stop_all
        echo "Clean complete"
        ;;
    update)
        update_all
        ;;
    *)
        show_help
        ;;
esac
