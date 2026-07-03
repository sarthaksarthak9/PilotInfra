# 🔐 SSH Password Access Guide

**Simple password-based SSH - No keys needed!**

---

## 🎯 Overview

Users access containers with just username + password:

```
User's Machine
    ↓
ssh username@server-ip
    ↓
Password prompt
    ↓
Authenticated
    ↓
Container
```

**No SSH keys, no public key management!**

---

## 🚀 Quick Setup

### Admin Setup (One Time)

```bash
cd ~/devops/scripts

# 1. Setup password SSH gateway
sudo ./ssh-gateway-password.sh setup

# 2. Create users (automatically SSH-enabled)
sudo ./multi-user-containers.sh create-user john --memory 1g
sudo ./multi-user-containers.sh create-user alice --memory 1g
```

**Done!** Users can now login with password.

---

## 👤 User Access

### Connect via SSH

```bash
# Direct connection
ssh -p 2222 john@your-server-ip

# Via Cloudflare Tunnel
ssh john@ssh.yourdomain.com -o ProxyCommand="cloudflared access ssh --hostname %h"

# Enter password when prompted
```

**That's it!** User lands in their container.

---

## �� How It Works

### Traditional SSH (with keys):
```
1. User generates SSH key pair
2. User sends public key to admin
3. Admin adds public key to server
4. User connects with private key
```

### Password SSH (much simpler):
```
1. Admin creates user
2. User gets username + password
3. User connects with password
4. Done!
```

---

## 🔧 Admin Commands

```bash
# List all users
sudo ./ssh-gateway-password.sh list

# Reset user's password
sudo ./ssh-gateway-password.sh reset-password john

# Test user's config
sudo ./ssh-gateway-password.sh test john

# View access logs
sudo tail -f /var/lib/user-containers/logs/access.log
```

---

## 🆚 Comparison: Keys vs Passwords

| Feature | SSH Keys | Passwords |
|---------|----------|-----------|
| **Setup** | Complex | Simple |
| **User onboarding** | Send key, admin adds | Send password, done |
| **Security** | More secure | Less secure |
| **Convenience** | Auto-login | Type password |
| **Key management** | Admin manages keys | No keys to manage |
| **Password change** | User can't | User can (passwd) |
| **Revoke access** | Remove key | Change password |

---

## 🔐 Security Considerations

### Passwords Are:
- ✅ **Easier** for users (no SSH key generation)
- ✅ **Simpler** for admins (no key management)
- ✅ **Changeable** by users (via `passwd` in container)
- ⚠️ **Less secure** than SSH keys (can be brute-forced)
- ⚠️ **Shoulder-surfing** risk (visible when typing)

### Recommendations:
1. **Use strong passwords** (12+ characters, random)
2. **Enable fail2ban** to prevent brute force
3. **Use Cloudflare Tunnel** (adds extra layer)
4. **Monitor access logs** regularly
5. **Rotate passwords** periodically
6. **Consider 2FA** for production (via Cloudflare Access)

---

## 🌐 With Cloudflare Tunnel

### Extra Security Layer

```bash
# Setup Cloudflare Tunnel first
sudo ./cloudflare-tunnel-setup.sh

# Configure for SSH (in ~/.cloudflared/config.yml)
ingress:
  - hostname: ssh.yourdomain.com
    service: ssh://localhost:2222
```

**Now users connect:**
```bash
ssh john@ssh.yourdomain.com -o ProxyCommand="cloudflared access ssh --hostname %h"
```

**Benefits:**
- ✅ No exposed port 2222 to internet
- ✅ Traffic encrypted through Cloudflare
- ✅ Can add Cloudflare Access policies (email verification, 2FA)
- ✅ DDoS protection
- ✅ Works on WiFi without port forwarding

---

## 💡 Best Practices

### For Admins:

1. **Generate strong passwords:**
```bash
openssl rand -base64 16
```

2. **Share passwords securely:**
- Use encrypted messaging (Signal, WhatsApp)
- Don't email passwords in plaintext
- Use password managers

3. **Monitor access:**
```bash
# Watch login attempts
sudo tail -f /var/log/auth.log | grep sshd

# Watch container access
sudo tail -f /var/lib/user-containers/logs/access.log
```

4. **Install fail2ban:**
```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### For Users:

1. **Change password immediately:**
```bash
# After first login inside container
passwd
```

2. **Use password manager** (1Password, Bitwarden, LastPass)

3. **Don't share passwords**

4. **Use SSH config** for convenience:
```bash
# ~/.ssh/config
Host mycontainer
    HostName ssh.yourdomain.com
    User john
    Port 2222
    ProxyCommand cloudflared access ssh --hostname %h
```

Then simply: `ssh mycontainer`

---

## 🚨 Troubleshooting

### "Permission denied"

```bash
# Check password is correct
sudo cat /var/lib/user-containers/users/john/password.txt

# Reset password
sudo ./ssh-gateway-password.sh reset-password john
```

### "User not found"

```bash
# List users
sudo ./ssh-gateway-password.sh list

# Create user
sudo ./multi-user-containers.sh create-user john
```

### "Connection refused"

```bash
# Check SSH service
sudo systemctl status sshd

# Check port 2222
sudo netstat -tlnp | grep 2222

# Restart SSH
sudo systemctl restart sshd
```

### Too many failed logins (fail2ban)

```bash
# Check if IP is banned
sudo fail2ban-client status sshd

# Unban IP
sudo fail2ban-client set sshd unbanip <ip-address>
```

---

## 🎉 Complete Example

```bash
# ===== ADMIN SETUP =====

cd ~/devops/scripts

# 1. Setup password SSH
sudo ./ssh-gateway-password.sh setup

# 2. Setup Cloudflare Tunnel (optional but recommended)
sudo ./cloudflare-tunnel-setup.sh
# Configure with SSH ingress

# 3. Create users
sudo ./multi-user-containers.sh create-user john --memory 1g
sudo ./multi-user-containers.sh create-user alice --memory 1g

# 4. Get passwords
sudo cat /var/lib/user-containers/users/john/password.txt
sudo cat /var/lib/user-containers/users/alice/password.txt

# ===== USER ACCESS =====

# 5. Share credentials with users
# John: username=john, password=abc123xyz
# Alice: username=alice, password=def456uvw

# 6. Users connect
ssh -p 2222 john@server-ip
# or
ssh john@ssh.yourdomain.com -o ProxyCommand="cloudflared access ssh --hostname %h"

# 7. Users change passwords
passwd

# ===== MONITORING =====

# 8. Monitor access
sudo ./ssh-gateway-password.sh list
sudo tail -f /var/lib/user-containers/logs/access.log
```

---

## 🔄 Migration: Keys → Passwords

Already using SSH keys? Switch to passwords:

```bash
# 1. Setup password SSH
sudo ./ssh-gateway-password.sh setup

# 2. Users automatically get password auth
# Keys still work, passwords work too

# 3. To disable keys completely, edit /etc/ssh/sshd_config:
PubkeyAuthentication no
PasswordAuthentication yes

# 4. Restart SSH
sudo systemctl restart sshd
```

---

## 📊 When to Use Each Method

| Scenario | Recommended Method |
|----------|-------------------|
| **Personal projects** | Passwords (simpler) |
| **Team of developers** | SSH keys (more secure) |
| **Training/workshops** | Passwords (easier onboarding) |
| **Production servers** | SSH keys + 2FA |
| **Demo accounts** | Passwords (temporary) |
| **High security** | SSH keys only |

---

**Password SSH = Simple and convenient! 🎉**

No SSH keys to manage, just username + password!
