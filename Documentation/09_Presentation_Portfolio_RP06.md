# RP06 — PRA + PCA IRIS Nice | NVTech
## Présentation Portfolio — Nedjmeddine Belloum

---

## 🎯 En une phrase

> Déploiement d'une infrastructure complète de continuité et reprise d'activité : BorgBackup (RPO < 1h) + DRBD réplication synchrone (RPO = 0) + Keepalived failover automatique (RTO < 30 secondes).

---

## 📋 Contexte du projet

| | |
|---|---|
| **Client** | École IRIS Nice (~300 utilisateurs) |
| **Prestataire** | NVTech |
| **Équipe** | 1 personne — Nedjmeddine Belloum |
| **Durée** | 4 mois |
| **Cadre** | BTS SIO SISR Épreuve E5 — Suite du RP01 |
| **Référence** | IRIS-NICE-2026-RP06 |

**Problème résolu :** L'infrastructure IRIS Nice (RP01) n'avait aucune protection contre les sinistres. Une panne serveur ou un ransomware aurait provoqué une interruption de service de plusieurs heures, voire plusieurs jours, pour 300 utilisateurs dépendants des services numériques (Nextcloud, authentification 802.1X, GLPI).

---

## ⚡ PRA vs PCA — La distinction clé

| | PRA | PCA |
|---|---|---|
| **Signifie** | Plan de **Reprise** d'Activité | Plan de **Continuité** d'Activité |
| **Philosophie** | Réactif — on restaure après l'incident | Proactif — le service ne s'interrompt jamais |
| **Technologie** | BorgBackup / Borgmatic | DRBD + Keepalived/VRRP |
| **RTO** | 2 – 24 heures | **< 30 secondes** |
| **RPO** | **< 1 heure** | **0** (réplication synchrone) |
| **Service interrompu ?** | Oui, pendant le RTO | **Non — transparent** |
| **Cas d'usage** | Ransomware, catastrophe totale | Panne serveur, crash OS |

---

## 🏗️ Architecture déployée

```
                    ┌─────────────────────────────────────────────┐
                    │          VIP : 192.168.50.50 (VRRP)        │
                    │  → Adresse virtuelle qui migre automatique- │
                    │    ment entre MAIN et BACKUP               │
                    └────────────┬──────────────────┬────────────┘
                                 │                  │
              ┌──────────────────▼──┐  DRBD  ┌──────▼──────────────────┐
              │  SRV_MAIN           │◄══════►│  SRV_BACKUP             │
              │  192.168.50.10      │Protocol│  192.168.50.20           │
              │  192.168.56.10      │   C    │  192.168.56.20           │
              │  ─────────────────  │        │  ─────────────────────   │
              │  OpenLDAP           │        │  Keepalived BACKUP       │
              │  FreeRADIUS         │        │  BorgBackup serveur      │
              │  Nextcloud          │        │  Node Exporter           │
              │  WireGuard          │        │                          │
              │  ClamAV             │        │                          │
              │  BorgBackup client ─┼───────►│  borguser@192.168.50.20  │
              │  Keepalived MASTER  │        │                          │
              └─────────────────────┘        └──────────────────────────┘
                                                          │
                    ┌─────────────────────────────────────▼──────────────┐
                    │  SRV_MONITORING — 192.168.50.30                     │
                    │  Prometheus | Grafana | Alertmanager | Node Exporter │
                    └──────────────────────────────────────────────────────┘
```

---

## 🛡️ Couche PRA — BorgBackup / Borgmatic

### Principe
BorgBackup crée des archives **dédupliquées, chiffrées (AES-256), compressées (LZ4)** depuis SRV_MAIN vers SRV_BACKUP de manière automatique.

### Stratégie 3-2-1-0-0
- **3** copies des données
- **2** supports différents (disque OS + disque DRBD dédié)
- **1** copie hors site (prévu : cloud)
- **0** erreur lors des vérifications de cohérence
- **0** RPO pour le PCA (complément au PRA)

### Configuration de rétention
```
Horaire   : 24 dernières archives  → données perdues max = 1 heure
Quotidien : 7 jours
Hebdo     : 4 semaines
Mensuel   : 6 mois
```

### Commandes clés
```bash
# Sauvegarde manuelle
borgmatic create --verbosity 1

# Lister les archives
borgmatic list

# Restaurer depuis la dernière archive
borgmatic restore --archive latest

# Vérifier l'intégrité du dépôt
borgmatic check
```

---

## 🔄 Couche PCA — DRBD + Keepalived

### DRBD — Réplication synchrone Protocol C
```bash
# Vérifier l'état de la réplication
drbdadm status
# Résultat attendu : mediaschool role:Primary peer-node-id:1 connection:Connected
#                   disk:UpToDate peer-disk:UpToDate

# Voir les stats en temps réel
cat /proc/drbd
```

**Protocol C** = l'écriture n'est confirmée à l'application que lorsqu'elle est enregistrée sur les **deux nœuds**. Garantit RPO = 0 mais légère latence (~1ms sur réseau LAN).

### Keepalived — VRRP Failover
```
SRV_MAIN   : state MASTER  | priority 100 | interface enp0s8
SRV_BACKUP : state BACKUP  | priority 90  | interface enp0s8
VIP        : 192.168.50.50/24

Si MAIN tombe → BACKUP détecte absence heartbeat VRRP (< 5s)
             → BACKUP annonce gratuitous ARP pour 192.168.50.50
             → BACKUP devient MASTER, VIP migre
             → Tout le trafic arrive sur BACKUP → RTO < 30s
```

### Test de failover (procédure jury)
```bash
# Sur SRV_MAIN — simuler une panne :
sudo systemctl stop keepalived

# Sur SRV_BACKUP — vérifier la migration :
ip addr show enp0s8  # doit afficher 192.168.50.50

# Depuis le PC admin :
ping 192.168.50.50  # doit continuer à répondre

# Retour en production :
sudo systemctl start keepalived  # MAIN reprend MASTER (priorité 100 > 90)
```

---

## 📊 Supervision — Prometheus + Grafana + Alertmanager

### Métriques collectées
- **Node Exporter** sur les 3 VMs → CPU, RAM, disque, réseau
- **Prometheus** scrape toutes les 15 secondes → historisation
- **Grafana** → dashboards temps réel accessibles sur http://192.168.50.30:3000

### Alertes configurées (5 règles)
| Alerte | Condition | Sévérité |
|---|---|---|
| InstanceDown | VM inaccessible > 1 min | 🔴 Critical |
| VRRPFailover | Changement de MASTER détecté | 🟡 Warning |
| BackupTooOld | Dernière sauvegarde > 25h | 🟡 Warning |
| BackupDiskFull | Disque backup > 85% | 🟡 Warning |
| DRBDOutOfSync | Réplication hors synchronisation | 🔴 Critical |

---

## 🐳 Services Docker (SRV_MAIN)

| Service | URL d'accès | Identifiants |
|---|---|---|
| Nextcloud | http://192.168.50.50 | admin / NextcloudAdmin2026! |
| phpLDAPadmin | http://192.168.50.10:8080 | cn=admin,dc=iris,dc=local / adminpassword |
| WireGuard UI | http://192.168.50.10:51821 | WireGuard_IRIS_2026! |
| Portainer | https://192.168.50.10:9443 | admin (1er login) |
| Grafana | http://192.168.50.30:3000 | admin / Grafana_IRIS_2026! |
| Prometheus | http://192.168.50.30:9090 | — |
| Alertmanager | http://192.168.50.30:9093 | — |

---

## ✅ Résultats

| Indicateur | Valeur |
|---|---|
| RTO PCA (Keepalived) | **< 30 secondes** ✅ |
| RPO PCA (DRBD) | **0** ✅ |
| RPO PRA (BorgBackup) | **< 1 heure** ✅ |
| Rétention archives | **6 mois** ✅ |
| Services Docker déployés | **7/7** ✅ |
| VMs provisionnées automatiquement | **3/3** ✅ |
| Alertes Prometheus configurées | **5/5** ✅ |

---

## 🛠️ Technologies maîtrisées

```
BorgBackup / Borgmatic    DRBD Protocol C      Keepalived / VRRP
Docker / Compose          OpenLDAP             FreeRADIUS 802.1X
Nextcloud                 WireGuard (VPN)      ClamAV (antivirus)
Prometheus                Grafana              Alertmanager
Vagrant / VirtualBox      Ubuntu 22.04 LTS     Bash scripting
```

---

## 💡 Points techniques remarquables

**1. Deux niveaux de protection complémentaires**  
Le PRA protège contre les catastrophes (ransomware, erreur humaine) grâce aux archives historisées. Le PCA protège contre les pannes courantes grâce au basculement automatique. Les deux sont nécessaires.

**2. Disque DRBD séparé (sdb)**  
DRBD réplique un disque entier, jamais le disque OS. Le Vagrantfile crée automatiquement un disque VMDK de 10 Go (sdb) à l'initialisation de chaque VM.

**3. SSH avec restriction `borg serve`**  
La clé SSH du borgclient (SRV_MAIN) est autorisée sur SRV_BACKUP uniquement pour exécuter `borg serve --restrict-to-path /srv/borg/mediaschool` — impossible d'utiliser cette clé pour autre chose.

**4. Réseau DRBD dédié (192.168.56.x)**  
Le trafic de réplication DRBD passe par un réseau `virtualbox__intnet: "drbd-net"` séparé du VLAN Management — pour ne pas saturer le réseau principal avec la réplication.

---

## 📁 Livrables

- **Code source :** https://github.com/delcoco95/PRA-PCRA---backup-
- **Vagrantfile :** déploiement 3 VMs avec `vagrant up`
- **Scripts :** provision_main.sh, provision_backup.sh, provision_monitoring.sh
- **docker-compose.yml :** 7 services orchestrés
- **Documentation :** 8 fichiers Markdown complets
- **borgmatic/config.yaml :** stratégie de sauvegarde complète

---

## 🔗 Liens

- **GitHub :** https://github.com/delcoco95/PRA-PCRA---backup-
- **Portfolio :** https://delcoco95.github.io/portfolio-nedj/
- **Candidat :** Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL IRIS Nice — 2026
