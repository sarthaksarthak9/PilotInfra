#!/bin/bash

echo "=== Creating Debug Password Checker ==="
echo ""

# Create debug version of password checker with extensive logging
cat << 'EOF' | sudo tee /var/lib/user-containers/check-password-debug.sh > /dev/null
#!/bin/bash
# Debug version with extensive logging

LOGFILE="/tmp/pam-debug.log"

# Log start
echo "=== $(date) ===" >> "$LOGFILE"
echo "PAM_USER: ${PAM_USER}" >> "$LOGFILE"
echo "PAM_TYPE: ${PAM_TYPE}" >> "$LOGFILE"

# Get username from PAM
USERNAME="${PAM_USER}"

if [ -z "$USERNAME" ]; then
    echo "ERROR: No username provided" >> "$LOGFILE"
    exit 1
fi

echo "Username: $USERNAME" >> "$LOGFILE"

# Read password from stdin (PAM passes it with expose_authtok)
if read -r PASSWORD; then
    echo "Password received: ${#PASSWORD} characters" >> "$LOGFILE"
else
    echo "ERROR: Failed to read password from stdin" >> "$LOGFILE"
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    echo "ERROR: Password is empty" >> "$LOGFILE"
    exit 1
fi

# Get stored hash from database
DB_LINE=$(grep "^${USERNAME}:" /var/lib/user-containers/users.db 2>/dev/null)
if [ -z "$DB_LINE" ]; then
    echo "ERROR: User not found in database" >> "$LOGFILE"
    exit 1
fi

echo "DB line found: $DB_LINE" >> "$LOGFILE"

STORED_HASH=$(echo "$DB_LINE" | cut -d: -f3)
echo "Stored hash: $STORED_HASH" >> "$LOGFILE"

# Hash the provided password
INPUT_HASH=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')
echo "Input hash: $INPUT_HASH" >> "$LOGFILE"

# Compare hashes
if [ "$INPUT_HASH" = "$STORED_HASH" ]; then
    echo "SUCCESS: Hashes match" >> "$LOGFILE"
    exit 0
else
    echo "FAILURE: Hashes do not match" >> "$LOGFILE"
    exit 1
fi
EOF

sudo chmod +x /var/lib/user-containers/check-password-debug.sh
echo "✓ Created debug script"
echo ""

# Update PAM to use debug version
sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.backup-debug-$(date +%s)
sudo sed -i 's|/var/lib/user-containers/check-password.sh|/var/lib/user-containers/check-password-debug.sh|g' /etc/pam.d/sshd
echo "✓ Updated PAM to use debug script"
echo ""

# Show updated PAM config
echo "Updated PAM auth lines:"
sudo grep "pam_exec" /etc/pam.d/sshd
echo ""

# Create log file with proper permissions
sudo touch /tmp/pam-debug.log
sudo chmod 666 /tmp/pam-debug.log
echo "✓ Created log file: /tmp/pam-debug.log"
echo ""

# Restart SSH
sudo systemctl restart sshd || sudo systemctl restart ssh
echo "✓ SSH restarted"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Now try to login:"
echo "  ssh -p 2222 ary@localhost"
echo ""
echo "Then view the debug log:"
echo "  cat /tmp/pam-debug.log"
echo ""
echo "Or watch it live:"
echo "  tail -f /tmp/pam-debug.log"
