#!/usr/bin/env bash
# Usage: sudo ./install_zabbix_agent_linux.sh <ZABBIX_SERVER_IP> <HOSTNAME>
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être exécuté en root (sudo)." >&2
  exit 1
fi

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <ZABBIX_SERVER_IP> <HOSTNAME>"
  exit 1
fi

SERVER_IP="$1"
HOSTNAME="$2"

echo "=== Installation de l'agent Zabbix ==="
apt update
apt install -y zabbix-agent

CONF="/etc/zabbix/zabbix_agentd.conf"
sed -i "s/^Server=.*/Server=${SERVER_IP}/" "$CONF"
if grep -q "^# ServerActive=" "$CONF"; then
  sed -i "s/^# ServerActive=.*/ServerActive=${SERVER_IP}/" "$CONF"
else
  sed -i "s/^ServerActive=.*/ServerActive=${SERVER_IP}/" "$CONF"
fi
sed -i "s/^Hostname=.*/Hostname=${HOSTNAME}/" "$CONF"

systemctl restart zabbix-agent
systemctl enable zabbix-agent

echo "✅ Agent installé. Test rapide : zabbix_get -s <IP_CLIENT> -k agent.ping (depuis le serveur)"
