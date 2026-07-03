#!/bin/bash

echo "=== Setting Up Fail2ban for SSH Protection ==="
echo ""

# Check if fail2ban is installed
if ! command -v fail2ban-client &>/dev/null; then
    echo "Installing fail2ban..."
    sudo apt-get update -qq
    sudo apt-get install -y fail2ban
    echo "✓ Installed fail2ban"
else
    echo "✓ fail2ban already installed"
fi
echo ""

# Create custom jail for SSH
cat << 'EOF' | sudo tee /etc/fail2ban/jail.local > /dev/null
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = 2222
logpath = %(sshd_log)s
maxretry = 5
bantime = 1h
EOF

echo "✓ Created fail2ban configuration"
echo ""

echo "Configuration:"
echo "  • Max retries: 5 failed attempts"
echo "  • Time window: 10 minutes"
echo "  • Ban time: 1 hour"
echo "  • Monitored port: 2222"
echo ""

# Enable and restart fail2ban
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
echo "✓ Started fail2ban service"
echo ""

# Wait for service to start
sleep 2

# Check status
echo "Fail2ban status:"
sudo fail2ban-client status sshd
echo ""

echo "=== Fail2ban Configured ==="
echo ""
echo "Monitor with:"
echo "  sudo fail2ban-client status sshd"
echo "  sudo tail -f /var/log/fail2ban.log"
echo ""
echo "Unban an IP:"
echo "  sudo fail2ban-client set sshd unbanip IP_ADDRESS"
echo ""
echo "⚠️  Make sure you have Cloudflare IPs whitelisted if needed!"
