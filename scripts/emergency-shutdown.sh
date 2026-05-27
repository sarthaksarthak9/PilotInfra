#!/bin/bash

# Emergency Shutdown Script
# Automatically shuts down laptop if:
# - CPU temp > 90°C
# - Battery critically low
# - Memory > 95%
# - Disk > 98%

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG_FILE="$HOME/emergency-shutdown.log"

# Thresholds
CPU_TEMP_EMERGENCY=90
BATTERY_CRITICAL=10
RAM_CRITICAL=95
DISK_CRITICAL=98

log_emergency() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ EMERGENCY: $1" | tee -a "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ EMERGENCY: $1" | wall
}

emergency_shutdown() {
    REASON="$1"
    
    log_emergency "Initiating emergency shutdown: $REASON"
    
    # Try graceful shutdown first
    echo -e "${RED}================================${NC}"
    echo -e "${RED}⚠️  EMERGENCY SHUTDOWN${NC}"
    echo -e "${RED}Reason: $REASON${NC}"
    echo -e "${RED}================================${NC}"
    
    # Stop services gracefully
    echo "Stopping services..."
    pm2 stop all 2>/dev/null || true
    pm2 save 2>/dev/null || true
    
    # Save databases
    echo "Saving databases..."
    docker exec redis redis-cli SAVE 2>/dev/null || true
    docker exec mongodb mongod --shutdown 2>/dev/null || true
    
    # Wait 5 seconds for graceful shutdown
    sleep 5
    
    # Force shutdown
    log_emergency "Shutting down NOW"
    sync
    sudo shutdown -h now
}

# ============================
# CHECK CPU TEMPERATURE
# ============================
check_temperature() {
    TEMP=$(sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}' | tr -d '+°C' | cut -d'.' -f1)
    
    if [ -z "$TEMP" ]; then
        return 0
    fi
    
    if [ "$TEMP" -ge "$CPU_TEMP_EMERGENCY" ]; then
        emergency_shutdown "CPU temperature critical: ${TEMP}°C (threshold: ${CPU_TEMP_EMERGENCY}°C)"
    fi
}

# ============================
# CHECK BATTERY
# ============================
check_battery() {
    if [ -f /sys/class/power_supply/BAT0/capacity ]; then
        CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity)
        STATUS=$(cat /sys/class/power_supply/BAT0/status)
        
        # Only emergency if discharging AND low
        if [ "$STATUS" == "Discharging" ] && [ "$CAPACITY" -le "$BATTERY_CRITICAL" ]; then
            emergency_shutdown "Battery critically low: ${CAPACITY}% and discharging"
        fi
    fi
}

# ============================
# CHECK MEMORY
# ============================
check_memory() {
    MEM_PCT=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$MEM_PCT" -ge "$RAM_CRITICAL" ]; then
        emergency_shutdown "Memory exhausted: ${MEM_PCT}% (threshold: ${RAM_CRITICAL}%)"
    fi
}

# ============================
# CHECK DISK
# ============================
check_disk() {
    DISK_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    
    if [ "$DISK_PCT" -ge "$DISK_CRITICAL" ]; then
        emergency_shutdown "Disk full: ${DISK_PCT}% (threshold: ${DISK_CRITICAL}%)"
    fi
}

# ============================
# MAIN CHECK
# ============================

# Check if we're already shutting down
if [ -f /tmp/emergency-shutdown.lock ]; then
    exit 0
fi

# Create lock file
touch /tmp/emergency-shutdown.lock

# Run checks
check_temperature
check_battery
check_memory
check_disk

# Remove lock file
rm -f /tmp/emergency-shutdown.lock

# If we got here, everything is OK
exit 0
