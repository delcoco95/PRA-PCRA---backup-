# Architecture PRA/PCA — Infrastructure RP06
## NVTech | Mediaschool IRIS Nice | RP06

**Auteur:** Nedjmeddine Belloum — BTS SIO SISR  
**Date:** 2025-2026  

---

## 1. Schema d'Architecture

```
                    INTERNET / WAN
                          |
                    [RT2-IRIS]
                    192.168.50.1
                          |
                    [SW2-IRIS]
                    192.168.50.2
                     /    |    \
                    /     |     \
          +---------+  +------+  +-----------+
          |SRV_MAIN |  |      |  |SRV_MONITOR|
          |.50.10   |  | VIP  |  |.50.30     |
          |         |  |.50.50|  |           |
          |OpenLDAP |  |      |  |Prometheus |
          |GLPI     |<-+VRRP  |  |Grafana    |
          |Nextcloud|  |      |  |Alertmgr   |
          |WireGuard|  +------+  +-----------+
          |ClamAV   |       |
          |Keepalived       |
          |MASTER   |       |
          +---------+       |
               |            |
    DRBD       |            |
    Protocol C |            |
    (sync)     |            |
               |            |
          +---------+       |
          |SRV_BACK |<------+
          |.50.20   |
          |BorgBackup|
          |DRBD     |
          |Keepalived|
          |BACKUP   |
          +---------+

  Reseau replication: 192.168.56.x (host-only)
  SRV_MAIN:   192.168.56.10
  SRV_BACKUP: 192.168.56.20
  SRV_MONITOR:192.168.56.30
```

---

## 2. Tableau des VMs

| Serveur | IP VLAN50 | IP Replication | RAM | CPU | Disque DRBD | Role |
|---|---|---|---|---|---|---|
| SRV_MAIN | 192.168.50.10 | 192.168.56.10 | 3 Go | 2 | /dev/sdb (10Go) | Serveur principal actif |
| SRV_BACKUP | 192.168.50.20 | 192.168.56.20 | 3 Go | 2 | /dev/sdb (10Go) | Standby HA + BorgBackup |
| SRV_MONITORING | 192.168.50.30 | 192.168.56.30 | 2 Go | 2 | — | Prometheus + Grafana |
| VIP VRRP | 192.168.50.50 | — | — | — | — | IP virtuelle (auto-migration) |

---

## 3. Plan d'Adressage Complet

### VLANs Cisco
| VLAN | Reseau | Nom | Utilisation |
|---|---|---|---|
| VLAN 10 | 192.168.10.0/24 | ETUDIANTS | Postes etudiants |
| VLAN 20 | 192.168.20.0/24 | PROFS | Postes professeurs |
| VLAN 30 | 192.168.30.0/24 | ADMIN | Administration |
| VLAN 50 | 192.168.50.0/24 | MANAGEMENT | Serveurs + equipements |

### Equipements reseau
| Equipement | IP | Role |
|---|---|---|
| RT2-IRIS | 192.168.50.1 | Routeur/Passerelle |
| SW2-IRIS | 192.168.50.2 | Switch L3 Cisco |
| AP-IRIS | 192.168.50.24 | Point d'acces WiFi |

---

## 4. Flux DRBD (Replication Synchrone)

```
SRV_MAIN                              SRV_BACKUP
[/dev/sdb] ----- Protocol C -----> [/dev/sdb]
           192.168.56.10:7789   192.168.56.20:7789
           
Ecriture -> DRBD confirme SEULEMENT quand les 2 noeuds ont ecrit
=> RPO = 0 (zero perte de donnees)
=> Protocole synchrone, temps reel
```

**Ressource DRBD:** `mediaschool` (fichier: `/etc/drbd.d/mediaschool.res`)  
**Device:** `/dev/drbd1`  
**Disque physique:** `/dev/sdb` (10 Go dedie)  

---

## 5. Flux VRRP (Basculement Automatique)

```
Etat NORMAL:
  SRV_MAIN (MASTER, priorite 100) possede la VIP 192.168.50.50
  SRV_BACKUP (BACKUP, priorite 90) surveille

Etat PANNE MAIN:
  1. SRV_MAIN tombe
  2. SRV_BACKUP ne recoit plus d'advertisements VRRP (timeout ~3s)
  3. SRV_BACKUP passe MASTER automatiquement
  4. VIP 192.168.50.50 migre sur SRV_BACKUP
  5. Services continuent sur l'IP virtuelle
  => RTO < 30 secondes, transparent pour les utilisateurs

Retour MAIN:
  1. SRV_MAIN redemarre + keepalived start
  2. SRV_MAIN redevient MASTER (priorite 100 > 90)
  3. VIP revient sur SRV_MAIN
  4. DRBD resynchronise automatiquement
```

---

## 6. Flux BorgBackup

```
SRV_MAIN                              SRV_BACKUP
[cron 0 * * *]                        [borguser@192.168.50.20]
    |                                       |
    v                                       |
borgmatic create ----SSH ed25519----> /srv/borg/mediaschool/
    |                                  (dépôt chiffré AES-256)
    v
Sources:
  - /home/vagrant
  - /etc
  - /var/lib/docker/volumes
```

**Frequence:** Horaire (cron `0 * * * *`)  
**Chiffrement:** AES-256 (passphrase: BorgIRIS2026!)  
**Compression:** LZ4  
**Deduplication:** Automatique (chunk-level)  

---

## 7. Comparatif PRA vs PCA

| Critere | PRA (BorgBackup) | PCA (DRBD+Keepalived) |
|---|---|---|
| RTO | 2-24 heures | **< 30 secondes** |
| RPO | **< 1 heure** | **0 (replication synchrone)** |
| Mecanisme | Restauration depuis sauvegarde | Basculement automatique |
| Interruption service | Oui (duree = RTO) | Non (transparent) |
| Cout stockage | Faible (deduplication Borg) | Moyen (miroir complet DRBD) |
| Cas d'usage | Catastrophe totale, ransomware | Panne serveur, crash OS |
| Intervention humaine | Oui (restore manuel) | Non (automatique) |

---

## 8. Ports et Services

| Service | Port | Protocole | Source |
|---|---|---|---|
| SSH | 22 | TCP | Tous |
| HTTP Nextcloud | 80 | TCP | VLAN 50 |
| LDAP | 389 | TCP | VLAN 50 |
| LDAPS | 636 | TCP | VLAN 50 |
| GLPI | 8090 | TCP | VLAN 50 |
| phpLDAPadmin | 8080 | TCP | VLAN 50 |
| DRBD | 7789 | TCP | Replication |
| Node Exporter | 9100 | TCP | Monitoring |
| Portainer | 9443 | TCP | Admin |
| WireGuard VPN | 51820 | UDP | Internet |
| WireGuard UI | 51821 | TCP | VLAN 50 |
| Prometheus | 9090 | TCP | Monitoring |
| Alertmanager | 9093 | TCP | Monitoring |
| Grafana | 3000 | TCP | Monitoring |
| ClamAV | 3310 | TCP | Interne |

---

## 9. Politique de Retention Borgmatic

| Granularite | Retention | Cas d'usage |
|---|---|---|
| Horaire | 24 archives | Restauration < 24h |
| Quotidienne | 7 archives | Restauration semaine precedente |
| Hebdomadaire | 4 archives | Restauration mois precedent |
| Mensuelle | 6 archives | Restauration semestre |

**Total archives max:** ~41 archives (deduplication = faible utilisation disque)