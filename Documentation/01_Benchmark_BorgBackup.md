# Benchmark des Outils de Sauvegarde et Haute Disponibilite
## NVTech | Mediaschool IRIS Nice | RP06 — PRA/PCA

**Auteur:** Nedjmeddine Belloum — BTS SIO SISR  
**Date:** 2025-2026  
**Etablissement:** MEDIASCHOOL / IRIS Nice  

---

## 1. Comparaison des Outils de Sauvegarde

| Critere | BorgBackup | Restic | Duplicati | rsync |
|---|---|---|---|---|
| Deduplication | ✅ Bloc | ✅ Bloc | ⚠️ Partielle | ❌ Non |
| Chiffrement | ✅ AES-256 | ✅ AES-256 | ✅ AES-256 | ❌ Non natif |
| Compression | ✅ lz4/zstd/zlib | ✅ zstd | ✅ Oui | ❌ Non |
| Retention granulaire | ✅ Borgmatic | ⚠️ Manuel | ✅ GUI | ❌ Non |
| Support LAN/WAN | ✅ SSH natif | ✅ Multi-backend | ✅ Cloud/LAN | ✅ SSH |
| Documentation | ✅ Excellente | ✅ Bonne | ✅ GUI complete | ✅ Standard |
| Score global /10 | **9/10 ✅ CHOIX** | 8/10 | 6/10 | 5/10 |

### Justification BorgBackup
- **Deduplication chunk-level** : reduction de 60-80% de l'espace disque
- **Chiffrement AES-256** : securite des donnees en transit et au repos
- **Borgmatic** : wrapper YAML pour automatisation complete (cron, retention, hooks)
- **Strategie 3-2-1-0-0** : parfaitement supportee nativement
- **Eprouve en production** : standard industrie pour backup Linux

---

## 2. Comparaison Solutions Haute Disponibilite (Replication)

| Critere | DRBD | GlusterFS | Ceph |
|---|---|---|---|
| Type | Replication bloc | FS distribue | Object/bloc/FS |
| RPO | 0 (Protocol C sync) | ~0 (async possible) | 0 (sync) |
| Overhead | ✅ Tres faible | ⚠️ Moyen | ❌ Eleve |
| Complexite | ✅ Faible (2 noeuds) | ⚠️ Moyenne | ❌ Elevee |
| Cas d'usage | Paire HA VMs | Scale-out NFS | Cloud/gros clusters |
| Score /10 | **9/10 ✅ CHOIX** | 7/10 | 7/10 (overkill) |

### Justification DRBD
- **Protocol C (synchrone)** : aucune perte de donnees (RPO=0)
- **Overhead minimal** : adapte a une infrastructure VM/VirtualBox
- **Integration kernel** : performance maximale
- **Paire de noeuds** : parfait pour l'architecture SRV_MAIN + SRV_BACKUP
- **Commandes simples** : `drbdadm primary/secondary`, `drbdadm status`

---

## 3. Comparaison Solutions Failover IP

| Critere | Keepalived/VRRP | Pacemaker+Corosync | HAProxy seul |
|---|---|---|---|
| RTO | < 30 secondes | < 60 secondes | N/A (load balancing) |
| Complexite | ✅ Faible | ❌ Elevee | ⚠️ Moyenne |
| Failover IP | ✅ VIP automatique | ✅ VIP + ressources | ❌ Non |
| Scripts sante | ✅ vrrp_script | ✅ Agent ressources | N/A |
| Standard industrie | ✅ Tres repandu | ✅ Entreprise | ✅ Load balancing |
| Score /10 | **9/10 ✅ CHOIX** | 8/10 | 6/10 |

### Justification Keepalived
- **Protocole VRRP standard** (RFC 5798) : interoperabilite garantie
- **RTO < 30 secondes** : basculement rapide sans intervention humaine
- **Configuration simple** : un seul fichier YAML/conf
- **vrrp_script** : verification de sante des services Docker avant basculement

---

## 4. Justification des Choix Retenus

| Composant | Technologie | Justification |
|---|---|---|
| PRA — Sauvegarde | BorgBackup + Borgmatic | Deduplication + AES-256 + RPO<1h |
| PCA — Replication | DRBD Protocol C | RPO=0 + faible overhead |
| PCA — Failover | Keepalived/VRRP | RTO<30s + standard industrie |
| Supervision | Prometheus + Grafana | Open source + dashboards riches |
| Services | Docker Compose | Isolation + portabilite |

---

## 5. Strategie 3-2-1-0-0 Expliquee

La regle **3-2-1** est la reference industrie pour la sauvegarde. NVTech l'etend en **3-2-1-0-0** :

| Chiffre | Signification | Implementation RP06 |
|---|---|---|
| **3** | 3 copies des donnees | Production (SRV_MAIN) + Borg local + Borg distant |
| **2** | 2 supports differents | Disque OS + Disque DRBD dedie (/dev/sdb) |
| **1** | 1 copie hors site | Destination cloud (objectif futur S3/Backblaze) |
| **0** | 0 erreur lors des verifications | `borgmatic check` — consistency checks automatiques |
| **0** | 0 RPO pour le PCA | DRBD Protocol C — replication synchrone |

### Planning de retention Borgmatic
- **24 sauvegardes horaires** (24h glissantes)
- **7 sauvegardes quotidiennes** (semaine)
- **4 sauvegardes hebdomadaires** (mois)
- **6 sauvegardes mensuelles** (semestre)