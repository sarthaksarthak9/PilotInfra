# 🔐 SSH Container Access Guide

Simple SSH-based access to isolated Docker containers.

---

## 📋 Overview

Users access their containers via SSH from any terminal:
- ✅ Standard SSH (port 2222)
- ✅ Password authentication
- ✅ Users can change their own passwords
- ✅ Automatic container routing
- ✅ Complete isolation between users

---

## 🚀 Quick Setup (Admin)

### 1. Initialize System

```bash
cd ~/devops/scripts

# Setup container system
sudo ./multi-user-containers.sh init

# Setup SSH gateway
sudo ./multi-user-containers.sh setup-ssh
```

### 2. Create Users

```bash
# Create user with default resources
sudo ./multi-user-containers.sh create-user john

# Create user with custom resources
sudo ./multi-user-containers.sh create-user alice --memory 1g --cpu 2.0
```

**Output:**
```
✓ User created successfully

─────────────────────────────────
Username: john
Password: hG8kL3mP9nQ2s
Container: user-john-1234567890

User can connect via SSH:
  ssh -p 2222 john@192.168.1.100

Change password: Run 'passwd' inside container
─────────────────────────────────
```

### 3. Share Credentials with User

Send the user:
- Username
- Initial password
- SSH command: `ssh -p 2222 username@your-server-ip`

---

## 👤 User Access

### First Login

```bash
# Connect from your terminal
ssh -p 2222 john@server-ip

# Enter initial password when prompted
```

### Change Password (Immediately)

```bash
# Once logged in, change password:
passwd

# Enter current password
# Enter new password
# Confirm new password
```

**That's it!** Password is now changed for SSH and container access.

---

## 🔧 User Commands

### Basic Container Usage

```bash
# SSH into your container
ssh -p 2222 john@server-ip

# Run single command
ssh -p 2222 john@server-ip 'ls -la'

# Copy files TO container
scp -P 2222 file.txt john@server-ip:~/

# Copy files FROM container
scp -P 2222 john@server-ip:~/file.txt ./

# Use SSH key (optional, more secure)
ssh-copy-id -p 2222 john@server-ip
ssh -p 2222 john@server-ip  # No password needed
```

### Inside Container

```bash
# Check your resources
htop
df -h
free -h

# Install software (if sudo enabled)
sudo apt update
sudo apt install -y python3 nodejs

# Your files persist at
cd ~
ls -la
```

---

## 🛠️ Admin Operations

### List All Users

```bash
sudo ./multi-user-containers.sh list-users
```

### Monitor Containers

```bash
# View all container stats
sudo ./multi-user-containers.sh monitor

# View specific user stats
sudo ./multi-user-containers.sh stats john

# View container logs
sudo ./multi-user-containers.sh logs john
```

### User Management

```bash
# Reset user password (admin only)
sudo ./multi-user-containers.sh reset-password john

# Delete user
sudo ./multi-user-containers.sh delete-user john

# Restart container
sudo ./multi-user-containers.sh restart john

# Direct shell access (bypass SSH)
sudo ./multi-user-containers.sh shell john
```

---

## 🎯 Common Workflows

### Workflow 1: Development Environment

```bash
# Admin: Create developer account
sudo ./multi-user-containers.sh create-user dev1 --memory 2g --cpu 2.0 --image ubuntu:22.04

# User: Connect and setup environment
ssh -p 2222 dev1@server-ip
passwd  # Change password first

# Install development tools
sudo apt update
sudo apt install -y git curl build-essential python3 nodejs npm

# Clone and work on code
git clone https://github.com/your/repo
cd repo
npm install
npm run dev
```

---

### Workflow 2: Training/Workshop

```bash
# Admin: Create 10 student accounts
for i in {1..10}; do
    sudo ./multi-user-containers.sh create-user student$i --memory 512m --cpu 0.5
done

# Distribute credentials
# Each student gets: username (student1-10) and initial password

# Students connect
ssh -p 2222 student1@workshop-server-ip
passwd  # Change password

# Work on assignments
cd ~/workshop
python3 assignment.py
```

---

### Workflow 3: Demo Accounts

```bash
# Admin: Create demo account
sudo ./multi-user-containers.sh create-user demo --memory 256m --disk 2G

# Pre-configure demo environment
sudo ./multi-user-containers.sh shell demo
# Install demo software
apt update && apt install -y nginx
systemctl start nginx
exit

# Share demo credentials with clients
# They can explore without affecting production
```

---

## 🔒 Security Features

### User Isolation

- ✅ Each user has separate container
- ✅ Cannot see other users' processes
- ✅ Cannot access other users' files
- ✅ Resource limits prevent abuse
- ✅ Network isolation

### Password Security

- ✅ Users can change their own passwords
- ✅ Passwords encrypted in transit (SSH)
- ✅ No admin access to user passwords after change
- ✅ Admin can reset passwords if needed

### Access Logging

All access is logged:
```bash
# View access logs
sudo tail -f /var/lib/user-containers/logs/access.log

# View SSH logs
sudo tail -f /var/log/auth.log
```

---

## 🚨 Troubleshooting

### User Can't Connect

```bash
# Check if container is running
sudo docker ps | grep username

# Start container if stopped
sudo ./multi-user-containers.sh start username

# Check SSH service
sudo systemctl status sshd

# Check port 2222 is open
sudo netstat -tlnp | grep 2222
```

### User Forgot Password

```bash
# Admin resets password
sudo ./multi-user-containers.sh reset-password username

# New password will be displayed
# Share new password with user
```

### SSH Connection Refused

```bash
# Check SSH is running on port 2222
sudo netstat -tlnp | grep 2222

# Check firewall
sudo ufw allow 2222/tcp

# Check SSH config
sudo grep "Port 2222" /etc/ssh/sshd_config

# Restart SSH
sudo systemctl restart sshd
```

### Container Won't Start

```bash
# Check Docker
sudo systemctl status docker

# Check container logs
sudo docker logs user-username-12345

# Restart container
sudo ./multi-user-containers.sh restart username
```

---

## 💡 Best Practices

1. **Change Passwords Immediately**
   - All users should change initial password on first login

2. **Use SSH Keys (Optional but Recommended)**
   ```bash
   # Generate SSH key (user's machine)
   ssh-keygen -t ed25519
   
   # Copy to server
   ssh-copy-id -p 2222 username@server-ip
   ```

3. **Regular Backups**
   ```bash
   # Backup all user data
   sudo tar -czf users-backup.tar.gz /var/lib/user-containers/
   ```

4. **Monitor Resources**
   ```bash
   # Check resource usage regularly
   sudo ./multi-user-containers.sh monitor
   ```

5. **Clean Up Inactive Users**
   ```bash
   # Remove old accounts
   sudo ./multi-user-containers.sh delete-user old-user
   ```

---

## 📊 Resource Planning

### Single Server Capacity

Typical server can handle:
- **8GB RAM** → 10-12 users (512MB each)
- **16GB RAM** → 25-30 users (512MB each)
- **32GB RAM** → 60-70 users (512MB each)

### Recommended Allocations

| Use Case | CPU | Memory | Disk |
|----------|-----|--------|------|
| Basic shell | 0.5 | 256MB | 2GB |
| Development | 1.0-2.0 | 1-2GB | 10GB |
| Testing | 1.0 | 512MB | 5GB |
| Demo | 0.5 | 256MB | 2GB |

---

## 🎉 Complete Example

```bash
# === ADMIN SETUP ===

# 1. Initialize system
sudo ./multi-user-containers.sh init
sudo ./multi-user-containers.sh setup-ssh

# 2. Create users
sudo ./multi-user-containers.sh create-user john --memory 1g
sudo ./multi-user-containers.sh create-user alice --memory 1g

# 3. Monitor
sudo ./multi-user-containers.sh monitor

# === USER ACCESS ===

# 4. Users connect
ssh -p 2222 john@server-ip

# 5. Change password
passwd

# 6. Start working
git clone https://github.com/project/repo
cd repo
npm install
npm run dev

# === CLEANUP ===

# 7. Remove users when done
sudo ./multi-user-containers.sh delete-user john
sudo ./multi-user-containers.sh delete-user alice
```

---

## 📚 Related Commands

```bash
# System management
sudo ./multi-user-containers.sh init          # Initialize
sudo ./multi-user-containers.sh setup-ssh     # Setup SSH gateway
sudo ./multi-user-containers.sh list-users    # List all users
sudo ./multi-user-containers.sh monitor       # Monitor all

# User management
sudo ./multi-user-containers.sh create-user <name>    # Create
sudo ./multi-user-containers.sh delete-user <name>    # Delete
sudo ./multi-user-containers.sh reset-password <name> # Reset password

# Container operations
sudo ./multi-user-containers.sh start <name>   # Start
sudo ./multi-user-containers.sh stop <name>    # Stop
sudo ./multi-user-containers.sh restart <name> # Restart
sudo ./multi-user-containers.sh shell <name>   # Shell access
sudo ./multi-user-containers.sh logs <name>    # View logs
sudo ./multi-user-containers.sh stats <name>   # Resource usage
```

---

**Ready to deploy! 🚀**

Users get simple SSH access, can change their own passwords, and work in complete isolation.
