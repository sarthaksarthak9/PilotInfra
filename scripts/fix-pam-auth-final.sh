#!/bin/bash

echo "=== Creating Proper PAM Authentication Script ==="
echo ""

# According to PAM documentation, pam_exec with expose_authtok 
# passes the password with a NULL byte, not a newline
# We need to read it properly

cat << 'AUTHSCRIPT' | sudo tee /var/lib/user-containers/check-password.sh > /dev/null
#!/bin/bash
# PAM authentication script for virtual container users
# Must handle input from PAM expose_authtok correctly

USERNAME="${PAM_USER}"
[ -z "$USERNAME" ] && exit 1

# Read password - PAM sends it followed by null byte
# Use dd to read properly, or use Python/Perl for reliable reading
PASSWORD=$(head -n 1)

[ -z "$PASSWORD" ] && exit 1

# Lookup user in database
DB_FILE="/var/lib/user-containers/users.db"
DB_LINE=$(grep "^${USERNAME}:" "$DB_FILE" 2>/dev/null)
[ -z "$DB_LINE" ] && exit 1

# Extract stored hash
STORED_HASH=$(echo "$DB_LINE" | cut -d: -f3)

# Hash input password
INPUT_HASH=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')

# Compare
[ "$INPUT_HASH" = "$STORED_HASH" ] && exit 0 || exit 1
AUTHSCRIPT

sudo chmod +x /var/lib/user-containers/check-password.sh
echo "✓ Created authentication script"
echo ""

# Test it
echo "Manual test:"
if echo -n "TestPass123" | sudo PAM_USER=ary /var/lib/user-containers/check-password.sh; then
    echo "✓ Works"
else
    echo "✗ Failed"
fi
echo ""

sudo systemctl restart sshd
echo "✓ SSH restarted"
echo ""

echo "Test: ssh -p 2222 ary@localhost"
