# 🚀 DevOps Automation Suite

Complete DevOps toolkit for deploying and managing:
- **Sparkles** (Go microservices + React frontend)
- **OrchestAI** (LLM orchestration platform)
- **docs-portal** (Next.js documentation)

Works on: **Spare Laptop** or **VPS** (Hetzner/Vultr/DigitalOcean)

---

## 📁 Folder Structure

```
devops/
├── scripts/              # Automation scripts
│   ├── laptop-server-setup.sh          # Initial laptop setup
│   ├── cloudflare-tunnel-setup.sh      # Cloudflare Tunnel (no port forwarding!)
│   ├── laptop-deploy.sh                # Deploy all services
│   ├── laptop-health-monitor.sh        # Health checks & alerts
│   ├── auto-backup.sh                  # Automated backups
│   ├── emergency-shutdown.sh           # Auto-shutdown on critical issues
│   ├── notifications.sh                # Email/Telegram/Discord alerts
│   └── migrate-to-vps.sh              # One-click VPS migration
│
├── configs/             # Example configurations
│   ├── Caddyfile.example              # Reverse proxy config
│   ├── cloudflared-config.example.yml # Cloudflare Tunnel config
│   ├── ecosystem.config.example.js    # PM2 process manager
│   └── notifications.example.conf     # Notification settings
│
└── docs/                # Documentation
    └── LAPTOP-SERVER-README.md        # Detailed setup guide
```

---

## ⚡ Quick Start (5 Minutes)

### Option A: Spare Laptop Setup

```bash
cd devops/scripts

# 1. Initial setup (takes ~10 min)
./laptop-server-setup.sh

# Reboot
sudo reboot

# 2. Setup Cloudflare Tunnel (bypasses port forwarding!)
./cloudflare-tunnel-setup.sh

# 3. Clone projects and deploy
./laptop-deploy.sh setup      # Clone repos
./laptop-deploy.sh build      # Build all projects
./laptop-deploy.sh start      # Start services

# 4. Setup notifications (optional but recommended)
./notifications.sh setup

# 5. Setup auto-backup (runs daily at 2 AM)
(crontab -l; echo "0 2 * * * $PWD/auto-backup.sh") | crontab -

# 6. Setup emergency shutdown (checks every 5 min)
(crontab -l; echo "*/5 * * * * $PWD/emergency-shutdown.sh") | crontab -

# 7. Setup health monitoring (checks every 10 min)
(crontab -l; echo "*/10 * * * * $PWD/laptop-health-monitor.sh") | crontab -

# 8. Daily status report at 9 AM
(crontab -l; echo "0 9 * * * $PWD/notifications.sh daily") | crontab -
```

### Option B: VPS Migration (When Ready)

```bash
# Migrate from laptop to VPS
./migrate-to-vps.sh
```

---

## 📊 What Each Script Does

### 1. **laptop-server-setup.sh** (Initial Setup)

Installs everything needed:
- Docker & Docker Compose
- Go 1.23
- Node.js 20 & PM2
- Caddy (reverse proxy)
- Cloudflared (tunnel)
- Power management (no sleep, battery protection)
- WiFi optimization
- Temperature monitoring

**Run once on fresh laptop**

---

### 2. **cloudflare-tunnel-setup.sh** (Tunnel Setup)

Creates secure tunnel:
- No port forwarding needed
- Works with WiFi
- Auto-SSL (HTTPS)
- DDoS protection
- Free subdomain or custom domain
- Installed as systemd service

**Benefits:**
- Bypasses router completely
- No need to configure firewall
- Automatic HTTPS
- Can use free .trycloudflare.com domain

---

### 3. **laptop-deploy.sh** (Deployment)

Unified deployment script for all projects.

**Commands:**
```bash
./laptop-deploy.sh setup       # Clone repos
./laptop-deploy.sh build       # Build all projects
./laptop-deploy.sh start       # Start all services
./laptop-deploy.sh stop        # Stop all services
./laptop-deploy.sh restart     # Restart all services
./laptop-deploy.sh status      # Show service status
./laptop-deploy.sh logs        # Show logs (all services)
./laptop-deploy.sh logs auth   # Show logs (specific service)
./laptop-deploy.sh update      # Pull latest code & restart
```

**What it manages:**
- Sparkles (4 microservices)
- Sparkles-web (frontend)
- OrchestAI (all services)
- docs-portal
- MongoDB, Redis, RabbitMQ (Docker)

---

### 4. **laptop-health-monitor.sh** (Monitoring)

Real-time health checks:

```bash
./laptop-health-monitor.sh           # Full health check
./laptop-health-monitor.sh temp      # CPU temperature only
./laptop-health-monitor.sh memory    # Memory usage only
./laptop-health-monitor.sh services  # Services status only
```

**Monitors:**
- ✅ CPU temperature (warns >75°C, critical >85°C)
- ✅ Memory usage (warns >80%, critical >90%)
- ✅ Disk space (warns >80%, critical >90%)
- ✅ WiFi connectivity (auto-reconnect if down)
- ✅ PM2 services (auto-restart if stopped)
- ✅ Docker containers
- ✅ Cloudflare Tunnel
- ✅ Battery status (warns if unplugged)

**Logs:** `~/server-health.log`, `~/server-alerts.log`

---

### 5. **auto-backup.sh** (Automated Backups)

Complete backup solution:

**Backs up:**
- MongoDB (mongodump)
- Redis (dump.rdb)
- All configs (Cloudflare, PM2, Docker)
- Code with uncommitted changes
- System info (packages, services, network)
- Logs (last 1000 lines)

**Features:**
- Compressed tar.gz
- Retention: 7 days
- Max backups: 10
- Optional remote backup (SCP)

**Backup location:** `~/backups/`

**Schedule daily at 2 AM:**
```bash
(crontab -l; echo "0 2 * * * $PWD/auto-backup.sh") | crontab -
```

**Manual backup:**
```bash
./auto-backup.sh
```

---

### 6. **emergency-shutdown.sh** (Safety)

Auto-shutdown on critical conditions:

**Triggers:**
- CPU > 90°C
- Battery < 10% AND discharging
- Memory > 95%
- Disk > 98%

**Actions:**
1. Gracefully stop PM2 services
2. Save databases (Redis, MongoDB)
3. Shutdown system

**Schedule every 5 minutes:**
```bash
(crontab -l; echo "*/5 * * * * $PWD/emergency-shutdown.sh") | crontab -
```

**Logs:** `~/emergency-shutdown.log`

---

### 7. **notifications.sh** (Alerts)

Multi-channel notification system.

**Supported:**
- ✅ Email (SMTP)
- ✅ Telegram
- ✅ Discord

**Setup:**
```bash
./notifications.sh setup    # Configure channels
./notifications.sh test     # Send test notification
```

**Usage:**
```bash
# Built-in monitoring
./notifications.sh monitor  # Check health & send alerts

# Daily report
./notifications.sh daily    # Send daily status

# Custom notifications
./notifications.sh critical "Server Down" "MongoDB crashed!"
./notifications.sh warning "High CPU" "Temp at 80°C"
./notifications.sh info "Deploy" "New version deployed"
./notifications.sh success "Backup" "Backup completed"
```

**Auto-alerts for:**
- CPU > 85°C (critical)
- CPU > 75°C (warning)
- Memory > 90% (critical)
- Disk > 90% (warning)
- Services down (warning)
- Network down (critical)

**Schedule:**
```bash
# Health monitoring every 10 minutes
(crontab -l; echo "*/10 * * * * $PWD/notifications.sh monitor") | crontab -

# Daily report at 9 AM
(crontab -l; echo "0 9 * * * $PWD/notifications.sh daily") | crontab -
```

**Config:** `~/.server-notifications.conf`

---

### 8. **migrate-to-vps.sh** (VPS Migration)

One-click migration from laptop to VPS.

**What it does:**
1. Creates backup of laptop
2. Installs dependencies on VPS
3. Transfers code & databases
4. Builds projects on VPS
5. Starts services
6. Configures Caddy reverse proxy

**Usage:**
```bash
./migrate-to-vps.sh
```

**Prompts for:**
- VPS IP address
- SSH credentials
- Domain name

**Prerequisites:**
- VPS with Ubuntu 22.04+
- SSH key added to VPS
- Domain pointing to VPS (for SSL)

**Time:** ~30 minutes

---

## 🔧 Configuration Files

### Caddyfile (VPS)

```bash
cp configs/Caddyfile.example /etc/caddy/Caddyfile
# Edit and replace 'yourdomain.com'
sudo systemctl restart caddy
```

### Cloudflare Tunnel

```bash
cp configs/cloudflared-config.example.yml ~/.cloudflared/config.yml
# Edit with your tunnel ID and domains
```

### PM2 Ecosystem

```bash
cp configs/ecosystem.config.example.js ~/ecosystem.config.js
# Edit paths and adjust services
pm2 start ecosystem.config.js
```

### Notifications

```bash
cp configs/notifications.example.conf ~/.server-notifications.conf
# Edit with your credentials
```

---

## 📊 Monitoring Dashboard

View all services:

```bash
# PM2 dashboard
pm2 monit

# Quick status
./laptop-deploy.sh status

# Health check
./laptop-health-monitor.sh

# Logs
./laptop-deploy.sh logs           # All services
./laptop-deploy.sh logs auth      # Specific service
pm2 logs sparkles-auth --lines 50 # PM2 logs
```

---

## 🔒 Security Checklist

- [x] Firewall enabled (ports 22, 80, 443)
- [x] SSH key authentication (disable password auth)
- [x] Auto-security updates
- [x] TLP battery protection (60-80% charge)
- [x] Emergency shutdown (>90°C)
- [x] Monitoring alerts
- [x] Daily backups
- [x] Cloudflare DDoS protection

---

## 🎯 Safety Guidelines for Laptop

### ✅ DO:
- Use cooling pad with fans
- Keep lid open or use external monitor
- Place in ventilated area
- Check temps daily (first week)
- Clean vents monthly
- Monitor battery health
- Use Ethernet cable (if possible)

### ❌ DON'T:
- Block air vents
- Place on bed/couch
- Let CPU exceed 85°C
- Ignore battery swelling
- Run without monitoring
- Unplug power (battery acts as UPS)

---

## 💰 Cost Comparison

### Laptop (24/7 for 1 year)
- Electricity: ~$132/year (~$11/mo)
- Hardware risk: Spare laptop
- **Total: ~$132/year**

### VPS (Hetzner CPX31)
- Monthly: €11.90 (~$13/mo)
- **Total: ~$156/year**

**Recommendation:** Start with laptop for 6-12 months, migrate to VPS when needed.

---

## 🚨 Emergency Procedures

### High CPU Temperature (>85°C)
```bash
# Check what's using CPU
htop

# Stop services temporarily
./laptop-deploy.sh stop

# Clean vents, improve cooling
# Restart when cool
./laptop-deploy.sh start
```

### Services Down
```bash
# Check status
./laptop-deploy.sh status

# Check logs
./laptop-deploy.sh logs

# Restart all
./laptop-deploy.sh restart
```

### WiFi Issues
```bash
# Check connection
ping 8.8.8.8

# Restart NetworkManager
sudo systemctl restart NetworkManager

# View WiFi monitor log
tail -f /var/log/wifi-monitor.log
```

### Out of Memory
```bash
# Find memory hogs
ps aux --sort=-%mem | head -10

# Restart services
./laptop-deploy.sh restart

# Last resort
sudo reboot
```

### Restore from Backup
```bash
cd ~/backups
tar -xzf backup_YYYYMMDD_HHMMSS.tar.gz
cd YYYYMMDD_HHMMSS

# Restore MongoDB
docker exec -i mongodb mongorestore databases/mongodb

# Restore Redis
docker cp databases/redis_dump.rdb redis:/data/dump.rdb
docker restart redis

# Restore configs
cp -r configs/.cloudflared ~/
cp pm2/dump.pm2 ~/.pm2/
pm2 resurrect
```

---

## 📞 Support & Troubleshooting

Check detailed guide:
```bash
cat docs/LAPTOP-SERVER-README.md
```

View logs:
- Health: `~/server-health.log`
- Alerts: `~/server-alerts.log`
- Emergency: `~/emergency-shutdown.log`
- Notifications: `~/notifications.log`
- Backups: `~/backups/backup.log`

---

## 🎉 Quick Commands Reference

```bash
# Deploy
./laptop-deploy.sh start|stop|restart|status|logs|update

# Monitor
./laptop-health-monitor.sh

# Backup
./auto-backup.sh

# Notify
./notifications.sh monitor|daily|test

# Migrate
./migrate-to-vps.sh
```

---

## 📝 Cron Jobs Setup (All in One)

```bash
cd /path/to/devops/scripts

# Add all monitoring jobs
(crontab -l 2>/dev/null; cat << 'EOF'
# Backup daily at 2 AM
0 2 * * * /path/to/devops/scripts/auto-backup.sh

# Emergency shutdown check every 5 minutes
*/5 * * * * /path/to/devops/scripts/emergency-shutdown.sh

# Health monitoring every 10 minutes
*/10 * * * * /path/to/devops/scripts/laptop-health-monitor.sh

# Notification alerts every 10 minutes
*/10 * * * * /path/to/devops/scripts/notifications.sh monitor

# Daily status report at 9 AM
0 9 * * * /path/to/devops/scripts/notifications.sh daily

# WiFi monitor every 2 minutes (already setup by laptop-server-setup.sh)
EOF
) | crontab -

echo "✓ All cron jobs configured"
crontab -l
```

---

**Everything you need to run a production server from your spare laptop! 🚀**

For detailed setup instructions, see: `docs/LAPTOP-SERVER-README.md`
