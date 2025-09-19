# Projet — Mise en place de la supervision **Zabbix** (Debian 12)

**Objectif :** déployer une plateforme Zabbix opérationnelle sur Debian 12 (MariaDB + Zabbix Server + Frontend Apache/PHP + Agent local), puis superviser deux hôtes (Linux & Windows) avec collecte des métriques essentielles (CPU, RAM, disques) et modèles (dont Apache).

---

## 1) Architecture & réseau

- Hyperviseur : VirtualBox
- Réseau : `intnet` (interne) + `NAT` (internet)
- Adresses choisies :  
  - **Zabbix Server (Debian 12)** : `192.168.100.10`  
  - **Hôte Linux** : `192.168.100.20`  
  - **Hôte Windows 10** : `192.168.100.15`  

### Flux et ports
- Frontend : `http://192.168.100.10/zabbix`
- MariaDB : base `zabbix` locale
- Zabbix Server ↔️ Agents :  
  - **passif** : agent écoute `10050/tcp` (le serveur interroge)  
  - **actif** : agent initie vers `10051/tcp` (le serveur reçoit)

---

## 2) Déploiement serveur (Debian 12)

> ⚠️ À exécuter *en root* sur la VM `192.168.100.10`

### Option A — **Script d’installation** (recommandé)
```bash
# utilisez le fichier fourni dans ./scripts/
chmod +x scripts/install_zabbix_server.sh
sudo ./scripts/install_zabbix_server.sh
```
Le script :
- installe Apache, PHP, MariaDB et les paquets Zabbix
- crée la base `zabbix`, l’utilisateur `zabbix` et importe le schéma
- configure `/etc/zabbix/zabbix_server.conf`
- active/démarre `zabbix-server`, `zabbix-agent` et `apache2`

### Option B — **Manuel** (extrait des commandes principales)
```bash
apt update && apt upgrade -y
apt install -y apache2 mariadb-server php php-mysql php-gd php-xml php-mbstring libapache2-mod-php unzip wget
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

mysql -uroot <<'SQL'
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'motdepasse_solide';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
SQL

zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p zabbix

sed -i 's/^# DBName=.*/DBName=zabbix/' /etc/zabbix/zabbix_server.conf
sed -i 's/^# DBUser=.*/DBUser=zabbix/' /etc/zabbix/zabbix_server.conf
sed -i 's/^# DBPassword=.*/DBPassword=motdepasse_solide/' /etc/zabbix/zabbix_server.conf

systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2
```

### Accès au frontend
- URL : `http://192.168.100.10/zabbix`
- Assistant d’install → renseigner la base (utilisateur `zabbix`), timezone `Europe/Paris`
- 1ère connexion : `Admin / zabbix` (à changer immédiatement)

---

## 3) Ajout d’un hôte **Linux** (192.168.100.20)

### Installation & configuration de l’agent
```bash
# sur l'hôte Linux
sudo apt update && sudo apt install -y zabbix-agent
sudo sed -i 's/^Server=.*/Server=192.168.100.10/' /etc/zabbix/zabbix_agentd.conf
sudo sed -i 's/^# ServerActive=.*/ServerActive=192.168.100.10/' /etc/zabbix/zabbix_agentd.conf
sudo sed -i 's/^Hostname=.*/Hostname=test-entretien/' /etc/zabbix/zabbix_agentd.conf
sudo systemctl restart zabbix-agent && sudo systemctl enable zabbix-agent
```

### Déclaration côté serveur
- Frontend → **Configuration → Hôtes → Créer**
  - Nom : `test-entretien`
  - Interface Agent : `192.168.100.20:10050`
  - Groupe : *Linux servers*
  - Template : **Linux by Zabbix agent**
- Contrôle : `zabbix_get -s 192.168.100.20 -k agent.ping` → `1`

---

## 4) Ajout d’un hôte **Windows 10** (192.168.100.15)

1. Télécharger l’agent Windows depuis zabbix.com  
2. Décompresser dans `C:\Program Files\Zabbix Agent\`  
3. Ouvrir un terminal **Admin** :
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
   - **NIC1** : NAT (internet)
   - **NIC2** : *intnet* statique → `192.168.100.15/24`

Déclarer l’hôte côté serveur (mêmes paramètres que pour Linux, IP `192.168.100.15`).

---

## 5) Import de **templates** (ex. Apache)

- Frontend → *Configuration → Collecte de données → Modèles → Importer*
- Sélectionner un `.xml` (officiel “Template App Apache by Zabbix agent”)
- Lier aux hôtes concernés (*onglet Modèles*).

---

## 6) Vérifications & Runbook rapide

- **Services** : `systemctl status zabbix-server zabbix-agent apache2`
- **DB** : `mysql -uroot -e "SHOW DATABASES LIKE 'zabbix';"`
- **Agent Linux** : `zabbix_get -s 192.168.100.20 -k system.hostname`
- **Web** : `curl -I http://192.168.100.10/zabbix` → 200
- **Dashboards** : *Monitoring → Latest data / Graphs*

---

## 7) Dépannage — cas réels rencontrés

- **Icône ZBX grisée (Linux)** : IP/port erronés, service agent arrêté → corriger conf + `systemctl restart zabbix-agent`, tester avec `zabbix_get`.
- **Zabbix Server ne démarre pas** : mot de passe DB incohérent → réaligner `/etc/zabbix/zabbix_server.conf` et la base (`ALTER USER ... IDENTIFIED BY ...`), puis `systemctl restart zabbix-server`.
- **Frontend “Access denied for user 'zabbix'@'localhost'”** : identifiants discordants → resynchroniser et relancer.
- **Windows non joignable** : NIC *intnet* manquante → ajouter NIC2 et IP statique `192.168.100.15`.

---

## 8) Automatisation (bonus)

- Script agent Linux : `./scripts/install_zabbix_agent_linux.sh 192.168.100.10 test-entretien`
- Mini playbook Ansible : `ansible-playbook -i ansible/hosts ansible/site.yml --ask-become-pass`

---

## 9) Schéma d’architecture (Mermaid)

Voir `./diagrams/architecture.mmd`. Vous pouvez le visualiser en ligne (Mermaid Live Editor) ou dans VSCode avec l’extension Mermaid.

---

**Auteur :** Projet ECF DevOps — Plateforme Zabbix sur Debian 12.  
**Licence :** MIT (documents et scripts de ce dépôt).
