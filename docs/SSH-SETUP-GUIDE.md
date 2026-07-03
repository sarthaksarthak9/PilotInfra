# 🔐 SSH Container Access - Complete Setup Guide

**Working setup based on real deployment with Cloudflare Tunnel**

---

## 🎯 Overview

This guide shows the **exact working setup** for SSH access to Docker containers via Cloudflare Tunnel.

### What Works

```
Mac/Client
    ↓ (SSH with key)
Cloudflare Tunnel
    ↓ (ssh.yourdomain.com)
SSH Server (port 2222)
    ↓ (ForceCommand)
Docker Container
    ✓ User lands inside container
```

---

## 📋 Complete Setup Flow

### 1️⃣ Generate SSH Key (Client Side)

**On user's machine (Mac/Linux/Windows):**

```bash
# Generate ED25519 key (modern, secure)
ssh-keygen -t ed25519 -C "user-access"

# Or RSA key (older but compatible)
ssh-keygen -t rsa -b 4096 -C "user-access"
```

Press Enter for defaults. This creates:
- `~/.ssh/id_ed25519` (private key - keep secret)
- `~/.ssh/id_ed25519.pub` (public key - share this)

**View public key:**
```bash
cat ~/.ssh/id_ed25519.pub
```

Example output:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBDAADJsW/w+kdW/vBw9vdr+vyDiMgpKp0N7LIHkzrgY user@machine
```

Copy this entire line - you'll need it in step 3.

---

### 2️⃣ Setup Server (Admin)

**On your server:**

```bash
cd ~/devops/scripts

# Initialize multi-user system
sudo ./multi-user-containers.sh init

# Setup SSH gateway
sudo ./multi-user-containers.sh setup-ssh

# Create user and container
sudo ./multi-user-containers.sh create-user test --memory 1g
```

**Output will show:**
- Username: `test`
- Initial password: `xxx` (for container use only)
- Container name: `user-test-1234567890`

---

### 3️⃣ Add User's SSH Key (Admin)

**On your server:**

```bash
# Add SSH key for user
sudo ./ssh-gateway.sh add-key test
```

**When prompted, paste the user's public key** (from step 1):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBDAADJsW/w+kdW/vBw9vdr+vyDiMgpKp0N7LIHkzrgY user@machine
```

**What this does:**
1. Creates Linux user `test`
2. Adds user to `docker` group
3. Creates `/home/test/.ssh/` directory
4. Adds public key to `authorized_keys`
5. Configures SSH `ForceCommand` to route to container
6. Restarts SSH service

---

### 4️⃣ Test Connection (User)

**Direct SSH (if server has public IP):**

```bash
ssh -p 2222 test@your-server-ip
```

**Via Cloudflare Tunnel (recommended for laptops on WiFi):**

```bash
ssh test@ssh.yourdomain.com \
  -o ProxyCommand="cloudflared access ssh --hostname %h"
```

**First time:** You'll land directly inside your container!

```
root@user-test-1234567890:/#
```

**Check you're in a container:**
```bash
hostname  # Shows container name
pwd       # Shows /root (or /home/test)
```

---

### 5️⃣ Optional: Simplify Connection (User)

**Create SSH config on user's machine:**

```bash
nano ~/.ssh/config
```

Add:
```
Host mycontainer
    HostName ssh.yourdomain.com
    User test
    ProxyCommand cloudflared access ssh --hostname %h

# Or for direct connection
Host mycontainer-direct
    HostName your-server-ip
    User test
    Port 2222
```

**Now connect with:**
```bash
ssh mycontainer
```

---

## 🔧 How It Works

### SSH Flow

```
1. User runs: ssh test@ssh.yourdomain.com
        ↓
2. Cloudflare Tunnel forwards to server port 2222
        ↓
3. SSH server authenticates with public key
        ↓
4. Match User test found in sshd_config
        ↓
5. ForceCommand executes: docker exec -it user-test-xxx /bin/bash
        ↓
6. User lands inside container (no host access)
```

### Key Configuration Files

**`/etc/ssh/sshd_config`** (added by script):
```
Port 2222
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no

# Container access for test
Match User test
    ForceCommand docker exec -it user-test-1234567890 /bin/bash
    PermitTTY yes
```

**`/home/test/.ssh/authorized_keys`**:
```
ssh-ed25519 AAAAC3Nza... user@machine
```

**User permissions**:
- User `test` is in group `docker`
- Can run `docker exec` command
- Cannot access host system
- Forced into container immediately

---

## 🚀 Multiple Users

**Create multiple isolated environments:**

```bash
# Admin setup
sudo ./multi-user-containers.sh create-user alice --memory 1g
sudo ./multi-user-containers.sh create-user bob --memory 2g

sudo ./ssh-gateway.sh add-key alice
# Paste Alice's public key

sudo ./ssh-gateway.sh add-key bob
# Paste Bob's public key
```

**Each user:**
- ✅ Gets separate container
- ✅ Uses their own SSH key
- ✅ Cannot access other containers
- ✅ Cannot access host system
- ✅ Complete isolation

**Users connect:**
```bash
# Alice
ssh alice@ssh.yourdomain.com -o ProxyCommand="cloudflared access ssh --hostname %h"

# Bob
ssh bob@ssh.yourdomain.com -o ProxyCommand="cloudflared access ssh --hostname %h"
```

---

## 📊 Admin Commands

```bash
# List all SSH users and their status
sudo ./ssh-gateway.sh list

# Test user's SSH configuration
sudo ./ssh-gateway.sh test alice

# View SSH access logs
sudo tail -f /var/lib/user-containers/logs/access.log

# Monitor containers
sudo ./multi-user-containers.sh monitor

# Remove SSH access
sudo ./ssh-gateway.sh remove-key alice

# Delete user completely
sudo ./multi-user-containers.sh delete-user alice
```

---

## 🔒 Security Features

### What's Protected

✅ **Host system isolated** - Users never access host shell  
✅ **SSH key authentication only** - No passwords over network  
✅ **ForceCommand enforcement** - Cannot bypass container  
✅ **User isolation** - Each user in separate container  
✅ **Resource limits** - CPU/RAM/disk quotas per user  
✅ **Audit logging** - All access logged  

### Attack Surface

| What | Protected? | How |
|------|-----------|-----|
| Host access | ✅ Yes | ForceCommand forces container |
| Other containers | ✅ Yes | Docker isolation |
| SSH brute force | ✅ Yes | Key-only auth |
| Container escape | ⚠️ Partial | Standard Docker isolation |
| Resource exhaustion | ✅ Yes | CPU/RAM/disk limits |

---

## 🚨 Troubleshooting

### Connection Refused

```bash
# Check SSH service
sudo systemctl status sshd

# Check port 2222 is listening
sudo netstat -tlnp | grep 2222

# Restart SSH
sudo systemctl restart sshd
```

### Permission Denied (publickey)

```bash
# Check key was added
sudo cat /home/test/.ssh/authorized_keys

# Check permissions
sudo ls -la /home/test/.ssh/
# Should be: drwx------ (700) and -rw------- (600)

# Check user exists
id test
groups test  # Should include: docker
```

### User Not in Docker Group

```bash
# Add to docker group
sudo usermod -aG docker test

# Verify
groups test

# Test docker access
sudo -u test docker ps
```

### Container Not Running

```bash
# Check container status
docker ps -a | grep test

# Start container
sudo ./multi-user-containers.sh start test

# View logs
sudo ./multi-user-containers.sh logs test
```

### ForceCommand Not Working

```bash
# Check sshd_config
sudo grep -A 3 "Match User test" /etc/ssh/sshd_config

# Should show:
# Match User test
#     ForceCommand docker exec -it user-test-xxx /bin/bash
#     PermitTTY yes

# Test SSH config
sudo sshd -t

# Restart SSH
sudo systemctl restart sshd
```

### Cloudflared Not Found (User Side)

```bash
# Install cloudflared on user's machine

# Mac
brew install cloudflare/cloudflare/cloudflared

# Linux
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Windows
# Download from: https://github.com/cloudflare/cloudflared/releases
```

---

## 💡 Best Practices

### For Admins

1. **Use ForceCommand** - Never give direct host access
2. **SSH keys only** - Disable password authentication
3. **Resource limits** - Set CPU/RAM/disk quotas
4. **Regular monitoring** - Check `docker stats` and logs
5. **Backup user data** - Container volumes in `/var/lib/user-containers/`
6. **Rotate SSH keys** - Encourage users to update keys periodically

### For Users

1. **Protect private key** - Never share `~/.ssh/id_ed25519`
2. **Use passphrase** - Encrypt private key with password
3. **Use SSH config** - Simplifies connection
4. **SSH agent** - Use `ssh-add` for convenience
5. **Update keys** - Generate new key if compromised

---

## 🎉 Complete Working Example

```bash
# ===== ADMIN: COMPLETE SETUP =====

cd ~/devops/scripts

# 1. Initialize
sudo ./multi-user-containers.sh init
sudo ./multi-user-containers.sh setup-ssh

# 2. Setup Cloudflare Tunnel (optional)
sudo ./cloudflare-tunnel-setup.sh
# Configure with SSH ingress

# 3. Create user
sudo ./multi-user-containers.sh create-user john --memory 1g

# 4. Get John's public key (he sends it)
# john@machine: ssh-keygen -t ed25519
# john@machine: cat ~/.ssh/id_ed25519.pub

# 5. Add John's SSH key
sudo ./ssh-gateway.sh add-key john
# Paste: ssh-ed25519 AAAA... john@machine

# ===== USER: CONNECT =====

# 6. John installs cloudflared
brew install cloudflare/cloudflare/cloudflared

# 7. John connects
ssh john@ssh.yourdomain.com \
  -o ProxyCommand="cloudflared access ssh --hostname %h"

# ===== RESULT =====
# John is inside his container!
root@user-john-1234567890:/# whoami
root
```

---

**This setup is production-ready and battle-tested! 🚀**
