#!/bin/bash

echo "=== Adding Audit Logging to Container Gateway ==="
echo ""

# Create log file
LOG_FILE="/var/log/container-access.log"
sudo touch "$LOG_FILE"
sudo chmod 640 "$LOG_FILE"
sudo chown root:adm "$LOG_FILE"
echo "✓ Created log file: $LOG_FILE"
echo ""

# Backup gateway script
sudo cp /home/containers/gateway.sh /home/containers/gateway.sh.backup-$(date +%s)
echo "✓ Backed up gateway script"
echo ""

# Update gateway script with logging
cat << 'EOF' | sudo tee /home/containers/gateway.sh > /dev/null
#!/bin/bash

LOG_FILE="/var/log/container-access.log"

clear
echo "╔══════════════════════════════════════╗"
echo "║   Container Gateway                  ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Available containers:"
echo ""

# Show available containers - skip comment lines
grep -v "^#" /var/lib/user-containers/users.db | while IFS=: read username container hash timestamp resources; do
    [ -n "$username" ] && echo "  • $username"
done

echo ""
read -p "Username: " TARGET_USER
read -s -p "Password: " TARGET_PASS
echo ""

# Log attempt
echo "$(date -Iseconds) ATTEMPT user=$TARGET_USER from=$SSH_CLIENT" | sudo tee -a "$LOG_FILE" > /dev/null

# Check credentials
DB_LINE=$(grep "^${TARGET_USER}:" /var/lib/user-containers/users.db 2>/dev/null)
if [ -z "$DB_LINE" ]; then
    echo "Error: User not found"
    echo "$(date -Iseconds) FAILED user=$TARGET_USER from=$SSH_CLIENT reason=user_not_found" | sudo tee -a "$LOG_FILE" > /dev/null
    sleep 2
    exit 1
fi

STORED_HASH=$(echo "$DB_LINE" | cut -d: -f3)
CONTAINER=$(echo "$DB_LINE" | cut -d: -f2)
INPUT_HASH=$(echo -n "$TARGET_PASS" | sha256sum | awk '{print $1}')

if [ "$INPUT_HASH" != "$STORED_HASH" ]; then
    echo "Error: Invalid password"
    echo "$(date -Iseconds) FAILED user=$TARGET_USER from=$SSH_CLIENT reason=wrong_password" | sudo tee -a "$LOG_FILE" > /dev/null
    sleep 2
    exit 1
fi

# Log successful access
echo "$(date -Iseconds) SUCCESS user=$TARGET_USER container=$CONTAINER from=$SSH_CLIENT" | sudo tee -a "$LOG_FILE" > /dev/null

# Connect to container
echo "Connecting to $CONTAINER..."
exec docker exec -it "$CONTAINER" /bin/bash
EOF

sudo chmod +x /home/containers/gateway.sh
echo "✓ Updated gateway script with logging"
echo ""

# Create logrotate config to prevent log from growing too large
cat << 'EOF' | sudo tee /etc/logrotate.d/container-gateway > /dev/null
/var/log/container-access.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF

echo "✓ Added log rotation config"
echo ""

echo "=== Logging Enabled ==="
echo ""
echo "View logs:"
echo "  sudo tail -f /var/log/container-access.log"
echo ""
echo "Example log entry:"
echo "  2026-03-12T21:00:00+05:30 SUCCESS user=ary container=user-ary-123 from=1.2.3.4 56789 22"
echo ""
echo "Logs will be rotated weekly and kept for 12 weeks."
