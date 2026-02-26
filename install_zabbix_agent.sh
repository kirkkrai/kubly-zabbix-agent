#!/bin/bash
set -e

### ===== CONFIG =====
CUSTOMER_ID="COLS-2022080004"
ZABBIX_PROXY="203.151.50.235,203.151.50.253"
IP=$(hostname -I | awk '{print $1}')
BASE_HOST=$(hostname)
FULL_HOSTNAME="${CUSTOMER_ID}_${BASE_HOST}_${IP}"
### ==================

echo "Installing Zabbix Agent 6.0 (Active via Proxy)..."

apt update -y
apt install -y wget gnupg ca-certificates

# Add Zabbix repo for Ubuntu 24.04 (noble)
wget -qO - https://repo.zabbix.com/zabbix-official-repo.key | gpg --dearmor -o /usr/share/keyrings/zabbix.gpg

echo "deb [signed-by=/usr/share/keyrings/zabbix.gpg] https://repo.zabbix.com/zabbix/6.0/ubuntu noble main" \
  > /etc/apt/sources.list.d/zabbix.list

apt update -y
apt install -y zabbix-agent

# Backup config
cp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.bak.$(date +%F_%T)

# Configure Active mode
sed -i "s/^#*Server=.*/Server=127.0.0.1/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^#*ServerActive=.*/ServerActive=${ZABBIX_PROXY}/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^#*Hostname=.*/Hostname=${FULL_HOSTNAME}/" /etc/zabbix/zabbix_agentd.conf

systemctl enable zabbix-agent
systemctl restart zabbix-agent

echo "Hostname set to: ${FULL_HOSTNAME}"
echo "Done."
