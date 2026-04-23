# RP06 — PRA/PCA IRIS Nice | NVTech

![Tests](https://img.shields.io/badge/Tests-100%25%20passes-brightgreen)
![Infrastructure](https://img.shields.io/badge/Infrastructure-3%20VMs%20Vagrant-blue)
![PRA](https://img.shields.io/badge/PRA-BorgBackup%20RPO%3C1h-orange)
![PCA](https://img.shields.io/badge/PCA-DRBD%2BKeepalived%20RTO%3C30s-red)

**BTS SIO SISR — Epreuve E5 — MEDIASCHOOL / IRIS Nice — Session 2026**

---

## Description du Projet

Ce projet met en place une infrastructure complete de **continuite et reprise d'activite** pour l'ecole IRIS Nice, realisee par NVTech.

### PRA — Plan de Reprise d'Activite
> "Si tout plante, je restaure en quelques heures depuis les sauvegardes"
- Sauvegardes **automatiques horaires** avec BorgBackup/Borgmatic
- Strategie **3-2-1-0-0** : 3 copies, 2 supports, 1 hors site, 0 erreur, 0 RPO
- Chiffrement **AES-256** avec deduplication et compression LZ4
- **RPO < 1 heure** — **RTO 2–24 heures** selon scenario

### PCA — Plan de Continuite d'Activite
> "Si tout plante, ca bascule automatiquement en moins de 30 secondes"
- Replication **synchrone temps reel** avec DRBD (Protocol C)
- Basculement **automatique** avec Keepalived/VRRP
- **RPO = 0** (aucune perte de donnees) — **RTO < 30 secondes**

---

## Architecture

```
+-------------------------------------------------------------+
|                   VIP : 192.168.50.50 (VRRP)               |
|                                                             |
|  SRV_MAIN (192.168.50.10)    SRV_BACKUP (192.168.50.20)    |
|  +--------------------+      +--------------------+         |
|  | OpenLDAP           |<===> | OpenLDAP (replique)|         |
|  | FreeRADIUS         | DRBD | FreeRADIUS (standby|         |
|  | Nextcloud          |      | BorgBackup serveur |         |
|  | WireGuard          |      | Keepalived BACKUP  |         |
|  | ClamAV             |      +--------------------+         |
|  | BorgBackup client  |                                     |
|  | Keepalived MASTER  |      SRV_MONITORING (.50.30)        |
|  +--------------------+      +--------------------+         |
|                              | Prometheus          |         |
|                              | Grafana             |         |
|                              | Alertmanager        |         |
|                              +--------------------+         |
+-------------------------------------------------------------+
```

## Infrastructure

| Serveur | IP VLAN50 | IP DRBD | RAM | Role |
|---|---|---|---|---|
| SRV_MEDIASCHOOL_MAIN | 192.168.50.10 | 192.168.56.10 | 3 Go | Serveur principal (tous services) |
| SRV_MEDIASCHOOL_BACKUP | 192.168.50.20 | 192.168.56.20 | 3 Go | Standby HA + BorgBackup serveur |
| SRV_MONITORING | 192.168.50.30 | 192.168.56.30 | 2 Go | Prometheus + Grafana + Alertmanager |
| VIP VRRP | 192.168.50.50 | — | — | IP virtuelle (MASTER/BACKUP auto) |

## Technologies

| Technologie | Usage | Version |
|---|---|---|
| BorgBackup + Borgmatic | Sauvegarde PRA | 1.2+ |
| DRBD | Replication synchrone PCA | 9 |
| Keepalived/VRRP | Failover IP automatique PCA | 2.2+ |
| Docker + Compose | Orchestration services | 24+ |
| OpenLDAP | Annuaire LDAP | 1.5 |
| FreeRADIUS | 802.1X / RADIUS | 3.2 |
| Nextcloud | Partage fichiers | latest |
| WireGuard (wg-easy) | VPN | latest |
| ClamAV | Antivirus | 1.4 |
| Prometheus | Metriques | 2.54 |
| Grafana | Dashboards | latest |
| Alertmanager | Alertes | 0.27 |
| Vagrant + VirtualBox | Provisioning | latest |

## Deploiement

```bash
# Cloner le depot
git clone https://github.com/delcoco95/PRA-PCRA---backup-
cd PRA-PCRA---backup-

# Lancer les 3 VMs
vagrant up

# Ou VM par VM
vagrant up srv-main
vagrant up srv-backup
vagrant up srv-monitoring
```

## RTO/RPO — Comparatif

| Critere | PRA (BorgBackup) | PCA (DRBD+Keepalived) |
|---|---|---|
| RTO | 2–24 heures | **< 30 secondes** |
| RPO | **< 1 heure** | **0** |
| Mecanisme | Restauration archive | Basculement automatique |
| Interruption | Oui | Non (transparent) |
| Cas d'usage | Catastrophe totale, ransomware | Panne serveur, crash OS |

## Strategie 3-2-1-0-0

- **3** copies des donnees (production + Borg local + Borg distant)
- **2** supports differents (disque OS + disque DRBD dedie)
- **1** copie hors site (future: destination cloud S3/Backblaze)
- **0** erreur lors des verifications borgmatic (consistency checks)
- **0** RPO pour le PCA (replication synchrone DRBD)

## Structure du Depot

```
RP06/
├── Vagrantfile                  # Provisioning 3 VMs
├── docker-compose.yml           # Services Docker (MAIN)
├── scripts/
│   ├── provision_main.sh        # Provisioning SRV_MAIN
│   ├── provision_backup.sh      # Provisioning SRV_BACKUP
│   └── provision_monitoring.sh  # Provisioning SRV_MONITORING
├── freeradius/
│   ├── clients.conf             # Clients Cisco RADIUS
│   └── users                   # Utilisateurs 802.1X
├── borgmatic/
│   └── config.yaml              # Config sauvegarde
├── Documentation/
│   ├── 01_Benchmark_BorgBackup.md
│   ├── 02_Architecture_PRA_PCA.md
│   ├── 03_Plan_Reprise_Activite_PRA.md
│   ├── 04_PV_Tests_Validation.md
│   ├── 05_Procedure_Urgence.md
│   ├── 06_Documentation_Technique_BorgBackup.md
│   ├── 07_Annexe7_Fiche_E5.md
│   └── 08_Credentials_Access_RP06.md
├── configs-cisco/               # Configurations Cisco
├── schemas/                     # Schemas reseau
└── docs/                        # PDFs (futurs)
```

## Liens

- Portfolio: https://delcoco95.github.io/portfolio-nedj/
- Annexe 7 RP06: voir `Documentation/07_Annexe7_Fiche_E5.md`
- Acces/Credentials: voir `Documentation/08_Credentials_Access_RP06.md`

---
*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL IRIS Nice — 2025-2026*