#!/bin/bash

USERNAME="${1:-ary}"
PASSWORD="${2:-TestPass123}"

echo "=== Complete Password Authentication Debug ==="
echo ""
echo "Testing user: $USERNAME"
echo "Testing password: $PASSWORD"
echo ""

echo "1. Check PAM configuration:"
echo "---------------------------"
echo "Looking for expose_authtok in /etc/pam.d/sshd..."
if sudo grep "expose_authtok" /etc/pam.d/sshd | grep -q "pam_exec"; then
    echo "✓ expose_authtok is present"
    sudo grep "pam_exec" /etc/pam.d/sshd
else
    echo "✗ expose_authtok is MISSING!"
    echo "Current line:"
    sudo grep "pam_exec" /etc/pam.d/sshd
    echo ""
    echo "Should be:"
    echo "auth    sufficient   pam_exec.so expose_authtok quiet /var/lib/user-containers/check-password.sh"
fi
echo ""

echo "2. Check user exists in database:"
echo "----------------------------------"
if sudo grep -q "^$USERNAME:" /var/lib/user-containers/users.db; then
    echo "✓ User exists"
    sudo grep "^$USERNAME:" /var/lib/user-containers/users.db
else
    echo "✗ User NOT found in database"
    echo "Available users:"
    sudo cat /var/lib/user-containers/users.db
fi
echo ""

echo "3. Test password hash:"
echo "----------------------"
EXPECTED_HASH=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')
STORED_HASH=$(sudo grep "^$USERNAME:" /var/lib/user-containers/users.db | cut -d: -f3)
echo "Password: $PASSWORD"
echo "Expected hash: $EXPECTED_HASH"
echo "Stored hash:   $STORED_HASH"
if [ "$EXPECTED_HASH" = "$STORED_HASH" ]; then
    echo "✓ Password hash matches"
else
    echo "✗ Password hash MISMATCH!"
fi
echo ""

echo "4. Test password checker script manually:"
echo "------------------------------------------"
echo "Running: echo -n '$PASSWORD' | sudo PAM_USER=$USERNAME /var/lib/user-containers/check-password.sh"
if echo -n "$PASSWORD" | sudo PAM_USER=$USERNAME /var/lib/user-containers/check-password.sh; then
    echo "✓ Password checker script works (exit code: $?)"
else
    EXIT_CODE=$?
    echo "✗ Password checker script FAILED (exit code: $EXIT_CODE)"
fi
echo ""

echo "5. Check script permissions and syntax:"
echo "---------------------------------------"
ls -la /var/lib/user-containers/check-password.sh
echo ""
echo "Check for errors:"
sudo bash -n /var/lib/user-containers/check-password.sh && echo "✓ No syntax errors" || echo "✗ Syntax errors found"
echo ""

echo "6. Recent authentication failures:"
echo "----------------------------------"
echo "Last 5 failed attempts for $USERNAME:"
sudo grep "Failed password.*$USERNAME" /var/log/auth.log | tail -5
echo ""

echo "7. Check PAM execution in logs:"
echo "-------------------------------"
echo "Last pam_exec calls:"
sudo grep "pam_exec" /var/log/auth.log | tail -5
echo ""

echo "8. Check SSH configuration:"
echo "---------------------------"
echo "UsePAM setting:"
sudo grep "^UsePAM" /etc/ssh/sshd_config
echo ""
echo "PasswordAuthentication setting:"
sudo grep "^PasswordAuthentication" /etc/ssh/sshd_config
echo ""
echo "ChallengeResponseAuthentication setting:"
sudo grep "^ChallengeResponseAuthentication" /etc/ssh/sshd_config
echo ""

echo "9. Test with debug SSH server:"
echo "------------------------------"
echo "To see detailed auth flow, run in another terminal:"
echo "  sudo /usr/sbin/sshd -d -p 2223 -f /etc/ssh/sshd_config"
echo ""
echo "Then test from another terminal:"
echo "  ssh -p 2223 $USERNAME@localhost"
echo ""

echo "10. View complete PAM stack:"
echo "----------------------------"
sudo head -30 /etc/pam.d/sshd
echo ""

echo "=== Debug Complete ==="
echo ""
echo "If manual test (step 4) works but SSH fails, the issue is in PAM or SSH config."
echo "If manual test fails, the issue is in the password checker script or database."
