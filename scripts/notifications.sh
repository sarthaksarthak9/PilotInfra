#!/bin/bash

# Notification System for Laptop Server
# Supports: Email, Telegram, Discord
# Monitors critical events and sends alerts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================
# CONFIGURATION
# ============================

# Load config from file if exists
CONFIG_FILE="$HOME/.server-notifications.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Default config (edit these or create config file)
    ENABLE_EMAIL=false
    EMAIL_TO=""
    EMAIL_FROM=""
    SMTP_SERVER=""
    SMTP_PORT=587
    SMTP_USER=""
    SMTP_PASS=""
    
    ENABLE_TELEGRAM=false
    TELEGRAM_BOT_TOKEN=""
    TELEGRAM_CHAT_ID=""
    
    ENABLE_DISCORD=false
    DISCORD_WEBHOOK=""
fi

# ============================
# SETUP FUNCTION
# ============================
setup_notifications() {
    echo -e "${BLUE}Notification System Setup${NC}"
    echo ""
    
    # Email setup
    read -p "Enable email notifications? (y/n): " SETUP_EMAIL
    if [ "$SETUP_EMAIL" == "y" ]; then
        read -p "Your email address: " EMAIL_TO
        read -p "From email address: " EMAIL_FROM
        read -p "SMTP server (e.g., smtp.gmail.com): " SMTP_SERVER
        read -p "SMTP port (default 587): " SMTP_PORT
        SMTP_PORT=${SMTP_PORT:-587}
        read -p "SMTP username: " SMTP_USER
        read -sp "SMTP password: " SMTP_PASS
        echo ""
        ENABLE_EMAIL=true
    fi
    
    echo ""
    
    # Telegram setup
    read -p "Enable Telegram notifications? (y/n): " SETUP_TELEGRAM
    if [ "$SETUP_TELEGRAM" == "y" ]; then
        echo ""
        echo "To get Telegram Bot Token:"
        echo "  1. Message @BotFather on Telegram"
        echo "  2. Send: /newbot"
        echo "  3. Follow instructions"
        echo ""
        read -p "Telegram Bot Token: " TELEGRAM_BOT_TOKEN
        
        echo ""
        echo "To get Chat ID:"
        echo "  1. Message your bot"
        echo "  2. Visit: https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates"
        echo "  3. Find 'chat':{'id': YOUR_CHAT_ID}"
        echo ""
        read -p "Telegram Chat ID: " TELEGRAM_CHAT_ID
        ENABLE_TELEGRAM=true
    fi
    
    echo ""
    
    # Discord setup
    read -p "Enable Discord notifications? (y/n): " SETUP_DISCORD
    if [ "$SETUP_DISCORD" == "y" ]; then
        echo ""
        echo "To get Discord Webhook:"
        echo "  1. Go to Server Settings → Integrations → Webhooks"
        echo "  2. Create webhook"
        echo "  3. Copy webhook URL"
        echo ""
        read -p "Discord Webhook URL: " DISCORD_WEBHOOK
        ENABLE_DISCORD=true
    fi
    
    # Save config
    cat > "$CONFIG_FILE" << EOF
# Server Notification Configuration
# Generated: $(date)

ENABLE_EMAIL=$ENABLE_EMAIL
EMAIL_TO="$EMAIL_TO"
EMAIL_FROM="$EMAIL_FROM"
SMTP_SERVER="$SMTP_SERVER"
SMTP_PORT=$SMTP_PORT
SMTP_USER="$SMTP_USER"
SMTP_PASS="$SMTP_PASS"

ENABLE_TELEGRAM=$ENABLE_TELEGRAM
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"

ENABLE_DISCORD=$ENABLE_DISCORD
DISCORD_WEBHOOK="$DISCORD_WEBHOOK"
EOF
    
    chmod 600 "$CONFIG_FILE"
    
    echo ""
    echo -e "${GREEN}✓ Configuration saved to: $CONFIG_FILE${NC}"
    echo ""
    
    # Test notifications
    read -p "Send test notification? (y/n): " SEND_TEST
    if [ "$SEND_TEST" == "y" ]; then
        send_notification "info" "Test Notification" "This is a test message from your laptop server!"
    fi
}

# ============================
# SEND EMAIL
# ============================
send_email() {
    SUBJECT="$1"
    MESSAGE="$2"
    
    if [ "$ENABLE_EMAIL" != "true" ]; then
        return 0
    fi
    
    # Using sendemail (install: sudo apt install sendemail)
    if command -v sendemail &> /dev/null; then
        echo "$MESSAGE" | sendemail \
            -f "$EMAIL_FROM" \
            -t "$EMAIL_TO" \
            -u "$SUBJECT" \
            -s "$SMTP_SERVER:$SMTP_PORT" \
            -xu "$SMTP_USER" \
            -xp "$SMTP_PASS" \
            -o tls=yes \
            > /dev/null 2>&1
        return $?
    fi
    
    # Fallback to mail command
    if command -v mail &> /dev/null; then
        echo "$MESSAGE" | mail -s "$SUBJECT" "$EMAIL_TO"
        return $?
    fi
    
    return 1
}

# ============================
# SEND TELEGRAM
# ============================
send_telegram() {
    MESSAGE="$1"
    
    if [ "$ENABLE_TELEGRAM" != "true" ]; then
        return 0
    fi
    
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${MESSAGE}" \
        -d "parse_mode=HTML" \
        > /dev/null 2>&1
    
    return $?
}

# ============================
# SEND DISCORD
# ============================
send_discord() {
    LEVEL="$1"
    TITLE="$2"
    MESSAGE="$3"
    
    if [ "$ENABLE_DISCORD" != "true" ]; then
        return 0
    fi
    
    # Color based on level
    case "$LEVEL" in
        critical) COLOR=15158332 ;; # Red
        warning)  COLOR=16776960 ;; # Yellow
        info)     COLOR=3447003  ;; # Blue
        success)  COLOR=3066993  ;; # Green
        *)        COLOR=8421504  ;; # Gray
    esac
    
    PAYLOAD=$(cat <<EOF
{
  "embeds": [{
    "title": "$TITLE",
    "description": "$MESSAGE",
    "color": $COLOR,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "footer": {
      "text": "Laptop Server Monitor"
    }
  }]
}
EOF
)
    
    curl -s -H "Content-Type: application/json" \
        -X POST \
        -d "$PAYLOAD" \
        "$DISCORD_WEBHOOK" \
        > /dev/null 2>&1
    
    return $?
}

# ============================
# UNIFIED NOTIFICATION
# ============================
send_notification() {
    LEVEL="$1"    # critical, warning, info, success
    TITLE="$2"
    MESSAGE="$3"
    
    # Log locally
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] $TITLE: $MESSAGE" >> "$HOME/notifications.log"
    
    # Emoji for level
    case "$LEVEL" in
        critical) EMOJI="🚨" ;;
        warning)  EMOJI="⚠️" ;;
        info)     EMOJI="ℹ️" ;;
        success)  EMOJI="✅" ;;
        *)        EMOJI="📢" ;;
    esac
    
    # Format message
    FULL_MESSAGE="$EMOJI $TITLE\n\n$MESSAGE\n\nTime: $(date '+%Y-%m-%d %H:%M:%S')\nHost: $(hostname)"
    
    # Send via all enabled channels
    SENT=false
    
    if [ "$ENABLE_EMAIL" == "true" ]; then
        send_email "[$LEVEL] $TITLE" "$FULL_MESSAGE" && SENT=true
    fi
    
    if [ "$ENABLE_TELEGRAM" == "true" ]; then
        send_telegram "$FULL_MESSAGE" && SENT=true
    fi
    
    if [ "$ENABLE_DISCORD" == "true" ]; then
        send_discord "$LEVEL" "$TITLE" "$MESSAGE" && SENT=true
    fi
    
    if [ "$SENT" == "true" ]; then
        echo -e "${GREEN}✓ Notification sent${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ No notification channels configured${NC}"
        return 1
    fi
}

# ============================
# MONITORING FUNCTIONS
# ============================

monitor_health() {
    # Check CPU temp
    TEMP=$(sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}' | tr -d '+°C' | cut -d'.' -f1 || echo "0")
    if [ "$TEMP" -ge 85 ]; then
        send_notification "critical" "CPU Temperature Critical" "CPU is at ${TEMP}°C! Consider shutting down."
    elif [ "$TEMP" -ge 75 ]; then
        send_notification "warning" "CPU Temperature High" "CPU is at ${TEMP}°C. Monitor closely."
    fi
    
    # Check memory
    MEM_PCT=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$MEM_PCT" -ge 90 ]; then
        send_notification "critical" "Memory Critical" "Memory usage at ${MEM_PCT}%"
    fi
    
    # Check disk
    DISK_PCT=$(df / | awk 'NR==2{print $5}' | tr -d '%')
    if [ "$DISK_PCT" -ge 90 ]; then
        send_notification "warning" "Disk Space Low" "Disk usage at ${DISK_PCT}%"
    fi
    
    # Check services
    if command -v pm2 &> /dev/null; then
        STOPPED=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.pm2_env.status != "online") | .name' 2>/dev/null)
        if [ ! -z "$STOPPED" ]; then
            send_notification "warning" "Services Down" "Stopped services: $STOPPED"
        fi
    fi
    
    # Check network
    if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        send_notification "critical" "Network Down" "Internet connection lost!"
    fi
}

# ============================
# SCHEDULED REPORTS
# ============================

daily_report() {
    UPTIME=$(uptime -p)
    TEMP=$(sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}' || echo "N/A")
    MEM=$(free -h | awk 'NR==2{printf "Used: %s / %s", $3, $2}')
    DISK=$(df -h / | awk 'NR==2{printf "Used: %s / %s", $3, $2}')
    
    REPORT="Daily Server Status:\n\n"
    REPORT+="Uptime: $UPTIME\n"
    REPORT+="CPU Temp: $TEMP\n"
    REPORT+="Memory: $MEM\n"
    REPORT+="Disk: $DISK\n"
    
    send_notification "info" "Daily Server Report" "$REPORT"
}

# ============================
# MAIN
# ============================

case "$1" in
    setup)
        setup_notifications
        ;;
    test)
        send_notification "info" "Test Notification" "This is a test from your laptop server!"
        ;;
    critical)
        send_notification "critical" "${2:-Critical Alert}" "${3:-A critical event occurred}"
        ;;
    warning)
        send_notification "warning" "${2:-Warning}" "${3:-A warning event occurred}"
        ;;
    info)
        send_notification "info" "${2:-Information}" "${3:-An informational message}"
        ;;
    success)
        send_notification "success" "${2:-Success}" "${3:-Operation completed successfully}"
        ;;
    monitor)
        monitor_health
        ;;
    daily)
        daily_report
        ;;
    *)
        echo "Notification System"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup    - Configure notification channels"
        echo "  test     - Send test notification"
        echo "  monitor  - Check health and send alerts"
        echo "  daily    - Send daily status report"
        echo ""
        echo "Send custom notifications:"
        echo "  $0 critical 'Title' 'Message'"
        echo "  $0 warning 'Title' 'Message'"
        echo "  $0 info 'Title' 'Message'"
        echo "  $0 success 'Title' 'Message'"
        echo ""
        ;;
esac
