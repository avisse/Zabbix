#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être exécuté en root (sudo)." >&2
  exit 1
fi

echo "=== [1/7] Mises à jour & prérequis ==="
apt update
DEBIAN_FRONTEND=noninteractive apt upgrade -y
apt install -y apache2 mariadb-server php php-mysql php-gd php-xml php-mbstring libapache2-mod-php unzip wget curl

echo "=== [2/7] Paquets Zabbix ==="
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

echo "=== [3/7] Sécurisation MariaDB minimale ==="
DB_PASS="${ZBX_DB_PASS:-}"
if [[ -z "${DB_PASS}" ]]; then
  read -s -p "Mot de passe à définir pour l'utilisateur SQL 'zabbix' : " DB_PASS
  echo
fi

echo "=== [4/7] Création base & utilisateur Zabbix ==="
mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
SQL

echo "=== [5/7] Import du schéma ==="
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p"${DB_PASS}" zabbix

echo "=== [6/7] Configuration zabbix_server.conf ==="
conf="/etc/zabbix/zabbix_server.conf"
sed -i 's/^# \?DBName=.*/DBName=zabbix/' "$conf"
sed -i 's/^# \?DBUser=.*/DBUser=zabbix/' "$conf"
if grep -q '^# \?DBPassword=' "$conf"; then
  sed -i "s/^# \?DBPassword=.*/DBPassword=${DB_PASS}/" "$conf"
elif grep -q '^DBPassword=' "$conf"; then
  sed -i "s/^DBPassword=.*/DBPassword=${DB_PASS}/" "$conf"
else
  echo "DBPassword=${DB_PASS}" >> "$conf"
fi

echo "=== [7/7] Démarrage & activation des services ==="
systemctl restart mariadb
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

echo
echo "✅ Installation terminée."
echo " - Frontend : http://<IP_SERVEUR>/zabbix (Admin / zabbix, à changer)"
echo " - Fichier de conf : /etc/zabbix/zabbix_server.conf"
echo " - DB : zabbix (utilisateur zabbix)"
