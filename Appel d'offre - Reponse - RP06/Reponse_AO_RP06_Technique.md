# Réponse Technique à l'Appel d'Offres
## RP06 — Conception et mise en place d'un PRA/PCA avec sauvegarde 3-2-1-0-0
### Référence : IRIS-NICE-2026-RP06

---

**Candidat :** Nedjmeddine Belloum — BTS SIO SISR  
**Établissement :** MEDIASCHOOL / IRIS Nice  
**Date de remise :** Mars 2026  
**Responsable technique client :** Yan Bourquard  

---

## 1. Compréhension du besoin

L'école IRIS Nice dispose d'un serveur physique unique hébergeant l'ensemble de son infrastructure informatique (VMs étudiants SISR, annuaire LDAP, supervision, partages de fichiers). En l'absence de toute sauvegarde ou plan de reprise, une panne entraînerait la perte définitive de plusieurs mois de travaux pratiques et l'arrêt complet de l'activité pédagogique.

Notre réponse couvre **deux axes complémentaires** :
- **PRA** (Plan de Reprise d'Activité) : sauvegardes automatiques chiffrées avec BorgBackup, définitions RPO/RTO, scénarios de sinistre et tests de restauration
- **PCA** (Plan de Continuité d'Activité) : réplication synchrone DRBD + basculement automatique Keepalived/VRRP — *au-delà des exigences minimales de l'AO*

---

## 2. Architecture déployée

### 2.1 Infrastructure — 3 VMs Vagrant/VirtualBox

| VM | IP Management (VLAN50) | IP Réplication (DRBD) | RAM | Rôle |
|----|------------------------|----------------------|-----|------|
| SRV_MEDIASCHOOL_MAIN | 192.168.50.10 | 192.168.56.10 | 3 Go | Serveur principal actif — tous services |
| SRV_BACKUP | 192.168.50.20 | 192.168.56.20 | 3 Go | Standby HA + dépôt BorgBackup |
| SRV_MONITORING | 192.168.50.30 | 192.168.56.30 | 2 Go | Prometheus + Grafana + Alertmanager |
| VIP VRRP | 192.168.50.50 | — | — | IP virtuelle (basculement automatique) |

### 2.2 Services Docker déployés sur SRV_MAIN (9 conteneurs)

| Service | Port | Rôle |
|---------|------|------|
| OpenLDAP | 389 | Annuaire LDAP (26 utilisateurs — mêmes comptes que AD RP01) |
| phpLDAPadmin | 8080 | Interface web administration LDAP |
| GLPI | 8090 | Gestion de parc informatique et helpdesk |
| Nextcloud | 80 | Partage de fichiers collaboratif |
| WireGuard (wg-easy) | 51820 | VPN administration distante |
| ClamAV | — | Antivirus daemon |
| Portainer | 9443 | Interface web Docker |
| MariaDB (glpi-db) | — | Base de données GLPI |
| MariaDB (nextcloud-db) | — | Base de données Nextcloud |

### 2.3 Stratégie 3-2-1-0-0 implémentée

| Règle | Implémentation |
|-------|---------------|
| **3 copies** | 1 originale (SRV_MAIN) + 1 archive BorgBackup + 1 DRBD (SRV_BACKUP) |
| **2 supports** | Disque OS SRV_MAIN + Disque dédié DRBD/BorgBackup sur SRV_BACKUP |
| **1 hors site** | SRV_BACKUP simule un campus Mediaschool distant (Paris/Lyon/Toulouse) |
| **0 erreur** | `borg check` automatique après chaque sauvegarde + alertes Prometheus |
| **0 RPO** | DRBD Protocol C — réplication synchrone — chaque écriture confirmée sur 2 nœuds |

---

## 3. Conformité aux exigences obligatoires

| Exigence AO | Statut | Livrable |
|-------------|--------|----------|
| (1) RPO/RTO documentés par service critique (AD, VMs, fichiers, supervision) | ✅ CONFORME | `03_Plan_Reprise_Activite_PRA.md` — Section 1 + Tableau RPO/RTO |
| (2) PRA avec 3 scénarios de sinistre pas-à-pas | ✅ CONFORME | `03_Plan_Reprise_Activite_PRA.md` — Scénarios 1 à 4 |
| (3) Test de restauration réalisé et documenté | ✅ CONFORME | `04_PV_Tests_Validation.md` — T-BORG-01 à T-BORG-06 |
| (4) PV de test signé par le responsable technique | ✅ CONFORME | `04_PV_Tests_Validation.md` — campagne du 25/04/2026 |
| (5) Procédure d'urgence en langage non technique | ✅ CONFORME | `05_Procedure_Urgence.md` |
| (6) Alertes d'échec dans la supervision | ✅ CONFORME | Alertmanager — 5 règles : InstanceDown, VRRPFailover, BackupTooOld, BackupDiskFull, DRBDOutOfSync |
| (7) Sauvegardes chiffrées AES-256 (RGPD données étudiants) | ✅ CONFORME | BorgBackup mode `repokey` — chiffrement AES-256 — passphrase classeur sécurisé |

---

## 4. Conformité aux exigences souhaitables

| Exigence souhaitable | Statut | Détail |
|---------------------|--------|--------|
| Simulation sinistre VM détruite puis restaurée | ✅ RÉALISÉE | `rm -rf` simulation → `borg extract` → restauration 100% en < 30s |
| Tableau de bord suivi des sauvegardes | ✅ RÉALISÉ | Dashboard Grafana — CPU/RAM/disque/réseau — Node Exporter ID 1860 |
| Procédure d'escalade si responsable absent | ✅ RÉALISÉE | `03_Plan_Reprise_Activite_PRA.md` — Section 5 — Contacts et escalade |
| Conformité RGPD (accès tracé, durée conservation) | ✅ CONFORME | BorgBackup : rétention 24h horaires / 7j quotidiens / 4 semaines / 6 mois |

---

## 5. Résultats des tests — Bilan (25/04/2026)

| Catégorie | Tests | ✅ OK | ⚠️ Partiel |
|-----------|-------|-------|-----------|
| Infrastructure | 6 | 6 | 0 |
| Docker / Services | 7 | 7 | 0 |
| LDAP | 2 | 2 | 0 |
| BorgBackup (PRA) | 6 | 6 | 0 |
| PCA (DRBD + Keepalived) | 6 | 5 | 1 |
| Supervision | 6 | 5 | 1 |
| **TOTAL** | **33** | **31** | **2** |

> Les 2 tests partiels (T-PCA-06, T-SUP-06) concernent la validation en conditions réelles des alertes automatiques — fonctionnalité configurée, non testée en production.

### Résultats PCA — au-delà des exigences AO

| Test | Résultat |
|------|---------|
| Basculement VRRP (Keepalived) | ✅ **< 6 secondes** (objectif AO : < 30s) |
| DRBD synchronisation | ✅ Primary/UpToDate ↔ Secondary/UpToDate |
| Failback automatique | ✅ Retour SRV_MAIN automatique à la restauration |
| RPO DRBD | ✅ **0** (réplication synchrone Protocol C) |

---

## 6. RPO / RTO par service critique

| Service | RPO | RTO (PRA) | RTO (PCA) | Scénario couvert |
|---------|-----|-----------|-----------|-----------------|
| VMs étudiants SISR (Docker) | < 1 heure (BorgBackup) | 2–4 heures | **< 6 secondes** | Panne serveur, corruption |
| Annuaire LDAP (OpenLDAP) | < 1 heure | 1–2 heures | **< 6 secondes** | Panne serveur |
| Partages de fichiers (Nextcloud) | < 1 heure | 1–2 heures | **< 6 secondes** | Panne serveur |
| Supervision (Prometheus/Grafana) | N/A | 30 minutes | Automatique | Panne SRV_MONITORING |
| Hyperviseur complet | < 1 heure | 4–24 heures | Non applicable | Sinistre majeur |

---

## 7. Technologies utilisées

| Outil | Version | Rôle | Licence |
|-------|---------|------|---------|
| BorgBackup + Borgmatic | 1.2+ | Sauvegarde dédupliquée chiffrée AES-256 | BSD — Gratuit |
| DRBD | 9 | Réplication synchrone bloc par bloc (Protocol C) | GPL — Gratuit |
| Keepalived/VRRP | 2.2+ | Failover IP automatique | GPL — Gratuit |
| Docker + Compose | 24+ | Orchestration 9 services | Apache 2.0 — Gratuit |
| OpenLDAP | 1.5 | Annuaire LDAP | OpenLDAP — Gratuit |
| GLPI | latest | Gestion de parc | GPL — Gratuit |
| Nextcloud | latest | Partage de fichiers | AGPL — Gratuit |
| Prometheus | 2.54.1 | Collecte métriques | Apache 2.0 — Gratuit |
| Grafana | latest | Dashboards et visualisation | AGPL — Gratuit |
| Alertmanager | 0.27.0 | 5 règles d'alerte | Apache 2.0 — Gratuit |
| WireGuard (wg-easy) | latest | VPN | MIT — Gratuit |
| ClamAV | 1.4.4 | Antivirus | GPL — Gratuit |
| Vagrant + VirtualBox | latest | Virtualisation et provisioning | MIT / GPL — Gratuit |

---

## 8. Livrables remis

| # | Livrable | Fichier | Exigence AO |
|---|---------|---------|------------|
| 1 | Benchmark BorgBackup vs Restic vs Duplicati | `Documentation/01_Benchmark_BorgBackup.md` | Complément technique |
| 2 | Architecture PRA + PCA | `Documentation/02_Architecture_PRA_PCA.md` | Complément technique |
| 3 | Plan de Reprise d'Activité complet (4 scénarios) | `Documentation/03_Plan_Reprise_Activite_PRA.md` | Livrables (1)(2)(3) |
| 4 | PV de Tests et Validation (33 tests) | `Documentation/04_PV_Tests_Validation.md` | Livrable (4) |
| 5 | Procédure d'urgence responsable technique | `Documentation/05_Procedure_Urgence.md` | Livrable (5) |
| 6 | Documentation technique BorgBackup + DRBD | `Documentation/06_Documentation_Technique_BorgBackup.md` | Livrable (6) |
| 7 | Annexe 7 BTS SIO E5 | `Documentation/Oral/07_Annexe7_Fiche_E5.md` | Épreuve E5 |
| 8 | Maquette fonctionnelle automatisée | `Vagrantfile` + `scripts/` + `docker-compose.yml` | Démonstration jury |
| 9 | Configurations Cisco | `configs-cisco/` | Complément |
| 10 | Scripts LDAP | `ldap/` | Complément |

---

## 9. Accès à la maquette

- **GitHub :** https://github.com/delcoco95/PRA-PCRA---backup-
- **Portfolio :** https://delcoco95.github.io/portfolio-nedj/
- **Démarrage :** `vagrant up` → provisioning automatique des 3 VMs
- **Grafana :** http://192.168.50.30:3000 — admin / Grafana_IRIS_2026!
- **Prometheus :** http://192.168.50.30:9090
- **Nextcloud :** http://192.168.50.10 — admin / NextcloudIRIS2026!
- **GLPI :** http://192.168.50.10:8090 — glpi / glpi

---

## 10. Normes et référentiels appliqués

| Norme | Application |
|-------|-------------|
| RGPD | Chiffrement AES-256 des sauvegardes, rétention définie, accès tracé |
| RFC 5798 | Virtual Router Redundancy Protocol (VRRP) v3 |
| Règle 3-2-1-0-0 | Stratégie de sauvegarde — 3 copies, 2 supports, 1 hors site |
| DRBD Protocol C | Réplication synchrone — RPO=0 garanti |
| ISO 22301 | Plan de Continuité d'Activité (référentiel de bonnes pratiques) |

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL / IRIS Nice — Session 2026*  
*Référence : IRIS-NICE-2026-RP06 | GitHub : https://github.com/delcoco95/PRA-PCRA---backup-*
