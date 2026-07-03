# 🐳 Multi-User Docker Container System

Complete isolated container environment for multiple users with access control.

---

## 📋 Overview

This system allows you to:
- ✅ Create isolated Docker containers for each user
- ✅ Resource limits per user (CPU, RAM, disk)
- ✅ User-level authentication (password protected)
- ✅ SSH access to containers
- ✅ Web browser terminal access
- ✅ Complete isolation between users
- ✅ Easy management (create, delete, monitor)

**Perfect for:**
- Development environments
- Demo/testing accounts
- Training/workshops
- Multi-tenant applications
- Isolated workspaces

---

## 🚀 Quick Start (10 Minutes)

### Step 1: Install System

```bash
cd ~/devops/scripts

# Initialize multi-user system
sudo ./multi-user-containers.sh init
```

### Step 2: Create First User

```bash
# Create user with default resources (1 CPU, 512MB RAM, 5GB disk)
sudo ./multi-user-containers.sh create-user john

# Or with custom resources
sudo ./multi-user-containers.sh create-user alice \
    --cpu 2.0 \
    --memory 1g \
    --disk 10g \
    --image ubuntu:22.04
```

**Output:**
```
─────────────────────────────────
Username: john
Password: hG8kL3mP9nQ2s
Container: user-john-1234567890

Access commands:
  Shell:  ./multi-user-containers.sh shell john
  Exec:   ./multi-user-containers.sh exec john 'command'
  Logs:   ./multi-user-containers.sh logs john
─────────────────────────────────
```

### Step 3: Access Container

```bash
# Open interactive shell
sudo ./multi-user-containers.sh shell john

# Execute command
sudo ./multi-user-containers.sh exec john 'sudo apt update && sudo apt install -y python3'
```

### Step 4: Setup Simple Container Gateway

**SIMPLE PASSWORD-BASED GATEWAY**

The system uses a single `containers` gateway user that everyone connects through:

```bash
# 1. Setup the gateway system
cd ~/Desktop/linux-server-setup/scripts
sudo ./simple-gateway-setup.sh

# This creates:
# - A 'containers' gateway user (password: gateway123)
# - Interactive menu to select which container
# - Your system user (aryan) still works normally

# 2. Create container users
sudo ./ssh-gateway.sh create ary MyPassword123
sudo ./ssh-gateway.sh create john AnotherPass456

# 3. Connect from anywhere
ssh containers@ssh.aryangoyal.space
# Password: gateway123 (gateway password)
# Username: ary (container user)
# Password: MyPassword123 (container password)
# → You're now in ary's container!

# 4. System admin access still works normally
ssh aryan@ssh.aryangoyal.space
# → Regular system access
```

**HOW IT WORKS:**
- Everyone connects as `containers` user
- Gateway script asks which container you want
- Checks your container password from `/var/lib/user-containers/users.db`
- Connects you to your isolated Docker container
- System users (like `aryan`) bypass the gateway completely
- Passwords are stored as SHA256 hashes
- SSH automatically routes users to their Docker containers
- No system users are created (no login screen pollution)
- Users can change passwords inside their containers with `passwd`

**PASSWORD MANAGEMENT:**

```bash
# View all users
sudo cat /var/lib/user-containers/users.db
# Format: username:container_name:password_hash:timestamp:resources

# Reset a user's password
sudo ./ssh-gateway.sh reset-password john
# New password will be displayed

# Test if password is correct (manual check)
USERNAME="john"
PASSWORD="NewPassword123"
STORED_HASH=$(sudo grep "^$USERNAME:" /var/lib/user-containers/users.db | cut -d: -f3)
TEST_HASH=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')
[ "$TEST_HASH" = "$STORED_HASH" ] && echo "✓ Password matches" || echo "✗ Wrong password"

# Check authentication logs if login fails
sudo tail -50 /var/log/auth.log | grep -i sshd
sudo tail -50 /var/log/container-access.log
```

---

## 🔒 Security Improvements

**Current Status**: Basic security (good for development/learning)

To enhance security for production use:

```bash
cd ~/Desktop/linux-server-setup/security

# 1. Change gateway password (REQUIRED for production)
sudo passwd containers

# 2. Add audit logging (Recommended)
sudo bash add-logging.sh

# 3. Enable SSH keys instead of passwords (Highly Recommended)
bash enable-ssh-keys.sh

# 4. Upgrade to bcrypt password hashing (Recommended)
sudo bash improve-password-hashing.sh

# 5. Add fail2ban rate limiting (Optional)
sudo bash setup-fail2ban.sh
```

See `security/README.md` for detailed security documentation.

---

### Step 5: Setup Web Terminal (Optional)

```bash
# Setup web-based terminal
sudo ./web-terminal-gateway.sh setup

# Start the service
sudo ./web-terminal-gateway.sh start

# Access at: http://your-server-ip:7681
```

---

## 📚 Complete Command Reference

### System Setup

```bash
# Initialize multi-user system
sudo ./multi-user-containers.sh init

# Setup SSH gateway with password auth
sudo ./ssh-gateway.sh setup

# Setup Cloudflare Tunnel (optional, for WiFi/no static IP)
sudo ./cloudflare-tunnel-setup.sh
```

### User Management

```bash
# Create user
sudo ./multi-user-containers.sh create-user <username> [options]

Options:
  --image <image>    Docker image (default: ubuntu:22.04)
  --cpu <limit>      CPU cores (default: 1.0)
  --memory <limit>   RAM limit (default: 512m)
  --disk <limit>     Disk limit (default: 5G)

Examples:
  sudo ./multi-user-containers.sh create-user bob
  sudo ./multi-user-containers.sh create-user alice --memory 2g --cpu 2.0
  sudo ./multi-user-containers.sh create-user dev --image python:3.11

# Delete user
sudo ./multi-user-containers.sh delete-user <username>

# List all users
sudo ./multi-user-containers.sh list-users

# Get user's password
sudo cat /var/lib/user-containers/users/<username>/password.txt

# Reset user password
sudo ./ssh-gateway.sh reset-password <username>
```

### Container Operations

```bash
# Start container
sudo ./multi-user-containers.sh start <username>

# Stop container
sudo ./multi-user-containers.sh stop <username>

# Restart container
sudo ./multi-user-containers.sh restart <username>

# Open shell (admin access)
sudo ./multi-user-containers.sh shell <username>

# View logs
sudo ./multi-user-containers.sh logs <username> [lines]

Examples:
  sudo ./multi-user-containers.sh logs john
  sudo ./multi-user-containers.sh logs john 100

# Show resource usage
sudo ./multi-user-containers.sh stats <username>
```

### Monitoring

```bash
# Monitor all containers
sudo ./multi-user-containers.sh monitor

# List all users and SSH status
sudo ./ssh-gateway.sh list

# Test user's SSH configuration
sudo ./ssh-gateway.sh test <username>

# View SSH access logs
sudo tail -f /var/lib/user-containers/logs/access.log
```

---

## 🔐 Access Methods

### SSH Password Access (Recommended - Super Simple!)

**Users login with just username + password - no SSH keys needed!**

#### Why This Is Best

- ✅ **No SSH keys** - Users don't need to generate keys
- ✅ **No key management** - You don't manage public keys
- ✅ **Easy onboarding** - Just send username + password
- ✅ **Users can change passwords** - Run `passwd` inside container
- ✅ **Works with Cloudflare Tunnel** - Same as everything else
- ✅ **Clean system** - No extra visible users

#### Setup (Admin - One Time)

```bash
cd ~/devops/scripts

# 1. Setup password SSH gateway
sudo ./ssh-gateway.sh setup

# 2. Create users (they automatically get SSH access)
sudo ./multi-user-containers.sh create-user john --memory 1g
sudo ./multi-user-containers.sh create-user alice --memory 1g
```

**Done!** Each user can now SSH with their password.

#### User Connects

**Direct connection:**
```bash
ssh -p 2222 john@your-server-ip
Password: [initial password from admin]
```

**Via Cloudflare Tunnel:**
```bash
ssh john@ssh.yourdomain.com -o ProxyCommand="cloudflared access ssh --hostname %h"
Password: [initial password]
```

#### Change Password (User)

Once logged in, users can change their password:
```bash
# Inside container
passwd

# Enter current password
# Enter new password (twice)
```

**Password changes are permanent and secure!**

#### Get User's Password (Admin)

```bash
# View initial password
sudo cat /var/lib/user-containers/users/john/password.txt

# Or reset password
sudo ./ssh-gateway.sh reset-password john
```

#### Example SSH Config (User)

Create `~/.ssh/config`:
```
Host mycontainer
    HostName ssh.yourdomain.com
    User john
    ProxyCommand cloudflared access ssh --hostname %h

# Or for direct connection
Host mycontainer-direct
    HostName your-server-ip
    User john
    Port 2222
```

Then simply:
```bash
ssh mycontainer
Password: [your password]
```

**Pros:**
- ✅ Super simple - just username + password
- ✅ No SSH key generation needed
- ✅ Easy for non-technical users
- ✅ Users can change their own passwords
- ✅ Works from any device (mobile, tablets)
- ✅ No key management overhead

**Cons:**
- ⚠️ Less secure than SSH keys (passwords can be guessed)
- ⚠️ Need to type password each time (unless using ssh-agent)

**Security Tips:**
- Use strong passwords (12+ characters)
- Enable fail2ban to prevent brute force
- Use Cloudflare Tunnel for extra protection
- Consider Cloudflare Access for 2FA

---

### Alternative: Direct Shell (Admin Only)

**For admin access only - not for users**

```bash
# From server
sudo ./multi-user-containers.sh shell john
```

**Pros:** Immediate access  
**Cons:** Requires server access, admin privileges

---

**Perfect for laptop servers on residential WiFi with no port forwarding!**

#### Why Use This?

- ✅ **No port forwarding** needed
- ✅ **No static IP** needed
- ✅ Works from **anywhere**
- ✅ **Free** (Cloudflare Tunnel)
- ✅ Secure (encrypted via Cloudflare)
- ✅ Reliable (auto-reconnects)

#### Setup (Admin - One Time)

**Step 1: Setup containers + SSH**
```bash
sudo ./multi-user-containers.sh init
sudo ./multi-user-containers.sh setup-ssh
```

**Step 2: Setup Cloudflare Tunnel**
```bash
cd ~/devops/scripts
sudo ./cloudflare-tunnel-setup.sh
# Follow prompts to create tunnel
```

**Step 3: Configure SSH in Tunnel**
```bash
sudo nano ~/.cloudflared/config.yml
```

Add SSH to ingress rules:
```yaml
tunnel: <your-tunnel-id>
credentials-file: /root/.cloudflared/<tunnel-id>.json

ingress:
  # SSH access via Cloudflare
  - hostname: ssh.yourdomain.com
    service: ssh://localhost:2222
  
  # Your web apps
  - hostname: sparkles.yourdomain.com
    service: http://localhost:8080
  
  - hostname: orchestai.yourdomain.com
    service: http://localhost:8000
  
  # Catch-all
  - service: http_status:404
```

**Step 4: Restart Tunnel**
```bash
sudo systemctl restart cloudflared
```

**Step 5: Add DNS Record in Cloudflare Dashboard**
- Go to your domain → DNS
- Add record:
  - Type: `CNAME`
  - Name: `ssh`
  - Target: `<tunnel-id>.cfargotunnel.com`
  - Proxy: **ON** (orange cloud)
- Save

#### User Access (via Cloudflare Tunnel)

**One-time setup (user's machine):**
```bash
# Mac
brew install cloudflare/cloudflare/cloudflared

# Linux
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Windows
# Download from: https://github.com/cloudflare/cloudflared/releases
```

**Connect via tunnel:**
```bash
ssh -o ProxyCommand="cloudflared access ssh --hostname ssh.yourdomain.com" john@ssh.yourdomain.com
```

**Or create SSH config (`~/.ssh/config`):**
```
Host mycontainer
    HostName ssh.yourdomain.com
    User john
    ProxyCommand cloudflared access ssh --hostname ssh.yourdomain.com
```

Then simply:
```bash
ssh mycontainer
passwd  # Change password
```

**Pros:**
- ✅ No port forwarding needed
- ✅ No static IP needed
- ✅ Works on WiFi/mobile hotspot
- ✅ Free (Cloudflare Tunnel)
- ✅ Accessible from anywhere
- ✅ Optional Zero Trust security

**Cons:**
- Requires users install `cloudflared` client
- Slightly more complex setup

#### Comparison: Direct vs Cloudflare Tunnel

| Feature | Direct SSH | Cloudflare Tunnel |
|---------|-----------|-------------------|
| Port Forwarding | Required | ❌ Not needed |
| Static IP | Required | ❌ Not needed |
| Works on WiFi | Only if public IP | ✅ Always |
| Client Setup | None | Install cloudflared |
| Command | `ssh -p 2222 user@ip` | `ssh` via ProxyCommand |
| Cost | Free | Free |
| Speed | Direct (fastest) | Via Cloudflare edge |

**Recommendation:**
- **Laptop on WiFi/residential ISP** → Use Cloudflare Tunnel
- **VPS with static IP** → Use Direct SSH
- **Both** → Support both methods (best flexibility)

---

### Method 3: Direct Shell (Admin Only)

**For admin access only - not for users**

```bash
# From server
sudo ./multi-user-containers.sh shell john
```

**Pros:** Immediate access  
**Cons:** Requires server access, admin privileges

---

## 🎯 Use Cases & Examples

### Use Case 1: Laptop Server (WiFi, No Port Forwarding)

**Perfect for your setup!**

```bash
# === ADMIN SETUP ===

cd ~/devops/scripts

# 1. Initialize everything
sudo ./multi-user-containers.sh init
sudo ./ssh-gateway.sh setup
sudo ./cloudflare-tunnel-setup.sh

# 2. Configure tunnel for SSH
sudo nano ~/.cloudflared/config.yml
# Add: - hostname: ssh.yourdomain.com
#        service: ssh://localhost:2222

# 3. Restart tunnel
sudo systemctl restart cloudflared

# 4. Create users
sudo ./multi-user-containers.sh create-user john --memory 1g
sudo ./multi-user-containers.sh create-user alice --memory 1g

# 5. Get passwords
sudo cat /var/lib/user-containers/users/john/password.txt
sudo cat /var/lib/user-containers/users/alice/password.txt

# === USER SETUP ===

# 6. Users install cloudflared (one time)
brew install cloudflare/cloudflare/cloudflared

# 7. Users connect
ssh john@ssh.yourdomain.com -o ProxyCommand="cloudflared access ssh --hostname %h"
Password: [initial password]

# 8. Users change passwords
passwd
```

**Now accessible from anywhere, no port forwarding!**

---

### Use Case 2: Development Environments

```bash
# Create dev environment for each team member
sudo ./multi-user-containers.sh create-user dev1 --image node:20 --memory 1g
sudo ./multi-user-containers.sh create-user dev2 --image python:3.11 --memory 1g
sudo ./multi-user-containers.sh create-user dev3 --image golang:1.21 --memory 1g

# Share passwords with team
sudo cat /var/lib/user-containers/users/dev1/password.txt

# Each dev logs in and installs tools
ssh -p 2222 dev1@server-ip
npm install -g typescript
```

---

### Use Case 3: Training Workshop

```bash
# Create 10 student environments
for i in {1..10}; do
    sudo ./multi-user-containers.sh create-user student$i \
        --image ubuntu:22.04 \
        --memory 512m \
        --cpu 0.5
done

# Get all passwords
for i in {1..10}; do
    echo "student$i: $(sudo cat /var/lib/user-containers/users/student$i/password.txt)"
done

# Share credentials with students
# They connect: ssh -p 2222 student1@workshop-server-ip
```

---

```bash
# Create 10 student environments
for i in {1..10}; do
    sudo ./multi-user-containers.sh create-user student$i \
        --image ubuntu:22.04 \
        --memory 512m \
        --cpu 0.5
done

# Install workshop materials
for i in {1..10}; do
    sudo ./multi-user-containers.sh exec student$i 'apt update && apt install -y python3 git vim'
done

# Setup SSH access for all
for i in {1..10}; do
    sudo ./ssh-gateway.sh add-key student$i
done
```

---

### Use Case 3: Demo Accounts

```bash
# Create demo account with limited resources
sudo ./multi-user-containers.sh create-user demo \
    --memory 256m \
    --cpu 0.5 \
    --disk 2G

# Pre-install demo software
sudo ./multi-user-containers.sh exec demo '
    apt update
    apt install -y nginx python3 nodejs
    systemctl start nginx
'

# Get credentials
sudo cat /var/lib/user-containers/users/demo/password.txt
```

---

### Use Case 4: Isolated Testing

```bash
# Create test environment
sudo ./multi-user-containers.sh create-user tester --memory 2g

# Run tests in isolation
sudo ./multi-user-containers.sh exec tester '
    git clone https://github.com/your/repo
    cd repo
    npm install
    npm test
'

# View test logs
sudo ./multi-user-containers.sh logs tester
```

---

## 🔒 Security Features

### User Isolation

Each user gets:
- ✅ Separate container
- ✅ Own filesystem
- ✅ Isolated network namespace
- ✅ Resource limits
- ✅ Password authentication
- ✅ Cannot access other users' containers

### Resource Limits

Prevents resource exhaustion:
```bash
# CPU: Limit to X cores
--cpu 1.0  # 100% of 1 CPU core
--cpu 0.5  # 50% of 1 CPU core
--cpu 2.0  # 2 full CPU cores

# Memory: Limit RAM
--memory 512m   # 512 MB
--memory 1g     # 1 GB
--memory 2g     # 2 GB

# Disk: Limit storage
--disk 5G   # 5 GB
--disk 10G  # 10 GB
```

### Access Control

- Passwords hashed with SHA256
- SSH key-based authentication available
- Per-user access logs
- Container-level isolation

### Audit Logging

All access logged to:
- `/var/lib/container-gateway/logs/access.log` (SSH)
- `/var/lib/container-gateway/logs/web-access.log` (Web)
- Container logs viewable with `logs` command

---

## 📊 Monitoring & Management

### Check System Status

```bash
# List all users
sudo ./multi-user-containers.sh list-users

# Monitor all containers
sudo ./multi-user-containers.sh monitor

# Check specific user
sudo ./multi-user-containers.sh stats john
```

### View Logs

```bash
# Container logs
sudo ./multi-user-containers.sh logs john

# SSH access logs
sudo cat /var/lib/container-gateway/logs/access.log

# Web access logs
sudo cat /var/lib/container-gateway/logs/web-access.log

# System logs
sudo journalctl -u web-terminal-gateway -f
```

### Cleanup

```bash
# Delete inactive users
sudo ./multi-user-containers.sh delete-user old-user

# Remove SSH keys
sudo ./ssh-gateway.sh remove-key old-user

# Clean Docker
docker system prune -af
```

---

## 🌐 Remote Access with Cloudflare Tunnels

### Why Cloudflare Tunnels?

Perfect for accessing your containers remotely without:
- ❌ Port forwarding
- ❌ Static IP address
- ❌ Firewall configuration
- ❌ Exposing SSH directly to internet

### Setup Cloudflare Tunnel for SSH

**Step 1: Install cloudflared**

On your Linux server:
```bash
# Download cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
```

**Step 2: Authenticate with Cloudflare**

```bash
cloudflared tunnel login
# Opens browser - login with your Cloudflare account
```

**Step 3: Create a Tunnel**

```bash
# Create tunnel named "ssh-gateway"
cloudflared tunnel create ssh-gateway

# Note the Tunnel ID shown (like: 8e2a5f7b-3c4d-4e5f-8a9b-1c2d3e4f5a6b)
```

**Step 4: Configure Tunnel**

Create config file:
```bash
sudo nano ~/.cloudflared/config.yml
```

Add this configuration:
```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /root/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  # SSH access through Cloudflare
  - hostname: ssh.yourdomain.com
    service: ssh://localhost:2222
  # Catch-all rule (required)
  - service: http_status:404
```

**Step 5: Create DNS Record**

```bash
cloudflared tunnel route dns ssh-gateway ssh.yourdomain.com
```

**Step 6: Run Tunnel**

```bash
# Test first
cloudflared tunnel run ssh-gateway

# If works, install as service
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

### Connecting Through Cloudflare Tunnel

**On Client Machine (Mac/Linux/Windows):**

```bash
# Install cloudflared client
# Mac:
brew install cloudflare/cloudflare/cloudflared

# Linux:
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared

# Windows:
# Download from: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/
```

**Connect via SSH:**

```bash
# Method 1: Using ProxyCommand (Recommended)
ssh john@ssh.yourdomain.com \
  -o ProxyCommand="cloudflared access ssh --hostname %h"

# Method 2: Using cloudflared access directly
cloudflared access ssh --hostname ssh.yourdomain.com --url john@ssh.yourdomain.com
```

**Add to ~/.ssh/config for easy access:**

```
Host myserver
    HostName ssh.yourdomain.com
    User john
    ProxyCommand cloudflared access ssh --hostname %h
```

Now just use:
```bash
ssh myserver
```

### Cloudflare Access Policies (Optional Security)

Add authentication before SSH:

1. Go to Cloudflare Zero Trust Dashboard
2. Navigate to **Access** → **Applications**
3. Click **Add an Application** → **Self-hosted**
4. Configure:
   - **Application name:** SSH Gateway
   - **Session duration:** 24 hours
   - **Application domain:** ssh.yourdomain.com
5. Add access policy:
   - **Rule name:** Allow specific emails
   - **Rule action:** Allow
   - **Include:** Emails ending in @yourdomain.com

Now users must authenticate through Cloudflare before SSH login!

### Troubleshooting Cloudflare Tunnel

**Tunnel not connecting:**
```bash
# Check tunnel status
sudo systemctl status cloudflared

# View logs
sudo journalctl -u cloudflared -f

# Test tunnel manually
cloudflared tunnel run ssh-gateway
```

**DNS not resolving:**
```bash
# Verify DNS record
dig ssh.yourdomain.com

# Check Cloudflare DNS settings in dashboard
```

**SSH connection times out:**
```bash
# Verify SSH service is running on port 2222
sudo netstat -tlnp | grep 2222

# Test local SSH works
ssh -p 2222 john@localhost

# Check firewall (should not block, tunnel handles it)
sudo ufw status
```

**Connection refused:**
```bash
# Ensure service points to correct port in config.yml
# Should be: service: ssh://localhost:2222

# Restart tunnel
sudo systemctl restart cloudflared
```

---

## 🔧 Advanced Configuration

### Custom Docker Images

```bash
# Use specific images for different users
sudo ./multi-user-containers.sh create-user python-dev --image python:3.11
sudo ./multi-user-containers.sh create-user node-dev --image node:20
sudo ./multi-user-containers.sh create-user rust-dev --image rust:latest
```

### Persistent Data

User data is stored in:
```
/var/lib/user-containers/users/USERNAME/
├── home/        # User's home directory
├── data/        # Shared data folder
├── logs/        # Container logs
└── password.txt # User password (secure)
```

### Resource Monitoring

```bash
# Real-time stats
watch -n 2 'sudo ./multi-user-containers.sh monitor'

# CPU usage only
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}"

# Memory usage only
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"
```

---

## 🚨 Troubleshooting

### Container Won't Start

```bash
# Check Docker
sudo systemctl status docker

# Check container logs
sudo docker logs user-username-12345

# Restart container
sudo ./multi-user-containers.sh restart username
```

### SSH Gateway Not Working

```bash
# Check SSH service
sudo systemctl status sshd

# Check gateway port
sudo netstat -tlnp | grep 2222

# Test SSH config
sudo sshd -t

# View SSH logs
sudo tail -f /var/log/auth.log
```

### Web Terminal Not Working

```bash
# Check service
sudo ./web-terminal-gateway.sh status

# View logs
sudo ./web-terminal-gateway.sh logs

# Restart service
sudo ./web-terminal-gateway.sh restart
```

### User Can't Access Container

```bash
# Check if container exists
docker ps -a | grep username

# Check if running
docker ps | grep username

# Start if stopped
sudo ./multi-user-containers.sh start username

# Reset password
sudo ./multi-user-containers.sh reset-password username
```

---

## 💡 Best Practices

1. **Set appropriate resource limits** - Don't give all users unlimited resources
2. **Use SSH keys** for production - More secure than passwords
3. **Enable HTTPS for web terminal** - Protect credentials in transit
4. **Regular backups** - Backup `/var/lib/user-containers/`
5. **Monitor resource usage** - Check for resource exhaustion
6. **Clean up old users** - Remove inactive accounts
7. **Update containers** - Keep base images up to date
8. **Use specific images** - Don't use `latest` tag in production

---

## 📈 Scaling

### Single Server Limits

Typical server can handle:
- 8GB RAM → ~10 users (512MB each)
- 16GB RAM → ~20 users (512MB each)
- 32GB RAM → ~50 users (512MB each)

### Load Balancing (Multiple Servers)

```bash
# Server 1: users 1-10
# Server 2: users 11-20
# Server 3: users 21-30

# Use DNS round-robin or load balancer
```

---

## 🎉 Complete Example Workflow

```bash
# 1. Setup system
cd ~/devops/scripts
sudo ./multi-user-containers.sh init
sudo ./ssh-gateway.sh setup
sudo ./web-terminal-gateway.sh setup
sudo ./web-terminal-gateway.sh start

# 2. Create users
sudo ./multi-user-containers.sh create-user john --memory 1g
sudo ./multi-user-containers.sh create-user alice --memory 1g

# 3. Add SSH keys
sudo ./ssh-gateway.sh add-key john
sudo ./ssh-gateway.sh add-key alice

# 4. Users connect
# John: ssh -p 2222 john@server-ip
# Alice: ssh -p 2222 alice@server-ip
# Or web: http://server-ip:7681

# 5. Monitor
sudo ./multi-user-containers.sh monitor

# 6. Cleanup when done
sudo ./multi-user-containers.sh delete-user john
sudo ./multi-user-containers.sh delete-user alice
```

---

## 📦 What You Get

### Password-Based SSH Access
✅ Super simple - just username + password  
✅ No SSH keys to generate or manage  
✅ Easy for non-technical users  
✅ Works from any device  
✅ Users can change passwords  
✅ Clean system (no visible users)  

### For Laptop Servers (WiFi)
✅ Multi-user isolated containers  
✅ SSH access via Cloudflare Tunnel  
✅ No port forwarding needed  
✅ No static IP needed  
✅ Complete isolation between users  
✅ Resource limits per user  
✅ Free (Cloudflare Tunnel)  

### For VPS Servers (Static IP)
✅ Multi-user isolated containers  
✅ Direct SSH access (port 2222)  
✅ Simpler setup (no tunnel)  
✅ Faster connection (no proxy)  
✅ Complete isolation between users  
✅ Resource limits per user  

---

## 🔗 Additional Resources

**Scripts Location:** `/Users/aryanag/Documents/devops/scripts/`

**Key Scripts:**
- `multi-user-containers.sh` - Container management (create, delete, monitor)
- `ssh-gateway.sh` - Password-based SSH gateway
- `cloudflare-tunnel-setup.sh` - Setup Cloudflare Tunnel (optional)

**Related Docs:**
- `SSH-PASSWORD-GUIDE.md` - Complete password SSH guide
- `SSH-SETUP-GUIDE.md` - Detailed SSH configuration
- `SSH-CLOUDFLARE-TUNNEL.md` - Cloudflare Tunnel specifics
- `QUICKSTART-MULTI-USER.md` - Quick 5-minute guide
- `SAFETY-GUIDE.md` - Laptop server safety tips

---

**All ready to deploy! 🚀**

**Choose your setup:**
- **Laptop/WiFi** → Use Cloudflare Tunnel method (no port forwarding)
- **VPS/Static IP** → Use Direct SSH method (simpler/faster)
- **Both work with passwords** → No SSH key management needed!
