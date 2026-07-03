# 🚀 Laptop Server Setup Guide

Complete guide to turn your spare laptop into a production server for:
- **Sparkles** (Backend + Web)
- **OrchestAI** 
- **docs-portal**

---

## 📋 Prerequisites

- Spare laptop with Ubuntu 22.04+ (or compatible Linux)
- i7 12th gen, 16GB RAM, 120GB storage ✅
- WiFi connection
- Cloudflare account (free)

---

## ⚡ Quick Start (5 Minutes)

### Step 1: Initial Setup

```bash
# Download setup script
cd ~/Documents
chmod +x laptop-server-setup.sh

# Run installation (takes ~10 minutes)
./laptop-server-setup.sh

# Reboot
sudo reboot
```

### Step 2: Clone Your Projects

```bash
# Run deployment script setup
chmod +x laptop-deploy.sh
./laptop-deploy.sh setup

# When prompted, enter your GitHub URLs:
# - https://github.com/AryanAg08/Sparkles
# - https://github.com/AryanAg08/Sparkles-web
# - https://github.com/AryanAg08/orchestai
# - https://github.com/AryanAg08/docs-portal
```

### Step 3: Setup Cloudflare Tunnel (Bypass Port Forwarding!)

```bash
chmod +x cloudflare-tunnel-setup.sh
./cloudflare-tunnel-setup.sh

# Follow the prompts:
# 1. Login to Cloudflare (browser window opens)
# 2. Choose tunnel name (e.g., "laptop-server")
# 3. Enter your domain or use free subdomain
# 4. Script auto-configures everything
```

### Step 4: Build & Deploy

```bash
# Build all projects
./laptop-deploy.sh build

# Start all services
./laptop-deploy.sh start

# Check status
./laptop-deploy.sh status
```

### Step 5: Access Your Apps

If using custom domain:
- Sparkles API: `https://api.yourdomain.com`
- Sparkles Web: `https://app.yourdomain.com`
- docs-portal: `https://docs.yourdomain.com`
- OrchestAI: `https://orchestai.yourdomain.com`

If using free Cloudflare domain:
```bash
# Get your free URL
sudo journalctl -u cloudflared -n 50 | grep trycloudflare.com
```

---

## 🔧 Configuration

### WiFi Optimization (Important!)

The setup script already configured:
- Disabled WiFi power saving
- Auto-restart on connection loss
- Monitoring every 2 minutes

**Manual check:**
```bash
# Test WiFi stability
ping -c 100 8.8.8.8

# View WiFi monitor log
tail -f /var/log/wifi-monitor.log
```

### Battery Protection (Critical!)

Setup script configured TLP to:
- Charge only to 80% (prevents battery degradation)
- Start charging at 60%
- Performance mode when plugged in

**Check battery status:**
```bash
sudo tlp-stat -b
```

### Temperature Monitoring

The laptop will auto-monitor CPU temps:

```bash
# Real-time temperature
watch -n 2 sensors

# View monitor log
tail -f ~/server-monitor.log

# Manual health check
chmod +x laptop-health-monitor.sh
./laptop-health-monitor.sh
```

---

## 📊 Monitoring & Maintenance

### Daily Commands

```bash
# Check everything
./laptop-health-monitor.sh

# View service status
./laptop-deploy.sh status

# View logs
./laptop-deploy.sh logs

# View specific service log
./laptop-deploy.sh logs sparkles-auth
```

### Weekly Maintenance

```bash
# Update all projects
./laptop-deploy.sh update

# Clean Docker
docker system prune -af

# Check disk space
df -h

# View system logs
sudo journalctl -p err -n 50
```

### Monthly Checks

- Clean laptop vents (dust)
- Check battery health: `sudo tlp-stat -b`
- Review alert logs: `cat ~/server-alerts.log`
- Update system: `sudo apt update && sudo apt upgrade`

---

## 🛠️ Troubleshooting

### Services Not Starting

```bash
# Check PM2 errors
pm2 logs --err

# Restart specific service
pm2 restart sparkles-auth

# Restart all
./laptop-deploy.sh restart
```

### High CPU Temperature (>80°C)

```bash
# Check what's using CPU
htop

# Check temps
sensors

# Solutions:
# 1. Clean laptop vents
# 2. Use cooling pad
# 3. Reduce service load
# 4. Check room temperature
```

### WiFi Disconnects

```bash
# Check WiFi log
tail -f /var/log/wifi-monitor.log

# Manual restart
sudo systemctl restart NetworkManager

# Permanent fix: Use Ethernet cable
```

### Cloudflare Tunnel Down

```bash
# Check status
sudo systemctl status cloudflared

# View logs
sudo journalctl -u cloudflared -f

# Restart
sudo systemctl restart cloudflared
```

### Out of Memory

```bash
# Check memory usage
free -h

# Find memory hogs
ps aux --sort=-%mem | head -10

# Restart heavy services
pm2 restart all

# Last resort: reboot
sudo reboot
```

### Disk Full

```bash
# Find large files
sudo du -h --max-depth=1 / | sort -hr | head -20

# Clean Docker
docker system prune -af

# Clean logs
sudo journalctl --vacuum-time=7d

# Clean PM2 logs
pm2 flush
```

---

## 📱 Remote Access

### SSH Access

```bash
# From another computer
ssh username@laptop-ip

# Or via Cloudflare Tunnel
cloudflared access ssh --hostname ssh.yourdomain.com
```

### Mobile Monitoring

Install Termux on Android:
```bash
# In Termux
pkg install openssh
ssh username@laptop-ip

# Run health check
./laptop-health-monitor.sh
```

---

## 🔒 Security

### Firewall (Already Configured)

```bash
# Check firewall status
sudo ufw status

# View rules
sudo ufw status numbered
```

### SSH Security

```bash
# Change SSH port (optional)
sudo nano /etc/ssh/sshd_config
# Change: Port 22 → Port 2222

# Disable password auth (use SSH keys)
# Add to /etc/ssh/sshd_config:
PasswordAuthentication no
PubkeyAuthentication yes

# Restart SSH
sudo systemctl restart sshd
```

### Automatic Security Updates

```bash
# Enable unattended upgrades
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

---

## 💰 Cost Analysis

### Monthly Costs

| Item | Cost |
|------|------|
| Electricity (100W × 24h) | ~$11/mo |
| Internet (already have) | $0 |
| Cloudflare (free tier) | $0 |
| **Total** | **~$11/mo** |

**vs. Hetzner VPS:** €11.90/mo (~$13/mo) but no hardware risk

---

## 📈 Performance Expectations

Your laptop specs vs. VPS:

| Resource | Your Laptop | Hetzner CPX31 | Winner |
|----------|-------------|---------------|--------|
| CPU | i7 12th gen (12-16 threads) | 4 vCPU AMD EPYC | **Laptop** 🏆 |
| RAM | 16GB | 8GB | **Laptop** 🏆 |
| Storage | 120GB NVMe | 160GB SSD | VPS |
| Network | WiFi (~100Mbps) | 20 Gbit | VPS |
| Uptime | Depends on power/WiFi | 99.9% | VPS |

**Your laptop is MORE powerful than $13/mo VPS!**

---

## 🎯 When to Migrate to VPS

Consider moving to VPS when:

- [ ] You have 100+ active users
- [ ] WiFi becomes unreliable
- [ ] Laptop temperature stays >75°C
- [ ] You need 99.9% uptime SLA
- [ ] You want to use laptop for something else
- [ ] Internet bandwidth is saturated

---

## 🚨 Emergency Contacts

### Critical Issues

If something breaks:

1. **Check health:** `./laptop-health-monitor.sh`
2. **Check logs:** `./laptop-deploy.sh logs`
3. **Restart services:** `./laptop-deploy.sh restart`
4. **Restart laptop:** `sudo reboot`

### Backup Strategy

```bash
# Create backup script
cat > ~/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="$HOME/backups/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup databases
docker exec mongodb mongodump --out $BACKUP_DIR/mongodb
docker exec redis redis-cli SAVE
cp /var/lib/docker/volumes/redis/_data/dump.rdb $BACKUP_DIR/

# Backup configs
cp -r ~/.cloudflared $BACKUP_DIR/
cp ~/.pm2/ecosystem.config.js $BACKUP_DIR/ 2>/dev/null || true

echo "Backup complete: $BACKUP_DIR"
EOF

chmod +x ~/backup.sh

# Run daily at 2 AM
(crontab -l; echo "0 2 * * * $HOME/backup.sh") | crontab -
```

---

## ✅ Final Checklist

Before going live:

- [ ] All scripts executable (`chmod +x *.sh`)
- [ ] All services running (`./laptop-deploy.sh status`)
- [ ] Cloudflare tunnel active (`sudo systemctl status cloudflared`)
- [ ] Health monitor running (`./laptop-health-monitor.sh`)
- [ ] WiFi stable (ping test passed)
- [ ] Battery protection enabled (TLP configured)
- [ ] Cooling pad placed
- [ ] Laptop in ventilated area
- [ ] Backups scheduled
- [ ] Monitoring logs clean

---

## 📚 Additional Resources

- Cloudflare Tunnel Docs: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- PM2 Docs: https://pm2.keymetrics.io/
- TLP Battery Management: https://linrunner.de/tlp/
- Docker Optimization: https://docs.docker.com/config/containers/resource_constraints/

---

## 🎉 Success!

Your spare laptop is now a production server! 

**Daily routine:**
1. Morning: `./laptop-health-monitor.sh`
2. Check alerts: `cat ~/server-alerts.log`
3. Spot-check temps: `sensors`

**That's it!** The scripts handle the rest automatically.

---

## 💬 Need Help?

Scripts created:
- `laptop-server-setup.sh` - Initial system setup
- `cloudflare-tunnel-setup.sh` - Tunnel configuration
- `laptop-deploy.sh` - Deploy/manage all services
- `laptop-health-monitor.sh` - System health checks

All scripts include error handling and auto-recovery.

**Happy hosting!** 🚀
