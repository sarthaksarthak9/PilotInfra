# 🚀 Multi-User Containers - Quick Start

Get isolated containers for multiple users in 5 minutes with **password-based SSH**.

---

## ⚡ Setup (Admin - One Time)

```bash
cd ~/devops/scripts

# 1. Initialize container system
sudo ./multi-user-containers.sh init

# 2. Setup password SSH gateway
sudo ./ssh-gateway.sh setup

# Done! System is ready.
```

---

## 👥 Create Users (Admin)

```bash
# Create users (they automatically get SSH access)
sudo ./multi-user-containers.sh create-user john --memory 1g
sudo ./multi-user-containers.sh create-user alice --memory 2g

# Get their passwords
sudo cat /var/lib/user-containers/users/john/password.txt
sudo cat /var/lib/user-containers/users/alice/password.txt
```

**Share username + password with users**

---

## 🔐 User Access

### Connect via SSH

```bash
# From user's terminal (Windows/Mac/Linux)
ssh -p 2222 john@your-server-ip

# Enter password when prompted
```

### Change Password (First Login)

```bash
# Once logged in
passwd

# Enter current password
# Enter new password (twice)
```

**Done!** User now has private container with custom password.

---

## 📊 Admin Commands

```bash
# List all users and passwords
sudo ./ssh-gateway.sh list

# Monitor resources
sudo ./multi-user-containers.sh monitor

# View logs
sudo ./multi-user-containers.sh logs john

# Reset password
sudo ./ssh-gateway.sh reset-password john

# Delete user
sudo ./multi-user-containers.sh delete-user john
```

---

## 💡 What Users Get

- ✅ Isolated container (cannot see other users)
- ✅ SSH access with password (no keys needed!)
- ✅ Can change their own password
- ✅ sudo access (for installing packages)
- ✅ Persistent home directory
- ✅ Resource limits (CPU/RAM/disk)

---

## 🌐 Cloudflare Tunnel (Optional - For WiFi)

If your server is on WiFi with no static IP:

```bash
# 1. Setup Cloudflare Tunnel
sudo ./cloudflare-tunnel-setup.sh

# 2. Configure for SSH (in ~/.cloudflared/config.yml)
#    Add: - hostname: ssh.yourdomain.com
#           service: ssh://localhost:2222

# 3. Restart tunnel
sudo systemctl restart cloudflared

# Now users connect via:
ssh john@ssh.yourdomain.com -o ProxyCommand="cloudflared access ssh --hostname %h"
```

**Benefits:**
- ✅ No port forwarding needed
- ✅ Works from anywhere
- ✅ Free

---

## 📚 Full Documentation

- **Complete Guide**: `docs/MULTI-USER-CONTAINERS.md`
- **Password SSH**: `docs/SSH-PASSWORD-GUIDE.md`
- **Cloudflare Tunnel**: `docs/SSH-CLOUDFLARE-TUNNEL.md`

---

## 🎯 Common Use Cases

### Development Team
```bash
# Create dev environments
sudo ./multi-user-containers.sh create-user dev1 --memory 2g
sudo ./multi-user-containers.sh create-user dev2 --memory 2g

# Share passwords, they can install their own tools
```

### Workshop/Training
```bash
# Create 10 student accounts
for i in {1..10}; do
    sudo ./multi-user-containers.sh create-user student$i --memory 512m
done

# Each student SSH with their password
```

### Demo Accounts
```bash
# Temporary demo access
sudo ./multi-user-containers.sh create-user demo --memory 256m --disk 2g

# Share password with client
# Delete when done: sudo ./multi-user-containers.sh delete-user demo
```

---

## 🚨 Troubleshooting

**Can't connect via SSH?**
```bash
# Check SSH service
sudo systemctl status sshd

# Restart SSH
sudo systemctl restart sshd
```

**User forgot password?**
```bash
# Admin resets
sudo ./ssh-gateway.sh reset-password username
```

**Container not running?**
```bash
# Start it
sudo ./multi-user-containers.sh start username
```

---

**That's it! Simple password-based SSH access with full isolation. 🎉**

No SSH keys to generate or manage!
