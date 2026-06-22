#!/bin/bash

echo "=== Upgrading to Bcrypt Password Hashing ==="
echo ""

# Check if python3-bcrypt is installed
if ! python3 -c "import bcrypt" &>/dev/null; then
    echo "Installing python3-bcrypt..."
    sudo apt-get update -qq
    sudo apt-get install -y python3-bcrypt
    echo "✓ Installed python3-bcrypt"
fi
echo ""

echo "⚠️  WARNING: This will require resetting ALL container user passwords!"
echo ""
echo "Current users:"
grep -v "^#" /var/lib/user-containers/users.db | cut -d: -f1
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi
echo ""

# Backup database
sudo cp /var/lib/user-containers/users.db /var/lib/user-containers/users.db.backup-bcrypt-$(date +%s)
echo "✓ Backed up user database"
echo ""

# Create new bcrypt-based password checker
cat << 'EOF' | sudo tee /var/lib/user-containers/check-password-bcrypt.py > /dev/null
#!/usr/bin/env python3
import sys
import os
import bcrypt

# Get username from environment
username = os.environ.get('PAM_USER', '').strip()
if not username:
    sys.exit(1)

# Read password from stdin
try:
    password = sys.stdin.read().strip()
    if not password:
        sys.exit(1)
except:
    sys.exit(1)

# Read database
db_file = '/var/lib/user-containers/users.db'
try:
    with open(db_file, 'r') as f:
        for line in f:
            if line.startswith('#'):
                continue
            if line.startswith(username + ':'):
                parts = line.strip().split(':')
                if len(parts) >= 3:
                    stored_hash = parts[2]
                    break
        else:
            sys.exit(1)  # User not found
except:
    sys.exit(1)

# Check password with bcrypt
try:
    if bcrypt.checkpw(password.encode(), stored_hash.encode()):
        sys.exit(0)
    else:
        sys.exit(1)
except:
    sys.exit(1)
EOF

sudo chmod +x /var/lib/user-containers/check-password-bcrypt.py
echo "✓ Created bcrypt password checker"
echo ""

# Create password reset tool
cat << 'EOF' | sudo tee /var/lib/user-containers/reset-password-bcrypt.py > /dev/null
#!/usr/bin/env python3
import sys
import bcrypt
import random
import string

if len(sys.argv) != 2:
    print("Usage: reset-password-bcrypt.py USERNAME")
    sys.exit(1)

username = sys.argv[1]

# Generate random password
password = ''.join(random.choices(string.ascii_letters + string.digits, k=16))

# Hash with bcrypt
salt = bcrypt.gensalt(rounds=12)
hashed = bcrypt.hashpw(password.encode(), salt).decode()

# Read database
db_file = '/var/lib/user-containers/users.db'
lines = []
user_found = False

with open(db_file, 'r') as f:
    for line in f:
        if line.startswith(username + ':'):
            parts = line.strip().split(':')
            parts[2] = hashed  # Replace hash
            lines.append(':'.join(parts) + '\n')
            user_found = True
        else:
            lines.append(line)

if not user_found:
    print(f"Error: User '{username}' not found")
    sys.exit(1)

# Write back
with open(db_file, 'w') as f:
    f.writelines(lines)

print(f"✓ Password reset for {username}")
print(f"\nNew password: {password}")
print(f"\nUser can login with:")
print(f"  ssh containers@ssh.aryangoyal.space")
print(f"  Username: {username}")
print(f"  Password: {password}")
EOF

sudo chmod +x /var/lib/user-containers/reset-password-bcrypt.py
echo "✓ Created password reset tool"
echo ""

# Update gateway script to use bcrypt checker
sudo sed -i 's|sha256sum|bcrypt-check|g' /home/containers/gateway.sh

# Actually, need to update gateway to use Python checker
cat << 'EOF' | sudo tee /home/containers/gateway.sh > /dev/null
#!/bin/bash

LOG_FILE="/var/log/container-access.log"

clear
echo "╔══════════════════════════════════════╗"
echo "║   Container Gateway                  ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Available containers:"
echo ""

grep -v "^#" /var/lib/user-containers/users.db | while IFS=: read username container hash timestamp resources; do
    [ -n "$username" ] && echo "  • $username"
done

echo ""
read -p "Username: " TARGET_USER
read -s -p "Password: " TARGET_PASS
echo ""

# Log attempt
echo "$(date -Iseconds) ATTEMPT user=$TARGET_USER from=$SSH_CLIENT" | sudo tee -a "$LOG_FILE" > /dev/null

# Check credentials using bcrypt checker
if echo -n "$TARGET_PASS" | sudo PAM_USER="$TARGET_USER" /var/lib/user-containers/check-password-bcrypt.py; then
    # Get container name
    CONTAINER=$(grep "^${TARGET_USER}:" /var/lib/user-containers/users.db | cut -d: -f2)
    
    # Log success
    echo "$(date -Iseconds) SUCCESS user=$TARGET_USER container=$CONTAINER from=$SSH_CLIENT" | sudo tee -a "$LOG_FILE" > /dev/null
    
    # Connect
    echo "Connecting to $CONTAINER..."
    exec docker exec -it "$CONTAINER" /bin/bash
else
    echo "Error: Invalid username or password"
    echo "$(date -Iseconds) FAILED user=$TARGET_USER from=$SSH_CLIENT reason=invalid_credentials" | sudo tee -a "$LOG_FILE" > /dev/null
    sleep 2
    exit 1
fi
EOF

sudo chmod +x /home/containers/gateway.sh
echo "✓ Updated gateway script"
echo ""

echo "=== Now Reset All User Passwords ==="
echo ""

# Reset passwords for all users
grep -v "^#" /var/lib/user-containers/users.db | cut -d: -f1 | while read username; do
    echo "Resetting password for: $username"
    sudo /var/lib/user-containers/reset-password-bcrypt.py "$username"
    echo ""
done

echo "=== Bcrypt Upgrade Complete ==="
echo ""
echo "✅ Password hashing upgraded to bcrypt (12 rounds)"
echo "✅ All user passwords have been reset (see above)"
echo ""
echo "⚠️  Send new passwords to users securely!"
echo ""
echo "To reset a password later:"
echo "  sudo /var/lib/user-containers/reset-password-bcrypt.py USERNAME"
