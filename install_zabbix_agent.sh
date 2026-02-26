#!/bin/bash

PROXY_IP="203.151.50.253"
CUSTOMER_CODE="$1"
HOST_SHORT="$2"
HOST_IP=$(hostname -I | awk '{print $1}')
CONF_FILE="/etc/zabbix/zabbix_agentd.conf"

if [ -z "$CUSTOMER_CODE" ] || [ -z "$HOST_SHORT" ]; then
    echo "Usage: $0 <CUSTOMER_CODE> <HOST_SHORTNAME>"
    exit 1
fi

FULL_HOSTNAME="${CUSTOMER_CODE}_${HOST_SHORT}_${HOST_IP}"

echo "==== Zabbix Agent Setup ===="
echo "Hostname: $FULL_HOSTNAME"
echo "Proxy: $PROXY_IP"
echo "============================"

cp $CONF_FILE ${CONF_FILE}.bak_$(date +%F_%T)

sed -i "s/^Server=.*/Server=${PROXY_IP}/" $CONF_FILE
sed -i "s/^ServerActive=.*/ServerActive=${PROXY_IP}/" $CONF_FILE
sed -i "s/^Hostname=.*/Hostname=${FULL_HOSTNAME}/" $CONF_FILE

systemctl restart zabbix-agent
sleep 3

zabbix_agentd -t system.uptime
echo "---- LOG ----"
tail -n 5 /var/log/zabbix/zabbix_agentd.log

echo "DONE."
