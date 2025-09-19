# Vérifications & Runbook

## Sanity checks
```bash
systemctl status zabbix-server zabbix-agent apache2
mysql -uroot -e "SHOW DATABASES LIKE 'zabbix';"
curl -I http://192.168.100.10/zabbix
```

## Tests agent Linux depuis le serveur
```bash
apt install -y zabbix-get
zabbix_get -s 192.168.100.20 -k agent.ping          # 1
zabbix_get -s 192.168.100.20 -k system.hostname
zabbix_get -s 192.168.100.20 -k vfs.fs.size[/,free]
```

## Dépannage rapide
- ZBX gris : vérifier IP/port, `systemctl status zabbix-agent`, logs `/var/log/zabbix/zabbix_agentd.log`.
- DB refusée : réaligner mot de passe dans `/etc/zabbix/zabbix_server.conf` et MariaDB.
- Windows muet : vérifier 2ème NIC *intnet* + règle pare-feu TCP/10050.
