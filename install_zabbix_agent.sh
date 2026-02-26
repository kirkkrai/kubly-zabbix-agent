#!/bin/bash

# ===============================
# ZABBIX AGENT ACTIVE-ONLY INSTALL SCRIPT
# Production version
# ===============================

set -e

### ==== CONFIG SECTION ====
PROXY_IP="203.151.50.253"
CONF_FILE="/etc/zabbix/zabbix_agentd.conf"

CUSTOMER_CODE="$1"
HOST_SHORT="$2"

### ==== PRECHECK ====
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root or sudo."
    exit 1
fi

if [ -z "$CUSTOMER_CODE" ] || [ -z "$HOST_SHORT" ]; then
    echo "Usage: $0 <CUSTOMER_CODE> <HOST_SHORTNAME>"
    exit 1
fi

if [ ! -f "$CONF_FILE" ]; then
    echo "❌ Zabbix agent config not found at $CONF_FILE"
    exit 1
fi

### ==== BUILD HOSTNAME ====
HOST_IP=$(hostname -I | awk '{print $1}')
FULL_HOSTNAME="${CUSTOMER_CODE}_${HOST_SHORT}_${HOST_IP}"

echo "================================="
echo "Zabbix Agent Configuration"
echo "Proxy IP     : $PROXY_IP"
echo "Hostname     : $FULL_HOSTNAME"
echo "================================="

### ==== BACKUP CONFIG ====
BACKUP_FILE="${CONF_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONF_FILE" "$BACKUP_FILE"
echo "✔ Backup created: $BACKUP_FILE"

### ==== SAFE UPDATE FUNCTION ====
update_or_append() {
    KEY="$1"
    VALUE="$2"

    if grep -qE "^${KEY}=" "$CONF_FILE"; then
        sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|g" "$CONF_FILE"
    else
        echo "${KEY}=${VALUE}" >> "$CONF_FILE"
    fi
}

### ==== FORCE ACTIVE-ONLY MODE ====
update_or_append "Server" "$PROXY_IP"
update_or_append "ServerActive" "$PROXY_IP"
update_or_append "Hostname" "$FULL_HOSTNAME"

# ปิด passive ถ้าต้องการ (optional)
# update_or_append "StartAgents" "0"

echo "✔ Configuration updated"

### ==== RESTART SERVICE ====
systemctl daemon-reload
systemctl restart zabbix-agent
sleep 3

if systemctl is-active --quiet zabbix-agent; then
    echo "✔ Zabbix agent restarted successfully"
else
    echo "❌ Zabbix agent failed to restart"
    exit 1
fi

### ==== VERIFY ====
echo "---- Testing active connection ----"
tail -n 5 /var/log/zabbix/zabbix_agentd.log

echo "================================="
echo "✅ DONE"
echo "================================="
