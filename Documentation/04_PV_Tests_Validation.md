# PV de Tests et Validation
## NVTech | Mediaschool IRIS Nice | RP06 — PRA/PCA

**Auteur:** Nedjmeddine Belloum — BTS SIO SISR  
**Date:** 2025-2026  

---

## Tests Infrastructure de Base

| ID | Test | Commande | Resultat Attendu | Statut |
|---|---|---|---|---|
| T-INF-01 | Ping SRV_MAIN | `ping 192.168.50.10` | Reponse ICMP | A tester |
| T-INF-02 | Ping SRV_BACKUP | `ping 192.168.50.20` | Reponse ICMP | A tester |
| T-INF-03 | Ping SRV_MONITORING | `ping 192.168.50.30` | Reponse ICMP | A tester |
| T-INF-04 | SSH SRV_MAIN | `vagrant ssh srv-main` | Connexion OK | A tester |
| T-INF-05 | SSH SRV_BACKUP | `vagrant ssh srv-backup` | Connexion OK | A tester |
| T-INF-06 | SSH SRV_MONITORING | `vagrant ssh srv-monitoring` | Connexion OK | A tester |

---

## Tests Docker — Services

| ID | Test | Commande | Resultat Attendu | Statut |
|---|---|---|---|---|
| T-DOC-01 | Docker running | `docker ps` | 7 containers Up | A tester |
| T-DOC-02 | Nextcloud web | `curl http://192.168.50.10` | Page Nextcloud | A tester |
| T-DOC-03 | phpLDAPadmin | `curl http://192.168.50.10:8080` | Page HTML | A tester |
| T-DOC-04 | Portainer | `curl -k https://192.168.50.10:9443` | Page Portainer | A tester |
| T-DOC-05 | WireGuard UI | `curl http://192.168.50.10:51821` | Page WG | A tester |

---

## Tests RADIUS/LDAP — Authentification 802.1X

| ID | Test | Commande | Resultat Attendu | Statut |
|---|---|---|---|---|
| T-RAD-01 | RADIUS etudiant | `radtest etudiant1 Etudiant2026! 192.168.50.10 0 RadiusSW_IRIS_2026!` | Access-Accept + VLAN 10 | A tester |
| T-RAD-02 | RADIUS prof | `radtest prof1 Prof2026! 192.168.50.10 0 RadiusSW_IRIS_2026!` | Access-Accept + VLAN 20 | A tester |
| T-RAD-03 | RADIUS admin | `radtest admin Admin2026! 192.168.50.10 0 RadiusSW_IRIS_2026!` | Access-Accept + VLAN 30 | A tester |
| T-RAD-04 | RADIUS mauvais mdp | `radtest etudiant1 mauvais 192.168.50.10 0 RadiusSW_IRIS_2026!` | Access-Reject | A tester |
| T-RAD-05 | LDAP connexion | `ldapsearch -x -H ldap://192.168.50.10 -D "cn=admin,dc=iris,dc=local" -w adminpassword -b "dc=iris,dc=local"` | Entrees LDAP | A tester |

---

## Tests BorgBackup — PRA

| ID | Test | Commande | Resultat Attendu | Statut |
|---|---|---|---|---|
| T-BORG-01 | Init depot Borg | `borgmatic init --encryption repokey` | Depot cree | A tester |
| T-BORG-02 | Sauvegarde manuelle | `borgmatic create --verbosity 1` | Archive creee | A tester |
| T-BORG-03 | Lister archives | `borgmatic list` | Liste archives | A tester |
| T-BORG-04 | Verifier consistance | `borgmatic check` | OK (0 erreur) | A tester |
| T-BORG-05 | Restauration test | `borgmatic restore --archive latest --destination /restore-test` | Fichiers restaures | A tester |
| T-BORG-06 | Cron horaire | `cat /etc/cron.d/borgmatic` | Cron configure | A tester |
| T-BORG-07 | Logs sauvegarde | `tail -20 /var/log/borgmatic.log` | Entrees horodatees | A tester |

---

## Tests PCA — DRBD + Keepalived

| ID | Test | Procedure | Resultat Attendu | Statut |
|---|---|---|---|---|
| T-PCA-01 | VIP accessible | `ping 192.168.50.50` depuis poste admin | Reponse de MAIN | A tester |
| T-PCA-02 | Basculement VRRP | `sudo systemctl stop keepalived` sur SRV_MAIN | VIP migre vers BACKUP <30s | A tester |
| T-PCA-03 | Services apres failover | `curl http://192.168.50.50` apres T-PCA-02 | Page Nextcloud OK | A tester |
| T-PCA-04 | Retour production MAIN | `sudo systemctl start keepalived` sur SRV_MAIN | VIP revient sur MAIN | A tester |
| T-PCA-05 | DRBD synchronise | `drbdadm status` sur MAIN et BACKUP | Both: UpToDate/UpToDate | A tester |
| T-PCA-06 | Alerte VRRP Grafana | Arreter MAIN completement | Alerte dans Alertmanager | A tester |

### Details T-PCA-02 (Test de Basculement)

```bash
# Etape 1 — Etat initial (MAIN est MASTER)
# Sur SRV_MAIN:
ip addr show enp0s8 | grep 192.168.50.50
# > inet 192.168.50.50/24 scope global secondary enp0s8

# Etape 2 — Simuler la panne
sudo systemctl stop keepalived

# Etape 3 — Attendre 30s puis verifier sur SRV_BACKUP:
ip addr show enp0s8 | grep 192.168.50.50
# > inet 192.168.50.50/24 scope global secondary enp0s8

# Etape 4 — Verifier les services
curl http://192.168.50.50
# > Page Nextcloud OK

# Etape 5 — Retour MAIN
sudo systemctl start keepalived  # sur SRV_MAIN
# Attendre 5s...
ip addr show enp0s8 | grep 192.168.50.50  # sur SRV_MAIN
# > inet 192.168.50.50/24 scope global secondary enp0s8
```

---

## Tests Supervision — Prometheus/Grafana

| ID | Test | Verification | Resultat Attendu | Statut |
|---|---|---|---|---|
| T-SUP-01 | Prometheus up | `curl http://192.168.50.30:9090/-/healthy` | OK | A tester |
| T-SUP-02 | Targets actives | `curl http://192.168.50.30:9090/api/v1/targets` | 3 targets UP | A tester |
| T-SUP-03 | Grafana web | `curl http://192.168.50.30:3000` | Page Grafana | A tester |
| T-SUP-04 | Alertmanager | `curl http://192.168.50.30:9093` | Page Alertmanager | A tester |
| T-SUP-05 | Node metrics MAIN | `curl http://192.168.56.10:9100/metrics` | Metriques systeme | A tester |
| T-SUP-06 | Alerte InstanceDown | Arreter Node Exporter sur MAIN | Alerte declenchee en 1min | A tester |