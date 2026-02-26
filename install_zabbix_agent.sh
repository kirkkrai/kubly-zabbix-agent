#!/bin/bash

# ===== CONFIG =====
PROXY_IP="203.151.50.253"
CUSTOMER_CODE="$1"
HOST_SHORT="$2"
CONF_FILE="/etc/zabbix/zabbix_agentd.conf"

# ===== PRECHECK =====
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root or sudo."
    exit 1
fi

if [ -z "$CUSTOMER_CODE" ] || [ -z "$HOST_SHORT" ]; then
    echo "Usage: $0 <CUSTOMER_CODE> <HOST_SHORTNAME>"
    exit 1
fi

if [ ! -f "$CONF_FILE" ]; then
    echo "❌ Config file not found: $CONF_FILE"
    exit 1
fi

HOST_IP=$(hostname -I | awk '{print $1}')
FULL_HOSTNAME="${CUSTOMER_CODE}_${HOST_SHORT}_${HOST_IP}"

echo "===================================="
echo " Zabbix Agent Setup"
echo " Hostname : $FULL_HOSTNAME"
echo " Proxy    : $PROXY_IP"
echo "===================================="

# ===== BACKUP =====
BACKUP_FILE="${CONF_FILE}.bak_$(date +%F_%H%M%S)"
cp "$CONF_FILE" "$BACKUP_FILE"
echo "✔ Backup created: $BACKUP_FILE"

# ===== UPDATE FUNCTION =====
update_or_append() {
    KEY="$1"
    VALUE="$2"

    if grep -qE "^#?$KEY=" "$CONF_FILE"; then
        sed -i "s|^#\?$KEY=.*|$KEY=$VALUE|" "$CONF_FILE"
    else
        echo "$KEY=$VALUE" >> "$CONF_FILE"
    fi
}

update_or_append "Server" "$PROXY_IP"
update_or_append "ServerActive" "$PROXY_IP"
update_or_append "Hostname" "$FULL_HOSTNAME"

echo "✔ Configuration updated."

# ===== RESTART =====
systemctl daemon-reload
systemctl restart zabbix-agent

sleep 3

# ===== VERIFY =====
echo "---- Agent Test ----"
zabbix_agentd -t system.uptime

echo "---- Recent Log ----"
tail -n 5 /var/log/zabbix/zabbix_agentd.log

echo "===================================="
echo " DONE ✅"
echo "===================================="
