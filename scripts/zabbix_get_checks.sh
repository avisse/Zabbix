#!/usr/bin/env bash
# Usage: ./zabbix_get_checks.sh <TARGET_IP>
set -euo pipefail

if ! command -v zabbix_get >/dev/null 2>&1; then
  echo "zabbix_get n'est pas installé. Sur le serveur : sudo apt install -y zabbix-get"
  exit 1
fi

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <TARGET_IP>"
  exit 1
fi

echo "== Tests zabbix_get sur $TARGET =="
for key in agent.ping system.hostname system.cpu.util vfs.fs.size[/,free] vfs.fs.size[/,total]; do
  echo -n "$key => "
  zabbix_get -s "$TARGET" -k "$key" || true
done
