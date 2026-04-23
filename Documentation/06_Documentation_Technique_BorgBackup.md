# Documentation Technique — BorgBackup, DRBD, Keepalived
## NVTech | Mediaschool IRIS Nice | RP06

**Auteur:** Nedjmeddine Belloum — BTS SIO SISR  
**Date:** 2025-2026  

---

## PARTIE 1 — BorgBackup

### Architecture
```
Client (SRV_MAIN)                  Serveur (SRV_BACKUP)
/home/vagrant                       
/etc                  --SSH--> borguser@192.168.50.20
/var/lib/docker/volumes          /srv/borg/mediaschool/
                                 (depot chiffre AES-256)
```

### Installation
```bash
# Sur SRV_MAIN (client)
apt-get install -y borgbackup borgmatic

# Sur SRV_BACKUP (serveur)
apt-get install -y borgbackup
useradd -m -s /bin/bash borguser
mkdir -p /srv/borg/mediaschool
chown -R borguser:borguser /srv/borg
```

### Initialisation du depot
```bash
# Sur SRV_MAIN — generer la cle SSH
ssh-keygen -t ed25519 -C 'borg-main' -f /root/.ssh/borg_key -N ''

# Copier la cle publique sur SRV_BACKUP
# Dans /home/borguser/.ssh/authorized_keys:
# command="borg serve --restrict-to-path /srv/borg/mediaschool",no-pty <cle_publique>

# Initialiser le depot (depuis SRV_MAIN)
BORG_PASSPHRASE='BorgIRIS2026!' \
  BORG_RSH='ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no' \
  borg init --encryption=repokey \
  borguser@192.168.50.20:/srv/borg/mediaschool
```

### Commandes Principales

```bash
# Creer une sauvegarde manuelle
borgmatic create --verbosity 1

# Lister les archives
borgmatic list
# ou directement:
BORG_PASSPHRASE='BorgIRIS2026!' borg list borguser@192.168.50.20:/srv/borg/mediaschool

# Afficher les infos d'une archive
borgmatic info

# Verifier la consistance du depot
borgmatic check

# Restaurer la derniere archive
borgmatic restore --archive latest

# Restaurer vers un repertoire specifique
borgmatic restore --archive latest --destination /restore-test

# Supprimer les archives selon la politique de retention
borgmatic prune --verbosity 1

# Tout en une commande (create + prune + check)
borgmatic --verbosity 1
```

### Configuration Borgmatic (config.yaml explique)
```yaml
location:
  source_directories:      # Repertoires a sauvegarder
    - /home/vagrant
    - /etc
    - /var/lib/docker/volumes
  repositories:            # Depot(s) de destination
    - borguser@192.168.50.20:/srv/borg/mediaschool

storage:
  encryption_passphrase: 'BorgIRIS2026!'  # Chiffrement AES-256
  compression: lz4                         # Compression rapide
  ssh_command: ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no
  archive_name_format: 'iris-{now:%Y-%m-%dT%H:%M:%S}'

retention:
  keep_hourly: 24    # 24 dernieres archives horaires
  keep_daily: 7      # 7 dernieres archives quotidiennes
  keep_weekly: 4     # 4 dernieres archives hebdomadaires
  keep_monthly: 6    # 6 dernieres archives mensuelles

consistency:
  checks:
    - name: repository  # Verifier l'integrite du depot
    - name: archives    # Verifier les archives
  check_last: 3         # Verifier les 3 dernieres archives

hooks:
  before_backup:
    - echo "=== Backup demarre $(date) ===" >> /var/log/borgmatic.log
  after_backup:
    - date +%s > /var/lib/node_exporter/textfile_collector/borg_last_backup.prom
  on_error:
    - echo "=== ERREUR backup $(date) ===" >> /var/log/borg-errors.log
```

### Cron Horaire
```bash
# Fichier: /etc/cron.d/borgmatic
0 * * * * root borgmatic --verbosity 0 2>> /var/log/borg-errors.log
```

---

## PARTIE 2 — DRBD

### Presentation
DRBD (Distributed Replicated Block Device) est un module kernel Linux qui recopie un volume bloc entre deux serveurs en temps reel.

- **Protocol C (synchrone):** l'ecriture n'est confirmee que lorsque les 2 noeuds ont ecrit
- **RPO = 0:** aucune perte de donnees possible
- **Niveau bloc:** transparent pour les systemes de fichiers

### Configuration (mediaschool.res)
```
resource mediaschool {
  protocol C;             # Synchrone = RPO=0
  device /dev/drbd1;      # Device DRBD cree
  disk /dev/sdb;          # Disque physique dedie
  meta-disk internal;     # Metadonnees sur le meme disque

  on srv-main {
    address 192.168.56.10:7789;   # Reseau de replication
  }
  on srv-backup {
    address 192.168.56.20:7789;
  }
}
```

### Commandes DRBD
```bash
# Initialisation (1 seule fois)
drbdadm create-md mediaschool
drbdadm up mediaschool
drbdadm primary --force mediaschool  # Sur MAIN uniquement

# Status
drbdadm status
# Etat ideal: Both: UpToDate/UpToDate

# Status detaille
drbdsetup status mediaschool --verbose

# Monitoring en temps reel
watch -n2 'cat /proc/drbd'

# Connecter/deconnecter
drbdadm connect mediaschool
drbdadm disconnect mediaschool

# Passer en primaire/secondaire manuellement
drbdadm primary mediaschool
drbdadm secondary mediaschool
```

### Verification de Synchronisation
```bash
cat /proc/drbd
# Exemple:
# version: 8.4.11 (api:1/proto:86-101)
#  0: cs:Connected ro:Primary/Secondary ds:UpToDate/UpToDate C r-----
#     ns:1048576 nr:0 dw:1048576 dr:0 al:8 bm:0 lo:0 pe:0 ua:0 ap:0 ep:1 wo:f oos:0
#
# cs: Connected    (connexion OK)
# ro: Primary/Secondary  (MAIN=Primary, BACKUP=Secondary)
# ds: UpToDate/UpToDate  (les 2 noeuds sont synchronises)
# oos: 0           (0 octets hors-sync)
```

### Resolution Split-Brain
```bash
# En cas de split-brain (les 2 noeuds pensent etre Primary):
# Sur le noeud a ABANDONNER (perdra ses donnees recentes):
drbdadm secondary mediaschool
drbdadm disconnect mediaschool
drbdadm -- --discard-my-data connect mediaschool

# Sur le noeud a CONSERVER:
drbdadm connect mediaschool
```

---

## PARTIE 3 — Keepalived / VRRP

### Architecture VRRP
```
VIP: 192.168.50.50

SRV_MAIN (MASTER, priorite 100)
  - Possede la VIP
  - Envoie advertisements VRRP toutes les secondes

SRV_BACKUP (BACKUP, priorite 90)
  - Surveille les advertisements
  - Si plus d'advertisement: devient MASTER, prend la VIP
```

### Configuration (SRV_MAIN - MASTER)
```
vrrp_script chk_services {
  script "/usr/local/bin/check_services.sh"  # Verification sante Docker
  interval 5     # Toutes les 5 secondes
  weight -20     # Reduire priorite si script echoue
}

vrrp_instance VI_1 {
  state MASTER
  interface enp0s8
  virtual_router_id 51
  priority 100           # Plus haute priorite = MASTER
  advert_int 1           # Advertisement toutes les 1s
  authentication {
    auth_type PASS
    auth_pass VRRP_IRIS_2026!
  }
  virtual_ipaddress {
    192.168.50.50/24     # L'IP virtuelle
  }
  track_script { chk_services }
}
```

### Commandes Keepalived
```bash
# Status
systemctl status keepalived

# Verifier qui possede la VIP
ip addr show enp0s8 | grep 192.168.50.50

# Logs temps reel
journalctl -u keepalived -f

# Test failover manuel
systemctl stop keepalived   # Sur MAIN: force basculement
systemctl start keepalived  # Sur MAIN: reprend MASTER (preemption)
```

### Test Manuel de Failover
```bash
# 1. Etat initial (SRV_MAIN est MASTER)
ip addr show enp0s8  # Sur SRV_MAIN: voir 192.168.50.50

# 2. Simuler la panne
systemctl stop keepalived  # Sur SRV_MAIN

# 3. Attendre 30 secondes

# 4. Verifier que BACKUP a pris le relai
ip addr show enp0s8  # Sur SRV_BACKUP: voir 192.168.50.50

# 5. Services toujours accessibles
curl http://192.168.50.50  # Doit repondre

# 6. Retour MAIN
systemctl start keepalived  # Sur SRV_MAIN
```

---

## Ports Ouverts (UFW)

| Port | Protocole | Service |
|---|---|---|
| 22 | TCP | SSH |
| 80 | TCP | HTTP Nextcloud |
| 389 | TCP | LDAP |
| 636 | TCP | LDAPS |
| 1812 | UDP | RADIUS Auth |
| 1813 | UDP | RADIUS Accounting |
| 7789 | TCP | DRBD Replication |
| 9100 | TCP | Node Exporter |
| 9443 | TCP | Portainer HTTPS |
| 51820 | UDP | WireGuard VPN |
| 51821 | TCP | WireGuard UI |