# Credentials et Acces — RP06 PRA/PCA
## NVTech | Mediaschool IRIS Nice

> **CONFIDENTIEL — Ne pas partager en dehors de l'equipe NVTech/IRIS**

---

## VMs

| VM | IP VLAN50 | IP DRBD | SSH Port | Identifiants |
|---|---|---|---|---|
| SRV_MAIN | 192.168.50.10 | 192.168.56.10 | 22 | vagrant/vagrant |
| SRV_BACKUP | 192.168.50.20 | 192.168.56.20 | 22 | vagrant/vagrant |
| SRV_MONITORING | 192.168.50.30 | 192.168.56.30 | 22 | vagrant/vagrant |
| VIP (VRRP) | 192.168.50.50 | — | — | Pointe vers MAIN ou BACKUP |

---

## URLs des Services

| Service | URL | Identifiants |
|---|---|---|
| Nextcloud | http://192.168.50.50 ou http://192.168.50.10 | admin / NextcloudAdmin2026! |
| phpLDAPadmin | http://192.168.50.10:8080 | cn=admin,dc=iris,dc=local / adminpassword |
| Portainer | https://192.168.50.10:9443 | admin (a definir au 1er login) |
| WireGuard UI | http://192.168.50.10:51821 | WireGuard_IRIS_2026! |
| Grafana | http://192.168.50.30:3000 | admin / Grafana_IRIS_2026! |
| Prometheus | http://192.168.50.30:9090 | (aucun) |
| Alertmanager | http://192.168.50.30:9093 | (aucun) |

---

## BorgBackup

| Parametre | Valeur |
|---|---|
| Depot | borguser@192.168.50.20:/srv/borg/mediaschool |
| Passphrase | BorgIRIS2026! |
| Cle SSH | /root/.ssh/borg_key (ed25519) |
| Utilisateur serveur | borguser |
| Repertoire depot | /srv/borg/mediaschool |

---

## OpenLDAP

| Parametre | Valeur |
|---|---|
| Admin DN | cn=admin,dc=iris,dc=local |
| Mot de passe admin | adminpassword |
| Base DN | dc=iris,dc=local |
| Organisation | IRIS Nice |
| Domaine | iris.local |

---

## FreeRADIUS

| Client | IP | Secret |
|---|---|---|
| SW2-IRIS | 192.168.50.2 | RadiusSW_IRIS_2026! |
| RT2-IRIS | 192.168.50.1 | RadiusRTR_IRIS_2026! |
| AP-IRIS | 192.168.50.24 | RadiusAP_IRIS_2026! |

### Utilisateurs FreeRADIUS
| Utilisateur | Mot de passe | VLAN |
|---|---|---|
| etudiant1 | Etudiant2026! | VLAN 10 |
| prof1 | Prof2026! | VLAN 20 |
| admin | Admin2026! | VLAN 30 |

### Test RADIUS
```bash
radtest etudiant1 Etudiant2026! 192.168.50.10 0 RadiusSW_IRIS_2026!
# Attendu: Received Access-Accept
```

---

## Keepalived VRRP

| Parametre | Valeur |
|---|---|
| VIP | 192.168.50.50 |
| Auth password | VRRP_IRIS_2026! |
| virtual_router_id | 51 |
| Priorite MAIN | 100 (MASTER) |
| Priorite BACKUP | 90 (BACKUP) |

---

## Cisco (Reseau Physique)

| Equipement | IP | Enable | SSH |
|---|---|---|---|
| RT2-IRIS | 192.168.50.1 | Cisco_Enable_RTR_2026! | Cisco_Admin_RTR_2026! |
| SW2-IRIS | 192.168.50.2 | Cisco_Enable_IRIS_2026! | Cisco_Admin_IRIS_2026! |
| AP-IRIS | 192.168.50.24 | — | WPA2-Enterprise (FreeRADIUS) |

---

## Bases de Donnees Docker

| Service | DB | Utilisateur | Mot de passe |
|---|---|---|---|
| Nextcloud | nextcloud | nextcloud | NextcloudDB_IRIS_2026! |
| MariaDB root | nextcloud | root | RootDB_IRIS_2026! |