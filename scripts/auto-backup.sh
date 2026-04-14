#!/bin/bash

# Automatic Backup Script for Laptop Server
# Backs up: MongoDB, Redis, configs, code, PM2 processes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_ROOT="$HOME/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
RETENTION_DAYS=7  # Keep backups for 7 days
MAX_BACKUPS=10    # Keep max 10 backups

# Projects
PROJECT_ROOT="$HOME/servers"
SPARKLES_DIR="$PROJECT_ROOT/sparkles"
ORCHESTAI_DIR="$PROJECT_ROOT/orchestai"
DOCS_DIR="$PROJECT_ROOT/docs-portal"
SPARKLES_WEB_DIR="$PROJECT_ROOT/sparkles-web"

# Log
LOG_FILE="$BACKUP_ROOT/backup.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Laptop Server Backup${NC}"
echo -e "${BLUE}$(date)${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

log "Backup started"

# Create backup directory
mkdir -p "$BACKUP_DIR"/{databases,configs,code,pm2,system}

# ============================
# 1. BACKUP DATABASES
# ============================
echo -e "${YELLOW}[1/6] Backing up databases...${NC}"

# MongoDB
if docker ps | grep -q mongodb; then
    log "Backing up MongoDB..."
    docker exec mongodb mongodump --out /tmp/mongodb_backup --quiet
    docker cp mongodb:/tmp/mongodb_backup "$BACKUP_DIR/databases/mongodb"
    docker exec mongodb rm -rf /tmp/mongodb_backup
    
    # Get size
    MONGO_SIZE=$(du -sh "$BACKUP_DIR/databases/mongodb" | cut -f1)
    log "MongoDB backup: $MONGO_SIZE"
    echo -e "${GREEN}  ✓ MongoDB: $MONGO_SIZE${NC}"
else
    log "MongoDB not running, skipping"
    echo -e "${YELLOW}  ⚠ MongoDB not running${NC}"
fi

# Redis
if docker ps | grep -q redis; then
    log "Backing up Redis..."
    docker exec redis redis-cli BGSAVE > /dev/null 2>&1
    sleep 2
    docker cp redis:/data/dump.rdb "$BACKUP_DIR/databases/redis_dump.rdb"
    
    REDIS_SIZE=$(du -sh "$BACKUP_DIR/databases/redis_dump.rdb" | cut -f1)
    log "Redis backup: $REDIS_SIZE"
    echo -e "${GREEN}  ✓ Redis: $REDIS_SIZE${NC}"
else
    log "Redis not running, skipping"
    echo -e "${YELLOW}  ⚠ Redis not running${NC}"
fi

# ============================
# 2. BACKUP CONFIGS
# ============================
echo -e "${YELLOW}[2/6] Backing up configurations...${NC}"

# Cloudflare Tunnel
if [ -d "$HOME/.cloudflared" ]; then
    cp -r "$HOME/.cloudflared" "$BACKUP_DIR/configs/"
    log "Cloudflare tunnel config backed up"
    echo -e "${GREEN}  ✓ Cloudflare tunnel${NC}"
fi

# PM2
if command -v pm2 &> /dev/null; then
    pm2 save > /dev/null 2>&1 || true
    if [ -d "$HOME/.pm2" ]; then
        cp "$HOME/.pm2/dump.pm2" "$BACKUP_DIR/pm2/" 2>/dev/null || true
        cp "$HOME/.pm2/ecosystem.config.js" "$BACKUP_DIR/pm2/" 2>/dev/null || true
        log "PM2 config backed up"
        echo -e "${GREEN}  ✓ PM2 processes${NC}"
    fi
fi

# Docker compose files
if [ -d "$SPARKLES_DIR" ]; then
    cp "$SPARKLES_DIR/docker-compose.yml" "$BACKUP_DIR/configs/sparkles-docker-compose.yml" 2>/dev/null || true
    cp "$SPARKLES_DIR/.env" "$BACKUP_DIR/configs/sparkles.env" 2>/dev/null || true
fi

if [ -d "$ORCHESTAI_DIR" ]; then
    cp "$ORCHESTAI_DIR/docker-compose.yml" "$BACKUP_DIR/configs/orchestai-docker-compose.yml" 2>/dev/null || true
    cp "$ORCHESTAI_DIR/.env" "$BACKUP_DIR/configs/orchestai.env" 2>/dev/null || true
fi

log "Configurations backed up"
echo -e "${GREEN}  ✓ All configs saved${NC}"

# ============================
# 3. BACKUP CODE (optional)
# ============================
echo -e "${YELLOW}[3/6] Backing up code...${NC}"

# Only backup if local changes exist
for dir in "$SPARKLES_DIR" "$SPARKLES_WEB_DIR" "$ORCHESTAI_DIR" "$DOCS_DIR"; do
    if [ -d "$dir/.git" ]; then
        cd "$dir"
        DIR_NAME=$(basename "$dir")
        
        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            log "Backing up $DIR_NAME (has local changes)"
            tar -czf "$BACKUP_DIR/code/${DIR_NAME}_uncommitted.tar.gz" \
                --exclude=node_modules \
                --exclude=.git \
                --exclude=dist \
                --exclude=build \
                --exclude=bin \
                . 2>/dev/null
            echo -e "${GREEN}  ✓ $DIR_NAME (local changes)${NC}"
        else
            # Just save the git commit hash
            git rev-parse HEAD > "$BACKUP_DIR/code/${DIR_NAME}_commit.txt" 2>/dev/null
            log "$DIR_NAME at commit: $(cat $BACKUP_DIR/code/${DIR_NAME}_commit.txt)"
            echo -e "${GREEN}  ✓ $DIR_NAME (commit recorded)${NC}"
        fi
    fi
done

# ============================
# 4. BACKUP SYSTEM INFO
# ============================
echo -e "${YELLOW}[4/6] Backing up system info...${NC}"

# Installed packages
dpkg -l > "$BACKUP_DIR/system/packages.txt" 2>/dev/null || true

# Running services
pm2 jlist > "$BACKUP_DIR/system/pm2-services.json" 2>/dev/null || true
docker ps -a > "$BACKUP_DIR/system/docker-containers.txt" 2>/dev/null || true
systemctl list-units --type=service --state=running > "$BACKUP_DIR/system/systemd-services.txt" 2>/dev/null || true

# Network info
ip addr > "$BACKUP_DIR/system/network.txt" 2>/dev/null || true

# Disk usage
df -h > "$BACKUP_DIR/system/disk-usage.txt" 2>/dev/null || true

# Crontabs
crontab -l > "$BACKUP_DIR/system/crontab.txt" 2>/dev/null || true

log "System info backed up"
echo -e "${GREEN}  ✓ System info saved${NC}"

# ============================
# 5. BACKUP LOGS (last 1000 lines)
# ============================
echo -e "${YELLOW}[5/6] Backing up logs...${NC}"

mkdir -p "$BACKUP_DIR/logs"

# PM2 logs
if command -v pm2 &> /dev/null; then
    pm2 logs --nostream --lines 1000 > "$BACKUP_DIR/logs/pm2.log" 2>/dev/null || true
fi

# System logs
journalctl -n 1000 > "$BACKUP_DIR/logs/system.log" 2>/dev/null || true

# Cloudflare tunnel logs
journalctl -u cloudflared -n 500 > "$BACKUP_DIR/logs/cloudflared.log" 2>/dev/null || true

# Health monitor logs
if [ -f "$HOME/server-health.log" ]; then
    tail -n 500 "$HOME/server-health.log" > "$BACKUP_DIR/logs/health.log"
fi

log "Logs backed up"
echo -e "${GREEN}  ✓ Logs saved${NC}"

# ============================
# 6. COMPRESS BACKUP
# ============================
echo -e "${YELLOW}[6/6] Compressing backup...${NC}"

cd "$BACKUP_ROOT"
tar -czf "backup_${TIMESTAMP}.tar.gz" "$TIMESTAMP/" > /dev/null 2>&1

BACKUP_SIZE=$(du -sh "backup_${TIMESTAMP}.tar.gz" | cut -f1)
log "Compressed backup size: $BACKUP_SIZE"
echo -e "${GREEN}  ✓ Compressed: $BACKUP_SIZE${NC}"

# Remove uncompressed directory
rm -rf "$BACKUP_DIR"

# ============================
# 7. CLEANUP OLD BACKUPS
# ============================
echo -e "${YELLOW}Cleaning up old backups...${NC}"

# Remove backups older than RETENTION_DAYS
find "$BACKUP_ROOT" -name "backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

# Keep only MAX_BACKUPS most recent
BACKUP_COUNT=$(ls -1 "$BACKUP_ROOT"/backup_*.tar.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]; then
    REMOVE_COUNT=$((BACKUP_COUNT - MAX_BACKUPS))
    ls -1t "$BACKUP_ROOT"/backup_*.tar.gz | tail -n $REMOVE_COUNT | xargs rm -f
    log "Removed $REMOVE_COUNT old backups"
    echo -e "${GREEN}  ✓ Removed $REMOVE_COUNT old backups${NC}"
fi

REMAINING=$(ls -1 "$BACKUP_ROOT"/backup_*.tar.gz 2>/dev/null | wc -l)
log "Keeping $REMAINING backups"
echo -e "${GREEN}  ✓ Keeping $REMAINING backups${NC}"

# ============================
# SUMMARY
# ============================
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}✓ Backup Complete!${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo "Backup file: backup_${TIMESTAMP}.tar.gz"
echo "Size: $BACKUP_SIZE"
echo "Location: $BACKUP_ROOT"
echo ""
echo "To restore:"
echo "  cd $BACKUP_ROOT"
echo "  tar -xzf backup_${TIMESTAMP}.tar.gz"
echo ""

log "Backup completed successfully: backup_${TIMESTAMP}.tar.gz ($BACKUP_SIZE)"

# Optional: Copy to external location
if [ ! -z "$REMOTE_BACKUP_HOST" ]; then
    echo -e "${YELLOW}Copying to remote backup...${NC}"
    scp "$BACKUP_ROOT/backup_${TIMESTAMP}.tar.gz" "$REMOTE_BACKUP_HOST:/backups/" 2>/dev/null && \
        echo -e "${GREEN}✓ Remote backup complete${NC}" || \
        echo -e "${RED}✗ Remote backup failed${NC}"
fi
