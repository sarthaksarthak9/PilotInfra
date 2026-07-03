# Container Gateway Security Improvements

This folder contains scripts to enhance the security of your container gateway system.

## Quick Start

**Current Status**: Basic security (good for development)

**To Production-Ready**: Run scripts in this order:

```bash
cd ~/Desktop/linux-server-setup/security

# 1. Change gateway password (required)
sudo passwd containers

# 2. Add audit logging (recommended)
sudo bash add-logging.sh

# 3. Enable SSH keys (highly recommended for production)
bash enable-ssh-keys.sh

# 4. Upgrade password hashing (recommended for production)
sudo bash improve-password-hashing.sh

# 5. Add rate limiting (optional but good)
sudo bash setup-fail2ban.sh
```

## Scripts

### 1. `add-logging.sh` - Audit Logging
**What**: Logs all container access attempts
**Why**: Know who accessed what and when
**Risk**: None - only adds logging
**Run**: `sudo bash add-logging.sh`

### 2. `enable-ssh-keys.sh` - SSH Key Authentication
**What**: Switch from passwords to SSH keys for gateway access
**Why**: Much more secure than passwords
**Risk**: Low - you can revert if needed
**Run**: `bash enable-ssh-keys.sh`

### 3. `improve-password-hashing.sh` - Bcrypt Passwords
**What**: Upgrade from SHA256 to bcrypt for container passwords
**Why**: Protects against rainbow table attacks
**Risk**: Medium - requires resetting all container passwords
**Run**: `sudo bash improve-password-hashing.sh`

### 4. `setup-fail2ban.sh` - Rate Limiting
**What**: Block IPs after failed login attempts
**Why**: Prevents brute force attacks
**Risk**: Low - might lock yourself out if you mistype password
**Run**: `sudo bash setup-fail2ban.sh`

## Security Levels

### Level 1: Development (Current)
- ✅ Cloudflare encryption
- ✅ Container isolation
- ✅ Basic password auth
- Good for: Personal projects, learning

### Level 2: Small Team Production
Run: `add-logging.sh` + `enable-ssh-keys.sh`
- ✅ Everything from Level 1
- ✅ Audit logging
- ✅ SSH key authentication
- Good for: Small team tools, internal apps

### Level 3: Public Production
Run: All scripts
- ✅ Everything from Level 2
- ✅ Bcrypt password hashing
- ✅ Rate limiting (fail2ban)
- Good for: Public services, sensitive data

## Monitoring

After applying improvements, monitor with:

```bash
# View access logs
sudo tail -f /var/log/container-access.log

# View authentication logs
sudo tail -f /var/log/auth.log

# Check fail2ban status (if installed)
sudo fail2ban-client status sshd
```

## Troubleshooting

**Locked out after enabling SSH keys?**
```bash
# From server console/physical access:
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

**Forgot to copy SSH key before disabling passwords?**
```bash
# From Mac, before disabling passwords:
ssh-copy-id -i ~/.ssh/your-key containers@ssh.aryangoyal.space
```

## Reverting Changes

All scripts create backups. To revert:

```bash
# List backups
ls -la /etc/ssh/sshd_config.backup-*
ls -la /var/lib/user-containers/users.db.backup-*

# Restore from backup
sudo cp /etc/ssh/sshd_config.backup-TIMESTAMP /etc/ssh/sshd_config
sudo systemctl restart sshd
```
