#!/bin/bash

# Laptop Server Health Monitor
# Monitors: CPU temp, RAM, disk, network, services

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOGFILE="$HOME/server-health.log"
ALERT_LOG="$HOME/server-alerts.log"

# Thresholds
CPU_TEMP_WARN=75
CPU_TEMP_CRIT=85
RAM_WARN=80
RAM_CRIT=90
DISK_WARN=80
DISK_CRIT=90

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOGFILE
}

alert_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1" >> $ALERT_LOG
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1" | wall
}

# ============================
# CPU TEMPERATURE CHECK
# ============================
check_cpu_temp() {
    TEMP=$(sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}' | tr -d '+°C' | cut -d'.' -f1)
    
    if [ -z "$TEMP" ]; then
        TEMP=0
    fi
    
    echo -e "${BLUE}CPU Temperature:${NC} ${TEMP}°C"
    log_msg "CPU Temp: ${TEMP}°C"
    
    if [ "$TEMP" -ge "$CPU_TEMP_CRIT" ]; then
        echo -e "${RED}  ⚠️  CRITICAL: CPU overheating!${NC}"
        alert_msg "CRITICAL: CPU temp ${TEMP}°C (threshold: ${CPU_TEMP_CRIT}°C)"
        return 2
    elif [ "$TEMP" -ge "$CPU_TEMP_WARN" ]; then
        echo -e "${YELLOW}  ⚠️  WARNING: CPU temp high${NC}"
        alert_msg "WARNING: CPU temp ${TEMP}°C (threshold: ${CPU_TEMP_WARN}°C)"
        return 1
    else
        echo -e "${GREEN}  ✓ Normal${NC}"
        return 0
    fi
}

# ============================
# MEMORY CHECK
# ============================
check_memory() {
    MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    MEM_USED=$(free -m | awk 'NR==2{print $3}')
    MEM_PCT=$(awk "BEGIN {printf \"%.0f\", ($MEM_USED/$MEM_TOTAL)*100}")
    
    echo -e "${BLUE}Memory Usage:${NC} ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PCT}%)"
    log_msg "Memory: ${MEM_PCT}% used"
    
    if [ "$MEM_PCT" -ge "$RAM_CRIT" ]; then
        echo -e "${RED}  ⚠️  CRITICAL: Memory exhausted!${NC}"
        alert_msg "CRITICAL: Memory at ${MEM_PCT}% (threshold: ${RAM_CRIT}%)"
        return 2
    elif [ "$MEM_PCT" -ge "$RAM_WARN" ]; then
        echo -e "${YELLOW}  ⚠️  WARNING: Memory high${NC}"
        alert_msg "WARNING: Memory at ${MEM_PCT}% (threshold: ${RAM_WARN}%)"
        return 1
    else
        echo -e "${GREEN}  ✓ Normal${NC}"
        return 0
    fi
}

# ============================
# DISK CHECK
# ============================
check_disk() {
    DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
    DISK_USED=$(df -h / | awk 'NR==2{print $3}')
    DISK_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    
    echo -e "${BLUE}Disk Usage:${NC} ${DISK_USED} / ${DISK_TOTAL} (${DISK_PCT}%)"
    log_msg "Disk: ${DISK_PCT}% used"
    
    if [ "$DISK_PCT" -ge "$DISK_CRIT" ]; then
        echo -e "${RED}  ⚠️  CRITICAL: Disk almost full!${NC}"
        alert_msg "CRITICAL: Disk at ${DISK_PCT}% (threshold: ${DISK_CRIT}%)"
        return 2
    elif [ "$DISK_PCT" -ge "$DISK_WARN" ]; then
        echo -e "${YELLOW}  ⚠️  WARNING: Disk space low${NC}"
        alert_msg "WARNING: Disk at ${DISK_PCT}% (threshold: ${DISK_WARN}%)"
        return 1
    else
        echo -e "${GREEN}  ✓ Normal${NC}"
        return 0
    fi
}

# ============================
# NETWORK CHECK
# ============================
check_network() {
    echo -e "${BLUE}Network Status:${NC}"
    
    # Check WiFi connection
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        echo -e "${GREEN}  ✓ Internet connected${NC}"
        log_msg "Network: OK"
        
        # Check WiFi signal strength
        SIGNAL=$(iwconfig 2>/dev/null | grep -i signal | awk '{print $4}' | tr -d 'level=')
        if [ ! -z "$SIGNAL" ]; then
            echo "  WiFi Signal: $SIGNAL"
            log_msg "WiFi Signal: $SIGNAL"
        fi
        
        return 0
    else
        echo -e "${RED}  ⚠️  CRITICAL: No internet connection!${NC}"
        alert_msg "CRITICAL: Internet connection lost"
        
        # Try to restart NetworkManager
        echo "  Attempting to restart NetworkManager..."
        sudo systemctl restart NetworkManager
        sleep 5
        
        if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
            echo -e "${GREEN}  ✓ Connection restored${NC}"
            log_msg "Network: Restored after restart"
            return 0
        else
            echo -e "${RED}  ✗ Connection still down${NC}"
            return 2
        fi
    fi
}

# ============================
# SERVICE CHECK
# ============================
check_services() {
    echo -e "${BLUE}Service Status:${NC}"
    
    # Check PM2 services
    if command -v pm2 &> /dev/null; then
        STOPPED=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.pm2_env.status != "online") | .name' 2>/dev/null)
        
        if [ -z "$STOPPED" ]; then
            echo -e "${GREEN}  ✓ All PM2 services running${NC}"
            log_msg "Services: All running"
            PM2_STATUS=0
        else
            echo -e "${RED}  ⚠️  WARNING: Some services stopped${NC}"
            echo "  Stopped: $STOPPED"
            alert_msg "WARNING: Services stopped: $STOPPED"
            
            # Auto-restart stopped services
            echo "  Attempting to restart..."
            pm2 restart all
            PM2_STATUS=1
        fi
    else
        echo -e "${YELLOW}  PM2 not found${NC}"
        PM2_STATUS=0
    fi
    
    # Check Docker containers
    DOCKER_DOWN=$(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$DOCKER_DOWN" ]; then
        echo -e "${GREEN}  ✓ All Docker containers running${NC}"
        log_msg "Docker: All running"
        DOCKER_STATUS=0
    else
        echo -e "${YELLOW}  ⚠️  WARNING: Some containers stopped${NC}"
        echo "  Stopped: $DOCKER_DOWN"
        alert_msg "WARNING: Docker containers stopped: $DOCKER_DOWN"
        DOCKER_STATUS=1
    fi
    
    # Check Cloudflare Tunnel
    if systemctl is-active --quiet cloudflared; then
        echo -e "${GREEN}  ✓ Cloudflare Tunnel running${NC}"
        log_msg "Cloudflare: Running"
        CF_STATUS=0
    else
        echo -e "${RED}  ⚠️  CRITICAL: Cloudflare Tunnel down!${NC}"
        alert_msg "CRITICAL: Cloudflare Tunnel is down"
        
        # Try to restart
        echo "  Attempting to restart..."
        sudo systemctl restart cloudflared
        sleep 3
        
        if systemctl is-active --quiet cloudflared; then
            echo -e "${GREEN}  ✓ Tunnel restarted${NC}"
            CF_STATUS=0
        else
            echo -e "${RED}  ✗ Failed to restart tunnel${NC}"
            CF_STATUS=2
        fi
    fi
    
    return $(( PM2_STATUS + DOCKER_STATUS + CF_STATUS ))
}

# ============================
# BATTERY CHECK
# ============================
check_battery() {
    if [ -d /sys/class/power_supply/BAT0 ]; then
        echo -e "${BLUE}Battery Status:${NC}"
        
        BATTERY_CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "N/A")
        BATTERY_STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "N/A")
        
        echo "  Capacity: ${BATTERY_CAPACITY}%"
        echo "  Status: ${BATTERY_STATUS}"
        log_msg "Battery: ${BATTERY_CAPACITY}% - ${BATTERY_STATUS}"
        
        # Check for battery swelling (health check)
        if [ -f /sys/class/power_supply/BAT0/health ]; then
            HEALTH=$(cat /sys/class/power_supply/BAT0/health)
            echo "  Health: ${HEALTH}"
            log_msg "Battery Health: ${HEALTH}"
        fi
        
        # Warn if discharging while server is running
        if [ "$BATTERY_STATUS" == "Discharging" ]; then
            echo -e "${YELLOW}  ⚠️  WARNING: Running on battery power${NC}"
            alert_msg "WARNING: Server running on battery (${BATTERY_CAPACITY}%)"
        fi
    fi
}

# ============================
# UPTIME CHECK
# ============================
check_uptime() {
    echo -e "${BLUE}Uptime:${NC} $(uptime -p)"
    log_msg "Uptime: $(uptime -p)"
}

# ============================
# TOP PROCESSES
# ============================
show_top_processes() {
    echo -e "${BLUE}Top CPU Processes:${NC}"
    ps aux --sort=-%cpu | head -6 | tail -5
    
    echo ""
    echo -e "${BLUE}Top Memory Processes:${NC}"
    ps aux --sort=-%mem | head -6 | tail -5
}

# ============================
# MAIN HEALTH CHECK
# ============================
main() {
    echo "=================================="
    echo "Laptop Server Health Check"
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
    echo "=================================="
    echo ""
    
    ERRORS=0
    
    check_uptime
    echo ""
    
    check_cpu_temp
    ERRORS=$((ERRORS + $?))
    echo ""
    
    check_memory
    ERRORS=$((ERRORS + $?))
    echo ""
    
    check_disk
    ERRORS=$((ERRORS + $?))
    echo ""
    
    check_network
    ERRORS=$((ERRORS + $?))
    echo ""
    
    check_services
    ERRORS=$((ERRORS + $?))
    echo ""
    
    check_battery
    echo ""
    
    show_top_processes
    echo ""
    
    # Summary
    echo "=================================="
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}✓ System Health: GOOD${NC}"
        log_msg "Health Check: PASSED"
    elif [ $ERRORS -le 2 ]; then
        echo -e "${YELLOW}⚠️  System Health: WARNING${NC}"
        log_msg "Health Check: WARNING ($ERRORS issues)"
    else
        echo -e "${RED}⚠️  System Health: CRITICAL${NC}"
        log_msg "Health Check: CRITICAL ($ERRORS issues)"
    fi
    echo "=================================="
    echo ""
    echo "Logs: $LOGFILE"
    echo "Alerts: $ALERT_LOG"
}

# Run main or specific check
case "$1" in
    temp|temperature)
        check_cpu_temp
        ;;
    mem|memory)
        check_memory
        ;;
    disk)
        check_disk
        ;;
    net|network)
        check_network
        ;;
    services)
        check_services
        ;;
    battery)
        check_battery
        ;;
    *)
        main
        ;;
esac
