# ANNEXE 7-1-A — Fiche descriptive de réalisation professionnelle
## BTS Services informatiques aux organisations — SESSION 2026
## Épreuve E5 - Administration des systèmes et des réseaux (option SISR)

---

## RECTO — DESCRIPTION D'UNE RÉALISATION PROFESSIONNELLE

| | |
|---|---|
| **N° réalisation** | 2 |
| **Nom, prénom** | Belloum Nedjmeddine |
| **N° candidat** | *(à compléter)* |
| **Type d'épreuve** | Contrôle en cours de formation |
| **Date** | 18 / 03 / 2026 |

---

### Organisation support de la réalisation professionnelle

| | |
|---|---|
| **Intitulé de la réalisation professionnelle** | Conception et mise en place d'un PRA et d'un PCA avec BorgBackup, DRBD et Keepalived — Campus IRIS Nice |
| **Période de réalisation** | 09/03/2026 au 28/03/2026 |
| **Lieu** | Mediaschool – IRIS Nice |
| **Modalité** | Seul(e) |

---

### Compétences travaillées

- [x] Concevoir une solution d'infrastructure réseau
- [x] Installer, tester et déployer une solution d'infrastructure réseau
- [x] Exploiter, dépanner et superviser une solution d'infrastructure réseau

---

### Conditions de réalisation

**Ressources :**
- Appel d'offre IRIS-NICE-2026-RP06 fourni par Yan Bourquard (Responsable Technique)
- Infrastructure de référence : serveur physique hébergeant des VMs sous VirtualBox
- Environnement de test : 3 VMs Vagrant/VirtualBox sur poste de développement
- Accès Internet pour téléchargement des outils open source (BorgBackup, DRBD, Prometheus…)

**Résultats attendus :**
- Stratégie de sauvegarde 3-2-1-0-0 implémentée avec BorgBackup/Borgmatic — RPO < 1 heure
- Réplication synchrone des données en temps réel avec DRBD Protocol C — RPO = 0
- Basculement automatique Keepalived/VRRP en cas de panne — RTO < 30 secondes
- Plan de Reprise d'Activité (PRA) couvrant 4 scénarios de sinistre (dont PCA)
- Tests de restauration et de failover réalisés et documentés
- Alertes d'échec intégrées dans Prometheus/Alertmanager
- Procédure d'urgence utilisable par le responsable technique seul

---

### Description des ressources documentaires, matérielles et logicielles utilisées

**Ressources documentaires :**
- Documentation officielle BorgBackup : https://borgbackup.readthedocs.io
- Documentation Borgmatic : https://torsion.org/borgmatic/
- Documentation DRBD (Linbit) — protocoles de réplication et gestion split-brain
- RFC 5798 — Virtual Router Redundancy Protocol (VRRP) Version 3
- Documentation Prometheus / Grafana / Alertmanager
- Appel d'offre IRIS-NICE-2026-RP06

**Matérielles et logicielles utilisées :**
- VirtualBox + Vagrant — virtualisation et provisioning automatisé des 3 VMs
- Ubuntu 22.04 LTS (Jammy) — système des 3 VMs
- BorgBackup 1.2 + Borgmatic — sauvegarde dédupliquée chiffrée AES-256
- DRBD 9 (drbd-utils) — réplication synchrone bloc par bloc (Protocol C)
- Keepalived 2.2 — gestion VRRP, IP virtuelle 192.168.50.50
- Docker + Docker Compose — orchestration 7 services (OpenLDAP, FreeRADIUS, Nextcloud, WireGuard, ClamAV, phpLDAPadmin, Portainer)
- Prometheus v2.54.1 + Node Exporter v1.8.1 — supervision métriques
- Grafana — dashboards et visualisation
- Alertmanager v0.27.0 — gestion des alertes (5 règles)

---

### Modalités d'accès aux productions et à leur documentation

- **GitHub :** https://github.com/delcoco95/PRA-PCRA---backup-
- **Portfolio :** https://delcoco95.github.io/portfolio-nedj/
- **Maquette démontrable :** `vagrant up` → provisioning automatique des 3 VMs

---

## VERSO — Descriptif de la réalisation professionnelle

---

**Objectif :**

Conception et déploiement d'une stratégie complète de continuité et reprise d'activité pour l'école IRIS Nice (campus Mediaschool). Le projet couvre deux axes complémentaires : le PRA (Plan de Reprise d'Activité) avec BorgBackup pour les sauvegardes automatiques chiffrées, et le PCA (Plan de Continuité d'Activité) avec DRBD + Keepalived pour le basculement automatique sans interruption de service.

---

**Ce qui a été réalisé :**

**1. Déploiement de 3 VMs Vagrant provisionnées automatiquement :**
- SRV_MEDIASCHOOL_MAIN (192.168.50.10 / 192.168.56.10) : serveur principal actif — OpenLDAP, FreeRADIUS, Nextcloud, WireGuard, ClamAV, BorgBackup client, Keepalived MASTER
- SRV_MEDIASCHOOL_BACKUP (192.168.50.20 / 192.168.56.20) : serveur secondaire standby — BorgBackup serveur (borguser), Keepalived BACKUP, Node Exporter
- SRV_MONITORING (192.168.50.30 / 192.168.56.30) : supervision — Prometheus, Grafana, Alertmanager, Node Exporter
- Réseau dédié DRBD : `virtualbox__intnet: "drbd-net"` sur 192.168.56.0/24 (séparé du VLAN Management)
- Chaque VM provisionnée par un script bash dédié (provision_main.sh, provision_backup.sh, provision_monitoring.sh)

**2. Couche PCA — Haute Disponibilité (DRBD + Keepalived) :**
- DRBD Protocol C sur disque secondaire dédié (sdb — 10 Go) : réplication synchrone bloc par bloc entre MAIN (192.168.56.10:7789) et BACKUP (192.168.56.20:7789) — chaque écriture confirmée sur les 2 nœuds avant validation → RPO = 0
- Keepalived/VRRP : IP virtuelle 192.168.50.50 (virtual_router_id 51) — MAIN priorité 100 (MASTER), BACKUP priorité 90 — détection panne < 5 secondes, migration automatique VIP → RTO < 30 secondes
- Script health check toutes les 5s : vérifie FreeRADIUS et OpenLDAP — déclenche failover si KO
- Test de basculement : `systemctl stop keepalived` sur MAIN → VIP migre sur BACKUP → services accessibles sans interruption

**3. Couche PRA — Sauvegarde BorgBackup/Borgmatic :**
- Échange de clés SSH ed25519 avec restriction `command="borg serve --restrict-to-path /srv/borg/mediaschool"` (sécurité maximale)
- Initialisation dépôt chiffré AES-256 (mode repokey) — passphrase BorgIRIS2026!
- Configuration Borgmatic YAML : rétention 24h horaires / 7j quotidiens / 4 semaines / 6 mois
- Automatisation cron toutes les heures — stratégie 3-2-1-0-0 respectée
- Test de restauration réalisé : rm -rf simulation → restauration 100% en < 30 secondes

**4. Supervision centralisée — Prometheus + Grafana + Alertmanager :**
- Node Exporter déployé sur les 3 VMs (port 9100 sur réseau 192.168.56.x)
- Prometheus scrape 4 targets toutes les 15 secondes
- Grafana accessible sur http://192.168.50.30:3000 — dashboards CPU/RAM/réseau/disque
- 5 règles d'alerte : InstanceDown (critique), VRRPFailover (warning), BackupTooOld > 25h (warning), BackupDiskFull > 85% (warning), DRBDOutOfSync (critique)

**5. Documentation complète livrée :**
- 01 — Benchmark BorgBackup vs Restic vs Duplicati + comparaison DRBD / GlusterFS / Ceph
- 02 — Architecture PRA + PCA (schéma 3 VMs, flux DRBD, flux VRRP, flux BorgBackup)
- 03 — Plan de Reprise d'Activité (4 scénarios dont Scénario 4 : basculement PCA automatique)
- 04 — PV de Tests et Validation (tests PCA T-PCA-01 à T-PCA-06, tests PRA T-PRA-01 à T-PRA-04)
- 05 — Procédure d'urgence (Situation 0 : basculement automatique PCA — rien à faire)
- 06 — Documentation technique BorgBackup + DRBD + Keepalived

---

**Compétences mobilisées :**
- Administration Linux Ubuntu 22.04 : systemd, UFW, SSH ed25519, gestion de services
- Virtualisation et automatisation : Vagrant, VirtualBox, provisioning bash (3 scripts)
- Haute disponibilité Linux : DRBD Protocol C, Keepalived/VRRP, gestion split-brain
- Sauvegarde et restauration : BorgBackup, Borgmatic, chiffrement AES-256, stratégie 3-2-1-0-0
- Supervision : Prometheus, Grafana, Alertmanager, Node Exporter, règles d'alerte
- Docker + Docker Compose : 7 services (OpenLDAP, FreeRADIUS, Nextcloud, WireGuard, ClamAV…)
- Documentation technique professionnelle : PRA, PV de tests, procédures d'urgence, benchmarks

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL / IRIS Nice — Session 2026*