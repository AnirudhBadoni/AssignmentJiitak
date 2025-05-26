#!/bin/bash
set -e

# Check /var/log mount
if ! mount | grep -q "on /var/log "; then
  echo "WARNING: /var/log is not a separate partition!"
fi

# Disable IP forwarding
sysctl -w net.ipv4.ip_forward=0
echo "net.ipv4.ip_forward=0" >> /etc/sysctl.conf

# Configure local login warning banner
cat <<EOF > /etc/issue
**********************************************************************
* WARNING: Unauthorized access to this system is prohibited.         *
* All activities are monitored and recorded.                         *
**********************************************************************
EOF

# Disable ICMP redirects
sysctl -w net.ipv4.conf.all.accept_redirects=0
echo "net.ipv4.conf.all.accept_redirects=0" >> /etc/sysctl.conf

# Disable IPv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf

# Install auditd if not present
if ! command -v auditctl &> /dev/null; then
  apt update && apt install -y auditd
fi

# Configure audit rules
echo "-w /var/log/faillog -p wa -k logins" >> /etc/audit/rules.d/audit.rules
echo "-w /home -p wa -k user_deletions" >> /etc/audit/rules.d/audit.rules

# Restart auditd
systemctl restart auditd

# Set password expiration to 90 days or less for all normal users
for user in $(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd); do
  chage --maxdays 90 "$user" || true
done

# Set SSH LogLevel to INFO
sed -i 's/^#*LogLevel .*/LogLevel INFO/' /etc/ssh/sshd_config
systemctl restart ssh

echo "Hardening complete."
