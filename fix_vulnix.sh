## fix_vulnix.sh

```bash
#!/bin/bash
# fix_vulnix.sh - Hardening Script for Vulnix VM
# This script hardens the system against the attack chain discovered in Part A.

set -e

echo "[+] Starting Vulnix Hardening Script..."
echo "[+] Date: $(date)"
echo "[+] Running as: $(whoami)"

# ============================================
# 1. Password Policy Hardening
# ============================================
echo "[+] 1. Hardening password policy..."

# Install libpam-cracklib (Ubuntu 12.04 equivalent of libpam-pwquality)
apt-get update -y
apt-get install -y libpam-cracklib

# Configure password quality requirements
cat > /etc/security/pwquality.conf << 'EOF'
# Minimum password length
minlen = 12
# Require at least one digit
dcredit = -1
# Require at least one uppercase letter
ucredit = -1
# Require at least one lowercase letter
lcredit = -1
# Require at least one special character
ocredit = -1
# Retry limit
retry = 3
EOF

# Update PAM to use cracklib
sed -i 's/pam_unix.so/pam_unix.so remember=5 minlen=12/' /etc/pam.d/common-password
sed -i 's/pam_unix.so/pam_unix.so obscure sha512/' /etc/pam.d/common-password

echo "[+] Password policy hardened."

# ============================================
# 2. Force Password Change for Weak Users
# ============================================
echo "[+] 2. Forcing password change for weak users..."

# Force 'user' to change password on next login
chage -d 0 user

# Force 'vulnix' to change password on next login
chage -d 0 vulnix

echo "[+] Users 'user' and 'vulnix' must change password on next login."

# ============================================
# 3. Disable Unnecessary Services
# ============================================
echo "[+] 3. Disabling unnecessary services..."

# Disable Finger service (port 79)
systemctl stop finger 2>/dev/null || true
systemctl disable finger 2>/dev/null || true
# Remove finger package if installed
apt-get remove -y finger 2>/dev/null || true

# Configure SMTP to disable VRFY and EXPN
cat >> /etc/postfix/main.cf << 'EOF'

# Disable VRFY and EXPN commands to prevent user enumeration
disable_vrfy_command = yes
smtpd_etrn_restrictions = reject
EOF

postfix reload 2>/dev/null || true

echo "[+] Unnecessary services disabled."

# ============================================
# 4. NFS Hardening
# ============================================
echo "[+] 4. Hardening NFS configuration..."

# Back up the original exports file
cp /etc/exports /etc/exports.backup 2>/dev/null || true

# Restore root_squash and restrict exports to specific subnet
cat > /etc/exports << 'EOF'
# /etc/exports: the access control list for filesystems which may be exported
# Restrict to the local subnet (adjust IP range as needed)
/home/vulnix    192.168.0.0/24(rw,sync,root_squash,no_subtree_check)
EOF

# Export the changes
exportfs -ra 2>/dev/null || true

echo "[+] NFS configuration hardened."

# ============================================
# 5. Remove sudoedit Privileges
# ============================================
echo "[+] 5. Removing sudoedit privileges for vulnix..."

# Create a backup of sudoers
cp /etc/sudoers /etc/sudoers.backup 2>/dev/null || true

# Remove the sudoedit line for vulnix
sed -i '/vulnix.*sudoedit/d' /etc/sudoers

# Validate sudoers file
visudo -c 2>/dev/null || true

echo "[+] sudoedit privileges removed."

# ============================================
# 6. SSH Hardening
# ============================================
echo "[+] 6. Hardening SSH configuration..."

# Back up sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true

# Apply SSH hardening
cat >> /etc/ssh/sshd_config << 'EOF'

# Hardening SSH
# Disable root login
PermitRootLogin no
# Limit authentication attempts
MaxAuthTries 3
# Connection timeout
LoginGraceTime 60
# Strict modes for .ssh directory
StrictModes yes
EOF

service ssh restart 2>/dev/null || true

echo "[+] SSH configuration hardened."

# ============================================
# 7. File Permission Hardening
# ============================================
echo "[+] 7. Hardening file permissions..."

# Remove world-writable files (with caution)
find /home -type f -perm -o+w -exec chmod o-w {} \; 2>/dev/null

# Set restrictive permissions on .ssh directories
for user_home in /home/*; do
    if [ -d "$user_home/.ssh" ]; then
        chown root:root "$user_home/.ssh" 2>/dev/null || true
        chmod 700 "$user_home/.ssh" 2>/dev/null || true
        chmod 600 "$user_home/.ssh/authorized_keys" 2>/dev/null || true
    fi
done

echo "[+] File permissions hardened."

# ============================================
# 8. SUID Binary Review
# ============================================
echo "[+] 8. Reviewing SUID binaries..."

# Remove SUID from unnecessary binaries
find / -perm -4000 -type f 2>/dev/null | while read suid_bin; do
    # Skip essential system binaries
    case "$suid_bin" in
        */bin/su|*/bin/mount|*/bin/umount|*/bin/ping|*/usr/bin/sudo|*/usr/bin/passwd|*/usr/bin/gpasswd|*/usr/bin/chfn|*/usr/bin/chsh|*/usr/bin/newgrp|*/usr/sbin/pppd)
            echo "  Keeping: $suid_bin"
            ;;
        *)
            echo "  Removing SUID from: $suid_bin"
            chmod -s "$suid_bin" 2>/dev/null || true
            ;;
    esac
done

echo "[+] SUID binaries reviewed."

# ============================================
# 9. Secure /tmp and /var/tmp
# ============================================
echo "[+] 9. Securing temporary directories..."

# Add to /etc/fstab for persistence
if ! grep -q "/tmp.*nosuid" /etc/fstab; then
    echo "tmpfs /tmp tmpfs rw,nosuid,noexec,nodev 0 0" >> /etc/fstab
fi
if ! grep -q "/var/tmp.*nosuid" /etc/fstab; then
    echo "tmpfs /var/tmp tmpfs rw,nosuid,noexec,nodev 0 0" >> /etc/fstab
fi

# Remount /tmp with secure options
mount -o remount,nosuid,noexec,nodev /tmp 2>/dev/null || true
mount -o remount,nosuid,noexec,nodev /var/tmp 2>/dev/null || true

echo "[+] Temporary directories secured."

# ============================================
# 10. Enable Auditing
# ============================================
echo "[+] 10. Enabling auditing..."

apt-get install -y auditd 2>/dev/null || true
if command -v auditctl >/dev/null 2>&1; then
    # Monitor /etc/exports for changes
    auditctl -w /etc/exports -p wa -k nfs_exports_change
    # Monitor NFS service
    auditctl -w /usr/sbin/exportfs -p x -k nfs_exportfs
fi

echo "[+] Auditing enabled."

# ============================================
# 11. Cleanup - Remove Attack Artifacts
# ============================================
echo "[+] 11. Removing attack artifacts..."

# Remove SUID shell created during attack
rm -f /home/vulnix/bash_suid 2>/dev/null || true
rm -f /tmp/bash_suid 2>/dev/null || true
rm -f /var/tmp/bash_suid 2>/dev/null || true

# Remove SSH keys used during attack
rm -f /home/vulnix/.ssh/authorized_keys 2>/dev/null || true
rm -f /home/user/.ssh/authorized_keys 2>/dev/null || true

# Clear bash histories
cat /dev/null > /root/.bash_history 2>/dev/null || true
cat /dev/null > /home/user/.bash_history 2>/dev/null || true
cat /dev/null > /home/vulnix/.bash_history 2>/dev/null || true

echo "[+] Attack artifacts removed."

# ============================================
# 12. Restart Services
# ============================================
echo "[+] 12. Restarting services..."

service nfs-kernel-server restart 2>/dev/null || true
service ssh restart 2>/dev/null || true

# ============================================
echo "[+] Hardening complete!"
echo "[+] Date: $(date)"
echo "[+] Please verify the hardening by testing the attack vectors."