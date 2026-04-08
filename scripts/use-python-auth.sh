#!/bin/bash

echo "=== Creating Python-Based Password Checker ==="
echo ""

# Create Python script for reliable password checking
cat << 'PYSCRIPT' | sudo tee /var/lib/user-containers/check-password.py > /dev/null
#!/usr/bin/env python3
import sys
import os
import hashlib

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
            if line.startswith(username + ':'):
                parts = line.strip().split(':')
                if len(parts) >= 3:
                    stored_hash = parts[2]
                    break
        else:
            sys.exit(1)  # User not found
except:
    sys.exit(1)

# Hash input password
input_hash = hashlib.sha256(password.encode()).hexdigest()

# Compare
if input_hash == stored_hash:
    sys.exit(0)
else:
    sys.exit(1)
PYSCRIPT

sudo chmod +x /var/lib/user-containers/check-password.py
echo "✓ Created Python password checker"
echo ""

# Update PAM to use Python script
sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.backup-python-$(date +%s)
sudo sed -i 's|/var/lib/user-containers/check-password.sh|/var/lib/user-containers/check-password.py|g' /etc/pam.d/sshd

echo "✓ Updated PAM to use Python script"
echo ""

# Show PAM config
echo "PAM configuration:"
sudo grep "pam_exec" /etc/pam.d/sshd
echo ""

# Test manually
echo "Testing manually:"
if echo -n "TestPass123" | sudo PAM_USER=ary /var/lib/user-containers/check-password.py; then
    echo "✓ Manual test passed"
    echo "Exit code: $?"
else
    echo "✗ Manual test failed"
    echo "Exit code: $?"
fi
echo ""

# Restart SSH
sudo systemctl restart sshd || sudo systemctl restart ssh
echo "✓ SSH restarted"
echo ""

echo "=== Python Script Ready ==="
echo ""
echo "Python handles stdin more reliably than bash."
echo ""
echo "Test now:"
echo "  ssh -p 2222 ary@localhost"
echo "  Password: TestPass123"
