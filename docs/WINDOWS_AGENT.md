# Installation agent **Zabbix** — Windows 10

1. Télécharger l’agent sur https://www.zabbix.com/download_agents
2. Décompresser dans `C:\Program Files\Zabbix Agent\`
3. Ouvrir **PowerShell en Administrateur** et exécuter :
   ```powershell
   cd "C:\Program Files\Zabbix Agent"
   .\zabbix_agentd.exe --config zabbix_agentd.conf --install
   ```
4. Éditer `zabbix_agentd.conf` :
   ```
   Server=192.168.100.10
   ServerActive=192.168.100.10
   Hostname=WIN10-DIGDASH
   ```
5. Pare-feu :
   ```powershell
   netsh advfirewall firewall add rule name="Zabbix Agent" dir=in action=allow protocol=TCP localport=10050
   net start "Zabbix Agent"
   ```
6. Réseau VirtualBox :  
   - NIC1 : NAT (internet)  
   - NIC2 : *intnet* statique `192.168.100.15/24`
