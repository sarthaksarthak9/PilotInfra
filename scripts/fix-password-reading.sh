#!/bin/bash

echo "=== Fixing Password Reading in Check Script ==="
echo ""

# Create fixed password checker that reads password correctly
cat << 'EOF' | sudo tee /var/lib/user-containers/check-password.sh > /dev/null
#!/bin/bash
# Password checker for container users
# Called by PAM with expose_authtok

# Get username from PAM
USERNAME="${PAM_USER}"

if [ -z "$USERNAME" ]; then
    exit 1
fi

# Read password from stdin (sent by PAM with expose_authtok)
# Read entire stdin, not just one line
PASSWORD=$(cat)

if [ -z "$PASSWORD" ]; then
    exit 1
fi

# Get stored hash from database
DB_LINE=$(grep "^${USERNAME}:" /var/lib/user-containers/users.db 2>/dev/null)
if [ -z "$DB_LINE" ]; then
    exit 1
fi

STORED_HASH=$(echo "$DB_LINE" | cut -d: -f3)

# Hash the provided password
INPUT_HASH=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')

# Compare hashes
if [ "$INPUT_HASH" = "$STORED_HASH" ]; then
    exit 0
else
    exit 1
fi
EOF

sudo chmod +x /var/lib/user-containers/check-password.sh
echo "✓ Fixed password checker script"
echo ""

# Update PAM to use the fixed non-debug version
sudo sed -i 's|/var/lib/user-containers/check-password-debug.sh|/var/lib/user-containers/check-password.sh|g' /etc/pam.d/sshd
echo "✓ Updated PAM to use fixed script"
echo ""

# Show PAM config
echo "PAM configuration:"
sudo grep "pam_exec" /etc/pam.d/sshd
echo ""

# Clear old debug log
echo "" | sudo tee /tmp/pam-debug.log > /dev/null
echo "✓ Cleared debug log"
echo ""

# Restart SSH
sudo systemctl restart sshd || sudo systemctl restart ssh
echo "✓ SSH restarted"
echo ""

echo "=== Fix Complete ==="
echo ""
echo "The issue was: 'read -r PASSWORD' only read until whitespace/newline"
echo "The fix: Use 'PASSWORD=\$(cat)' to read entire stdin"
echo ""
echo "Test now:"
echo "  ssh -p 2222 ary@localhost"
echo "  Password: TestPass123"
