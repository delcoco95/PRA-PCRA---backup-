# ANNEXE 7 — FICHE DE PRESENTATION DE LA SITUATION PROFESSIONNELLE
## BTS SIO — Epreuve E5 — Session 2026

**Etablissement:** MEDIASCHOOL / IRIS Nice  
**Candidat:** Nedjmeddine Belloum  
**Classe:** BTS SIO SISR  

---

## Identification de la Situation

**Intitule:** Mise en place d'un PRA et d'un PCA avec BorgBackup, DRBD et Keepalived pour l'infrastructure IRIS Nice

**Reference:** IRIS-NICE-2026-RP06

**Entreprise/Organisation:** NVTech — Client IRIS Nice (Ecole superieure, 200 etudiants)

---

## Contexte et Enjeux

L'ecole IRIS Nice a confie a NVTech la mise en place d'une solution complete de continuite et reprise d'activite pour son infrastructure informatique. Le projet couvre deux axes complementaires :

### PRA — Plan de Reprise d'Activite
- Sauvegarde automatique chiffree avec BorgBackup/Borgmatic
- Strategie 3-2-1-0-0 : 3 copies, 2 supports, 1 hors site, 0 erreur, 0 RPO pour PCA
- Chiffrement AES-256, deduplication, compression LZ4
- **RTO : 2–24h** selon scenario | **RPO : < 1 heure**

### PCA — Plan de Continuite d'Activite
- Replication synchrone DRBD Protocol C entre SRV_MAIN et SRV_BACKUP
- Basculement automatique Keepalived/VRRP — IP Virtuelle 192.168.50.50
- **RTO : < 30 secondes** (transparent pour les utilisateurs)
- **RPO : 0** (aucune perte de donnees — replication synchrone)

---

## Infrastructure Deployee

| Serveur | IP VLAN50 | IP Replication | Role |
|---|---|---|---|
| SRV_MEDIASCHOOL_MAIN | 192.168.50.10 | 192.168.56.10 | Serveur principal actif |
| SRV_MEDIASCHOOL_BACKUP | 192.168.50.20 | 192.168.56.20 | Serveur secondaire HA + BorgBackup serveur |
| SRV_MONITORING | 192.168.50.30 | 192.168.56.30 | Supervision (Prometheus, Grafana) |
| VIP VRRP | 192.168.50.50 | — | IP virtuelle (migre automatiquement) |

### Technologies Utilisees
- **BorgBackup 1.2 + Borgmatic** : sauvegarde dedupliquee chiffree AES-256
- **DRBD 9** : replication synchrone Protocol C, RPO=0
- **Keepalived/VRRP** : failover IP automatique, RTO<30s
- **Docker + Docker Compose** : OpenLDAP, FreeRADIUS, Nextcloud, WireGuard, ClamAV, Portainer
- **Prometheus + Grafana + Alertmanager** : supervision et alerting
- **Vagrant + VirtualBox** : provisioning automatise des 3 VMs

### Services Deployes
| Service | Image Docker | Port | Role |
|---|---|---|---|
| OpenLDAP | osixia/openldap:1.5.0 | 389/636 | Annuaire LDAP |
| phpLDAPadmin | osixia/phpldapadmin | 8080 | Interface Web LDAP |
| FreeRADIUS | freeradius-server:3.2.3 | 1812/1813 | Auth 802.1X |
| Nextcloud | nextcloud:apache | 80 | Partage fichiers |
| WireGuard | weejewel/wg-easy | 51820/51821 | VPN |
| ClamAV | clamav:1.4_base | 3310 | Antivirus |
| Portainer | portainer-ce | 9443 | Gestion Docker |

---

## Competences BTS SIO Mobilisees

| Code | Competence | Application dans RP06 |
|---|---|---|
| B1.1 | Recenser et identifier les ressources | Inventaire VMs, services, disques DRBD |
| B1.2 | Exploiter les documentiations | Configuration DRBD, Borgmatic, Keepalived |
| B1.3 | Mettre en place et verifier les niveaux d'habilitation | UFW, SSH ed25519, restriction borg serve |
| B2.1 | Intervenir sur les elements du SI | Provisioning Vagrant, Docker Compose |
| B2.2 | Garantir la disponibilite des services | DRBD + Keepalived (PCA), Borgmatic (PRA) |
| B3.1 | Mettre en oeuvre et maintenir les solutions de securite | Chiffrement AES-256, VPN WireGuard, RADIUS 802.1X |
| B3.2 | Assurer la supervision et la mesure | Prometheus, Grafana, Alertmanager |

---

## Liens

- **GitHub:** https://github.com/delcoco95/PRA-PCRA---backup-
- **Portfolio:** https://delcoco95.github.io/portfolio-nedj/
- **Annexe 7 officielle PDF:** voir fichier `Annexe7_RP06_Nedj Belloum.pdf`