#!/bin/bash
set -e

ZABBIX_PROXY="203.151.50.235,203.151.50.253"
HOSTNAME=$(hostname)

echo "Installing Zabbix Agent 6.0 (Active via Proxy)..."

apt update -y
apt install -y wget gnupg

if [ ! -f /etc/apt/sources.list.d/zabbix.list ]; then
    wget -q https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-4+ubuntu24.04_all.deb
    dpkg -i zabbix-release_6.0-4+ubuntu24.04_all.deb
    rm -f zabbix-release_6.0-4+ubuntu24.04_all.deb
    apt update -y
fi

if ! dpkg -l | grep -q zabbix-agent; then
    apt install -y zabbix-agent
fi

cp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.bak.$(date +%F_%T)

sed -i "s/^#*Server=.*/Server=127.0.0.1/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^#*ServerActive=.*/ServerActive=${ZABBIX_PROXY}/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^#*Hostname=.*/Hostname=${HOSTNAME}/" /etc/zabbix/zabbix_agentd.conf

systemctl enable zabbix-agent
systemctl restart zabbix-agent

echo "Done."
