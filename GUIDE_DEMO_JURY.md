# Guide de démonstration — RP06 PRA/PCRA BorgBackup
**Projet :** IRIS-NICE-2026-RP06 | **Auteur :** Nedj Belloum | **Date :** 18/03/2026

---

## Prérequis
- VirtualBox installé
- Vagrant installé
- 6 Go RAM disponibles (3 × 2 Go)
- Internet pour le premier `vagrant up` (téléchargement des boxes)

---

## ÉTAPE 1 — Démarrage des VMs (ordre important)

```
# Terminal 1 — SRV_BACKUP en premier (doit être UP avant borgmatic)
cd "C:\Users\nedjb\Documents\PROJET IT\- RP06 - PRA_PCRA_Backup - Nedj\SRV_BACKUP"
vagrant up

# Terminal 2 — SRV_MONITORING
cd "C:\Users\nedjb\Documents\PROJET IT\- RP06 - PRA_PCRA_Backup - Nedj\SRV_MONITORING"
vagrant up

# Terminal 3 — SRV_MEDIASCHOOL_COPY (en dernier)
cd "C:\Users\nedjb\Documents\PROJET IT\- RP06 - PRA_PCRA_Backup - Nedj\SRV_MEDIASCHOOL_COPY"
vagrant up
```

⏱ Durée approximative : 10-15 minutes (premier démarrage, téléchargement)

---

## ÉTAPE 2 — Initialisation BorgBackup (une seule fois)

```bash
# Sur SRV_MEDIASCHOOL_COPY
vagrant ssh  # depuis le dossier SRV_MEDIASCHOOL_COPY
sudo bash /home/vagrant/setup_borg.sh
```

Le script :
1. Copie la clé SSH publique sur SRV_BACKUP (mot de passe borguser : `BorgBackup2026!`)
2. Initialise le dépôt Borg avec chiffrement AES-256
3. Applique la restriction `command=borg serve` (sécurité)
4. Lance la première sauvegarde
5. Configure le cron horaire

---

## ÉTAPE 3 — Vérifications à montrer au jury

### 3.1 Services Docker sur SRV_MEDIASCHOOL_COPY
```bash
vagrant ssh  # dossier SRV_MEDIASCHOOL_COPY
docker compose ps
```
Résultat attendu : **11 containers UP** (openldap, phpldapadmin, freeradius, nextcloud-db, nextcloud-app, wg-easy, clamav...)

### 3.2 Test BorgBackup — lister les archives
```bash
export BORG_RSH="ssh -i /root/.ssh/borg_key"
export BORG_PASSPHRASE=$(cat /root/.borg_passphrase)
sudo -E borg list borguser@192.168.56.20:/srv/borg/mediaschool
```
Résultat attendu : liste des archives avec dates

### 3.3 Test de restauration (demo jury — scénario 3 : corruption)
```bash
# Simuler la suppression de fichiers critiques
mkdir -p /home/vagrant/donnees-critiques
echo "config-ldap" > /home/vagrant/donnees-critiques/config-ldap.txt
echo "etudiants-iris" > /home/vagrant/donnees-critiques/etudiants.txt
sudo borgmatic create  # créer une archive AVANT la suppression

# Simuler le sinistre
rm -rf /home/vagrant/donnees-critiques
ls /home/vagrant/donnees-critiques  # → "No such file or directory" ✓

# Restauration
mkdir -p /tmp/restauration && cd /tmp/restauration
sudo -E borg extract borguser@192.168.56.20:/srv/borg/mediaschool::latest home/vagrant/donnees-critiques
ls /tmp/restauration/home/vagrant/donnees-critiques/  # → fichiers restaurés ✓
```

### 3.4 Vérification intégrité du dépôt
```bash
sudo -E borgmatic check --verbosity 1
```
Résultat attendu : `no problems found`

### 3.5 Prometheus — 4 targets UP
**Navigateur :** http://192.168.56.30:9090/targets

Targets attendus (tous UP) :
| Target | Adresse | Rôle |
|--------|---------|------|
| prometheus | localhost:9090 | Prometheus lui-même |
| srv-monitoring | 192.168.56.30:9100 | Node Exporter SRV_MONITORING |
| srv-backup | 192.168.56.20:9100 | Node Exporter SRV_BACKUP |
| srv-mediaschool | 192.168.56.11:9100 | Node Exporter SRV_MEDIASCHOOL |

### 3.6 Grafana — Dashboard Node Exporter Full
**Navigateur :** http://192.168.56.30:3000  
Login : `admin` / `admin`  
Dashboard : importer ID **1860** (Node Exporter Full)

### 3.7 Test FreeRADIUS (802.1X)
```bash
# Sur SRV_MEDIASCHOOL_COPY
docker exec freeradius radtest nedj.belloum NVTech_Admin2026! 127.0.0.1 1812 RadiusTest_IRIS_2026!
```
Résultat attendu : `Access-Accept`

---

## ÉTAPE 4 — Simulation complète jury (scénario 1 : panne disque)

```
1. Arrêter SRV_MEDIASCHOOL_COPY : vagrant halt (dossier SRV_MEDIASCHOOL_COPY)
2. Montrer dans Prometheus : alerte InstanceDown déclenchée → FIRING
3. Recréer la VM : vagrant up
4. Restaurer les données : sudo borgmatic extract --archive latest --destination /
5. Vérifier les services : docker compose ps
```

---

## Accès rapide depuis le PC hôte

| Service | URL | Login |
|---------|-----|-------|
| phpLDAPadmin | http://192.168.56.11:8080 | cn=admin,dc=mediaschool,dc=local / NVTech_Admin2026! |
| Nextcloud | http://192.168.56.11:8081 | admin / NVTech_Admin2026! |
| WireGuard UI | http://192.168.56.11:51821 | (pas de login — interface directe) |
| Prometheus | http://192.168.56.30:9090 | — |
| Grafana | http://192.168.56.30:3000 | admin / admin |
| Alertmanager | http://192.168.56.30:9093 | — |

---

## Plan d'adressage réseau

| VM | IP Primaire (inter-VMs) | IP Secondaire (VLAN 50 Mgmt) |
|----|------------------------|------------------------------|
| SRV_MEDIASCHOOL_COPY | 192.168.56.11 | 192.168.50.11 |
| SRV_BACKUP | 192.168.56.20 | 192.168.50.20 |
| SRV_MONITORING | 192.168.56.30 | 192.168.50.30 |

---

## Questions jury anticipées

**Q1 : Pourquoi BorgBackup plutôt que rsync ou Bacula ?**
> BorgBackup combine déduplication + chiffrement AES-256 + compression en un seul outil léger. Rsync ne déduplique pas et ne chiffre pas nativement. Bacula est trop lourd pour une infrastructure PME.

**Q2 : Comment est-ce que la règle 3-2-1-0-0 est respectée ?**
> 3 copies : originaux + dépôt Borg + clé exportée. 2 supports : VM principale + VM backup. 1 hors-site : SRV_BACKUP représente le serveur du campus distant (simulé en maquette, réel en production). 0 erreur vérifiée par `borg check`. 0 tape nécessaire.

**Q3 : Que se passe-t-il si la passphrase est perdue ?**
> Les données sont inaccessibles — c'est le principe du chiffrement. C'est pourquoi la passphrase ET la clé exportée sont conservées hors-dépôt dans `/root/borg-key-backup.txt` et dans un coffre-fort (KeePass). Procédure documentée dans L-05.

**Q4 : Quel est le RPO réel ?**
> Maximum 1 heure (cron horaire `0 * * * *`). En cas de sinistre à 14h59, la dernière archive disponible date de 14h00 → perte maximale de 59 minutes de données.

**Q5 : Comment êtes-vous alerté en cas d'échec de sauvegarde ?**
> Deux mécanismes : hook `on_error` borgmatic écrit dans `/var/log/borg-errors.log`, ET Prometheus déclenche l'alerte `BackupTooOld` si aucune sauvegarde réussie depuis 25h → Alertmanager notifie l'administrateur.

**Q6 : Est-ce conforme RGPD ?**
> Oui : toutes les données personnelles des étudiants (OpenLDAP, Nextcloud) sont chiffrées avec AES-256 en transit et au repos. Durée de rétention définie (6 mois max). Accès restreint à borguser via clé SSH dédiée.
