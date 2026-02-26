#!/bin/bash

# ==========================================
# ZABBIX AGENT ACTIVE-ONLY INSTALL SCRIPT
# Hardened Production Version
# ==========================================

set -e

### ===== CONFIG =====
PROXY_IP="203.151.50.253"
CONF_FILE="/etc/zabbix/zabbix_agentd.conf"

CUSTOMER_CODE="$1"
HOST_SHORT="$2"

### ===== PRECHECK =====
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root or sudo."
    exit 1
fi

if [ -z "$CUSTOMER_CODE" ] || [ -z "$HOST_SHORT" ]; then
    echo "Usage: $0 <CUSTOMER_CODE> <HOST_SHORTNAME>"
    exit 1
fi

if ! systemctl list-unit-files | grep -q zabbix-agent; then
    echo "❌ Zabbix agent service not found. Please install first."
    exit 1
fi

if [ ! -f "$CONF_FILE" ]; then
    echo "❌ Config file not found: $CONF_FILE"
    exit 1
fi

### ===== BUILD HOSTNAME =====
HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(ip route get 1 | awk '{print $7;exit}')
fi

FULL_HOSTNAME="${CUSTOMER_CODE}_${HOST_SHORT}_${HOST_IP}"

echo "================================="
echo "Zabbix Active Agent Setup"
echo "Proxy      : $PROXY_IP"
echo "Hostname   : $FULL_HOSTNAME"
echo "================================="

### ===== BACKUP =====
BACKUP_FILE="${CONF_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONF_FILE" "$BACKUP_FILE"
echo "✔ Backup created: $BACKUP_FILE"

### ===== CLEAN DUPLICATE KEYS =====
sed -i '/^Server=/d' "$CONF_FILE"
sed -i '/^ServerActive=/d' "$CONF_FILE"
sed -i '/^Hostname=/d' "$CONF_FILE"

### ===== WRITE CONFIG =====
echo "Server=${PROXY_IP}" >> "$CONF_FILE"
echo "ServerActive=${PROXY_IP}" >> "$CONF_FILE"
echo "Hostname=${FULL_HOSTNAME}" >> "$CONF_FILE"

echo "✔ Configuration written"

### ===== RESTART SERVICE =====
systemctl daemon-reload
systemctl restart zabbix-agent || systemctl restart zabbix-agent2
sleep 3

if systemctl is-active --quiet zabbix-agent || systemctl is-active --quiet zabbix-agent2; then
    echo "✔ Zabbix agent restarted successfully"
else
    echo "❌ Failed to restart Zabbix agent"
    exit 1
fi

### ===== VERIFY =====
echo "---- Recent agent log ----"
tail -n 5 /var/log/zabbix/zabbix_agentd.log || true

echo "================================="
echo "✅ ACTIVE MODE READY"
echo "================================="
