#!/bin/bash

echo "=== Fixing Password Reading - Proper Method ==="
echo ""

# Create password checker that reads from stdin correctly for PAM
cat << 'EOF' | sudo tee /var/lib/user-containers/check-password.sh > /dev/null
#!/bin/bash
# Password checker for container users
# Called by PAM with expose_authtok

# Get username from PAM
USERNAME="${PAM_USER}"

if [ -z "$USERNAME" ]; then
    exit 1
fi

# Read password from stdin - PAM sends it as a line with expose_authtok
# Use read with -t timeout to avoid hanging
if ! read -r -t 2 PASSWORD; then
    exit 1
fi

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
echo "✓ Created password checker with proper stdin reading"
echo ""

# Test manually
echo "Testing manually:"
if echo -n "TestPass123" | sudo PAM_USER=ary /var/lib/user-containers/check-password.sh; then
    echo "✓ Manual test passed"
else
    echo "✗ Manual test failed"
fi
echo ""

# Restart SSH
sudo systemctl restart sshd || sudo systemctl restart ssh
echo "✓ SSH restarted"
echo ""

echo "=== Testing with actual SSH ==="
echo ""
echo "Try: ssh -p 2222 ary@localhost"
echo "Password: TestPass123"
echo ""
echo "Watch logs in another terminal:"
echo "  sudo journalctl -u sshd -f"
