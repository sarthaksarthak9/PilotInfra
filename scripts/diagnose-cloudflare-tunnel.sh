#!/bin/bash

echo "=== Cloudflare Tunnel Diagnostics ==="
echo ""

echo "1. Check if cloudflared is installed:"
echo "-------------------------------------"
if command -v cloudflared &> /dev/null; then
    echo "✓ cloudflared is installed"
    cloudflared --version
else
    echo "✗ cloudflared NOT installed"
    echo "Install with: wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && sudo dpkg -i cloudflared-linux-amd64.deb"
fi
echo ""

echo "2. Check cloudflared service status:"
echo "-------------------------------------"
sudo systemctl status cloudflared --no-pager -l
echo ""

echo "3. Check if cloudflared is running:"
echo "-----------------------------------"
if pgrep -f cloudflared > /dev/null; then
    echo "✓ cloudflared process is running"
    ps aux | grep cloudflared | grep -v grep
else
    echo "✗ cloudflared is NOT running"
fi
echo ""

echo "4. Check cloudflared configuration:"
echo "-----------------------------------"
if [ -f ~/.cloudflared/config.yml ]; then
    echo "✓ User config exists: ~/.cloudflared/config.yml"
    cat ~/.cloudflared/config.yml
elif [ -f /etc/cloudflared/config.yml ]; then
    echo "✓ System config exists: /etc/cloudflared/config.yml"
    sudo cat /etc/cloudflared/config.yml
else
    echo "✗ No cloudflared config found"
fi
echo ""

echo "5. Check for tunnel credentials:"
echo "--------------------------------"
if [ -f ~/.cloudflared/*.json ]; then
    echo "✓ Tunnel credentials found in ~/.cloudflared/"
    ls -la ~/.cloudflared/*.json
elif [ -f /etc/cloudflared/*.json ]; then
    echo "✓ Tunnel credentials found in /etc/cloudflared/"
    sudo ls -la /etc/cloudflared/*.json
else
    echo "✗ No tunnel credentials found"
fi
echo ""

echo "6. Check recent cloudflared logs:"
echo "---------------------------------"
if sudo journalctl -u cloudflared --no-pager -n 30 2>/dev/null | grep -q .; then
    sudo journalctl -u cloudflared --no-pager -n 30
else
    echo "⚠ No systemd logs found, checking process logs..."
    if pgrep -f cloudflared > /dev/null; then
        sudo journalctl _COMM=cloudflared --no-pager -n 30
    fi
fi
echo ""

echo "7. Test SSH service is listening:"
echo "---------------------------------"
if ss -tlnp 2>/dev/null | grep -q ':2222'; then
    echo "✓ SSH listening on port 2222"
    ss -tlnp 2>/dev/null | grep ':2222'
elif netstat -tlnp 2>/dev/null | grep -q ':2222'; then
    echo "✓ SSH listening on port 2222"
    netstat -tlnp 2>/dev/null | grep ':2222'
else
    echo "✗ SSH NOT listening on port 2222"
fi
echo ""

echo "8. Check Cloudflare Access authentication:"
echo "------------------------------------------"
if [ -f ~/.cloudflared/cert.pem ]; then
    echo "✓ Cloudflare cert exists: ~/.cloudflared/cert.pem"
elif [ -f /etc/cloudflared/cert.pem ]; then
    echo "✓ Cloudflare cert exists: /etc/cloudflared/cert.pem"
else
    echo "✗ No Cloudflare cert found"
    echo "Run: cloudflared tunnel login"
fi
echo ""

echo "=== Quick Fix Commands ==="
echo ""
echo "If tunnel is not running:"
echo "  sudo systemctl start cloudflared"
echo "  sudo systemctl enable cloudflared"
echo ""
echo "If tunnel needs reconfiguration:"
echo "  cloudflared tunnel list"
echo "  sudo systemctl restart cloudflared"
echo ""
echo "View live logs:"
echo "  sudo journalctl -u cloudflared -f"
