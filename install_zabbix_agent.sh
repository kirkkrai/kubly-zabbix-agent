#!/bin/bash
# ==========================================
# ZABBIX AGENT PRODUCTION INSTALL SCRIPT
# Auto Hostname | Active Only | Ubuntu 24.04
# Server 6.0 Compatible
# ==========================================

set -euo pipefail

PROXY_IP="203.151.50.253"
CUSTOMER_CODE="${1:-}"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Run as root"
  exit 1
fi

if [ -z "$CUSTOMER_CODE" ]; then
  echo "Usage: $0 <CUSTOMER_CODE>"
  exit 1
fi

# Detect OS
. /etc/os-release
UBUNTU_MAJOR=$(echo $VERSION_ID | cut -d'.' -f1)

echo "🔎 OS detected: Ubuntu $VERSION_ID"

# Install Zabbix repo (6.4 supports Ubuntu 24.04)
if ! dpkg -s zabbix-release &>/dev/null; then
  echo "📦 Installing Zabbix 6.4 repo..."
  wget -q https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu${UBUNTU_MAJOR}.04_all.deb
  dpkg -i zabbix-release_6.4-1+ubuntu${UBUNTU_MAJOR}.04_all.deb
  apt update -qq
  rm -f zabbix-release_*.deb
fi

# Install agent if not exists
if ! dpkg -s zabbix-agent &>/dev/null; then
  echo "📦 Installing Zabbix Agent..."
  apt install -y zabbix-agent
fi

SERVICE="zabbix-agent"
CONF="/etc/zabbix/zabbix_agentd.conf"

HOST_SHORT=$(hostname -s)
HOST_IP=$(hostname -I | awk '{print $1}')
FULL_HOSTNAME="${CUSTOMER_CODE}_${HOST_SHORT}_${HOST_IP}"

echo "---------------------------------"
echo " Proxy: $PROXY_IP"
echo " Host:  $FULL_HOSTNAME"
echo "---------------------------------"

# Backup config
cp "$CONF" "${CONF}.bak.$(date +%Y%m%d%H%M%S)"

# Clean old config
sed -i '/^Server=/d' "$CONF"
sed -i '/^ServerActive=/d' "$CONF"
sed -i '/^Hostname=/d' "$CONF"
sed -i '/^StartAgents=/d' "$CONF"

# Write active-only config
echo "Server=${PROXY_IP}" >> "$CONF"
echo "ServerActive=${PROXY_IP}" >> "$CONF"
echo "Hostname=${FULL_HOSTNAME}" >> "$CONF"
echo "StartAgents=0" >> "$CONF"

systemctl daemon-reload
systemctl enable "$SERVICE"
systemctl restart "$SERVICE"

sleep 2

if systemctl is-active --quiet "$SERVICE"; then
  echo "✅ Agent Ready (Active Mode)"
else
  echo "❌ Agent failed to start"
  exit 1
fi

tail -n 5 /var/log/zabbix/*agent*.log || true
