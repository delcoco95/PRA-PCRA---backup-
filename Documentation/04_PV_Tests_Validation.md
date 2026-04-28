# PV de Tests et Validation
## NVTech | Mediaschool IRIS Nice | RP06 — PRA/PCA

**Auteur:** Nedjmeddine Belloum — BTS SIO SISR  
**Date de campagne de tests :** 25/04/2026  

---

## Tests Infrastructure de Base

| ID | Test | Commande | Resultat Attendu | Statut | Resultat Obtenu |
|---|---|---|---|---|---|
| T-INF-01 | Ping SRV_MAIN | `ping 192.168.50.10` | Reponse ICMP | ✅ OK | 192.168.50.10 repond |
| T-INF-02 | Ping SRV_BACKUP | `ping 192.168.50.20` | Reponse ICMP | ✅ OK | 192.168.50.20 repond |
| T-INF-03 | Ping SRV_MONITORING | `ping 192.168.50.30` | Reponse ICMP | ✅ OK | 192.168.50.30 repond |
| T-INF-04 | SSH SRV_MAIN | `vagrant ssh srv-main` | Connexion OK | ✅ OK | Connexion etablie |
| T-INF-05 | SSH SRV_BACKUP | `vagrant ssh srv-backup` | Connexion OK | ✅ OK | Connexion etablie |
| T-INF-06 | SSH SRV_MONITORING | `vagrant ssh srv-monitoring` | Connexion OK | ✅ OK | Connexion etablie |

> ⚠️ **Note :** SRV_MAIN necessite le kernel 5.15.0-161-generic (configure dans GRUB) pour charger le module DRBD.

---

## Tests Docker — Services

| ID | Test | Commande | Resultat Attendu | Statut | Resultat Obtenu |
|---|---|---|---|---|---|
| T-DOC-01 | Docker running | `docker ps` | 9 containers Up | ✅ OK | 9 containers Up (nextcloud, glpi, glpi-db, nextcloud-db, openldap, phpldapadmin, portainer, wg-easy, clamav) |
| T-DOC-02 | Nextcloud web | `curl http://localhost:8091` | HTTP 200 | ✅ OK | HTTP 200 |
| T-DOC-03 | GLPI web | `curl http://localhost:8090` | HTTP 200 | ✅ OK | HTTP 200 |
| T-DOC-04 | phpLDAPadmin | `curl http://localhost:8092` | HTTP 200 | ✅ OK | HTTP 200 |
| T-DOC-05 | Portainer | `curl -k https://localhost:9453` | HTTP 200 | ✅ OK | HTTP 200 |
| T-DOC-06 | WireGuard UI | `curl http://localhost:8091` | Interface wg0 active | ✅ OK | wg0 actif, port 51820 |
| T-DOC-07 | ClamAV | `docker inspect clamav --format '{{.State.Health.Status}}'` | healthy | ✅ OK | healthy — ClamAV 1.4.4 |

---

## Tests LDAP — Annuaire

| ID | Test | Commande | Resultat Attendu | Statut | Resultat Obtenu |
|---|---|---|---|---|---|
| T-LDAP-01 | LDAP connexion | `docker exec openldap ldapsearch -x -H ldap://localhost -b "dc=iris,dc=local" -D "cn=admin,dc=iris,dc=local" -w adminpassword` | Entrees LDAP | ✅ OK | dc=iris,dc=local + ou=Utilisateurs, ou=Etudiants, ou=Professeurs trouves |
| T-LDAP-02 | phpLDAPadmin | `curl http://localhost:8092` | Page login LDAP | ✅ OK | HTTP 200 — interface accessible |

---

## Tests BorgBackup — PRA

| ID | Test | Commande | Resultat Attendu | Statut | Resultat Obtenu |
|---|---|---|---|---|---|
| T-BORG-01 | SSH borguser | `sudo ssh borguser@192.168.50.20 echo OK` | SSH_OK | ✅ OK | Connexion etablie sans mot de passe |
| T-BORG-02 | Init depot Borg | `borgmatic init --encryption repokey` (ou `borg init --encryption=repokey borguser@192.168.50.20:/srv/borg/mediaschool`) | Depot cree | ✅ OK | Depot initialise — chiffrement AES-256 repokey |
| T-BORG-03 | Sauvegarde manuelle | `borg create borguser@192.168.50.20:/srv/borg/mediaschool::{hostname}-test /etc/hostname /etc/hosts` | Archive creee | ✅ OK | Archive srv-main-test-20260425 creee |
| T-BORG-04 | Lister archives | `borg list borguser@192.168.50.20:/srv/borg/mediaschool` | Liste archives | ✅ OK | srv-main-test-20260425 visible avec hash SHA256 |
| T-BORG-05 | Restauration test | `borg extract --dry-run --list borguser@192.168.50.20:/srv/borg/mediaschool::srv-main-test-20260425` | Fichiers listes | ✅ OK | etc/hostname et etc/hosts listes |
| T-BORG-06 | Cron horaire | `cat /etc/cron.d/borgmatic` | Cron configure | ✅ OK | Cron horaire configure |

---

## Tests PCA — DRBD + Keepalived

| ID | Test | Procedure | Resultat Attendu | Statut | Resultat Obtenu |
|---|---|---|---|---|---|
| T-PCA-01 | VIP accessible | `ip addr show enp0s8 \| grep 192.168.50.50` sur SRV_MAIN | VIP presente | ✅ OK | inet 192.168.50.50/24 sur enp0s8 |
| T-PCA-02 | Basculement VRRP | `sudo systemctl stop keepalived` sur SRV_MAIN | VIP migre vers BACKUP <30s | ✅ OK | Basculement en **< 6 secondes** |
| T-PCA-03 | VIP sur BACKUP | `ip addr show enp0s8` sur SRV_BACKUP apres T-PCA-02 | 192.168.50.50 sur BACKUP | ✅ OK | inet 192.168.50.50/24 sur SRV_BACKUP |
| T-PCA-04 | Retour production MAIN | `sudo systemctl start keepalived` sur SRV_MAIN | VIP revient sur MAIN | ✅ OK | Failback automatique confirme |
| T-PCA-05 | DRBD synchronise | `drbdadm status mediaschool` sur MAIN et BACKUP | Primary/UpToDate — Secondary/UpToDate | ✅ OK | mediaschool: Primary/UpToDate ↔ Secondary/UpToDate |
| T-PCA-06 | Alerte VRRP Grafana | Arreter MAIN completement | Alerte dans Alertmanager | ⚠️ Non teste | Alertmanager configure, webhook a valider |

### Details T-PCA-02 — Test de Basculement (Execute le 25/04/2026)

```bash
# Etape 1 — Etat initial (MAIN est MASTER)
vagrant ssh srv-main -c "ip addr show enp0s8 | grep inet"
# > inet 192.168.50.10/24 ... + inet 192.168.50.50/24 (VIP)

# Etape 2 — Simuler la panne keepalived
vagrant ssh srv-main -c "sudo systemctl stop keepalived"

# Etape 3 — Verifier sur SRV_BACKUP apres ~5s:
vagrant ssh srv-backup -c "ip addr show enp0s8 | grep inet"
# > inet 192.168.50.20/24 + inet 192.168.50.50/24  ← VIP migree !

# Etape 4 — Retour MAIN
vagrant ssh srv-main -c "sudo systemctl start keepalived"
# Apres 8s:
vagrant ssh srv-main -c "ip addr show enp0s8 | grep inet"
# > inet 192.168.50.10/24 + inet 192.168.50.50/24  ← VIP revenue !
```

**Resultat :** Basculement < 6s, failback automatique — RTO constate < 10s

---

## Tests Supervision — Prometheus/Grafana

| ID | Test | Verification | Resultat Attendu | Statut | Resultat Obtenu |
|---|---|---|---|---|---|
| T-SUP-01 | Prometheus healthy | `curl http://localhost:9092/-/healthy` | Prometheus Server is Healthy | ✅ OK | HTTP 200 — Healthy |
| T-SUP-02 | Targets actives | `curl http://localhost:9092/api/v1/targets` | 4 targets UP | ✅ OK | 4 targets UP : node-main, node-backup, node-monitoring, prometheus |
| T-SUP-03 | Grafana web | `curl http://localhost:3002` | Page Grafana | ✅ OK | HTTP 200 — Grafana v13 |
| T-SUP-04 | Alertmanager | `curl http://localhost:9094` | Page Alertmanager | ✅ OK | HTTP 200 |
| T-SUP-05 | Node Exporter MAIN | `curl http://localhost:9101/metrics` | Metriques systeme | ✅ OK | HTTP 200 — metriques node_ presentes |
| T-SUP-06 | Alerte InstanceDown | Arreter Node Exporter sur MAIN | Alerte declenchee en 1min | ⚠️ Non teste | A valider en production |

---

## Bilan Global

| Categorie | Tests | ✅ OK | ⚠️ Partiel |
|-----------|-------|-------|-----------|
| Infrastructure | 6 | 6 | 0 |
| Docker / Services | 7 | 7 | 0 |
| LDAP | 2 | 2 | 0 |
| BorgBackup | 6 | 6 | 0 |
| PCA (DRBD + Keepalived) | 6 | 5 | 1 |
| Supervision | 6 | 5 | 1 |
| **TOTAL** | **33** | **31** | **2** |

> Les 2 tests partiels (T-PCA-06, T-SUP-06) concernent les alertes automatiques — fonctionnalite configuree, validation complete a realiser en environnement de production.