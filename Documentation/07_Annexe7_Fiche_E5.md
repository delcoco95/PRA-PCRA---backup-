# ANNEXE 7 — FICHE DE PRÉSENTATION DE LA SITUATION PROFESSIONNELLE
## BTS SIO — Épreuve E5 — Session 2026

---

| | |
|---|---|
| **Candidat** | Nedjmeddine Belloum |
| **Établissement** | MEDIASCHOOL / IRIS Nice |
| **Classe** | BTS SIO — option SISR |
| **Référence** | IRIS-NICE-2026-RP06 |
| **Date de réalisation** | Janvier 2026 – Avril 2026 |

---

## 1. IDENTIFICATION DE LA SITUATION

**Intitulé :**  
Mise en place d'un PRA et d'un PCA avec BorgBackup, DRBD et Keepalived pour l'infrastructure IRIS Nice

**Référence :** IRIS-NICE-2026-RP06

**Entreprise/Organisation :** NVTech — Client IRIS Nice (École supérieure, ~300 utilisateurs)

**Durée de la situation :** 4 mois  
**Taille de l'équipe :** 1 personne — Nedjmeddine Belloum

---

## 2. DESCRIPTION DE LA SITUATION

### 2.1 Problématique initiale
L'infrastructure IRIS Nice (issue du RP01) disposait d'une sécurité réseau solide (802.1X, VLANs, AD) mais était **vulnérable aux sinistres** : panne matérielle, ransomware, corruption de données. En cas d'incident majeur, les services (Nextcloud, GLPI, authentification RADIUS) seraient interrompus pendant plusieurs heures, voire plusieurs jours.

**Enjeux business identifiés :**
- 300 utilisateurs (étudiants, profs, admin) dépendants des services numériques
- Perte de données pédagogiques (Nextcloud) = risque critique
- Interruption du système d'authentification = blocage total de l'accès au réseau

### 2.2 Différence fondamentale PRA / PCA

```
PRA (Plan de Reprise d'Activité) = Réactif
  → "Je sauvegarde — si tout plante, je restaure en X heures depuis la sauvegarde"
  → Service INTERROMPU pendant le RTO (2–24 heures)

PCA (Plan de Continuité d'Activité) = Proactif
  → "Je réplique en temps réel — si tout plante, ça bascule en < 30 secondes automatiquement"
  → Service NON INTERROMPU — transparent pour les utilisateurs
```

### 2.3 Solution déployée — Couche PRA (BorgBackup)
- Sauvegardes **horaires automatiques** avec BorgBackup/Borgmatic
- **Chiffrement AES-256** — passphrase `BorgIRIS2026!`
- **Déduplication + compression LZ4** — réduction 60-80% de l'espace
- **Stratégie 3-2-1-0-0** : 3 copies, 2 supports différents, 1 hors site, 0 erreur, 0 RPO PCA
- Rétention : 24h/7j/4sem/6 mois — **RPO < 1 heure, RTO 2–24h**

### 2.4 Solution déployée — Couche PCA (DRBD + Keepalived)
- **DRBD Protocol C** : réplication synchrone bloc par bloc — chaque écriture confirmée sur les 2 nœuds avant validation → **RPO = 0**
- **Keepalived/VRRP** : IP Virtuelle 192.168.50.50 qui migre automatiquement de SRV_MAIN vers SRV_BACKUP si le MAIN tombe — **RTO < 30 secondes**
- Script de health check : vérifie les services critiques (FreeRADIUS, OpenLDAP) toutes les 5s — déclenche le failover si KO

### 2.5 Flux de basculement PCA
```
Situation normale :
  SRV_MAIN (192.168.50.10) ←── Tous les services ←── Utilisateurs via VIP 192.168.50.50
  SRV_BACKUP (192.168.50.20) ←── Réplication DRBD en temps réel ───► SRV_MAIN

Incident — SRV_MAIN tombe :
  [Keepalived détecte absence heartbeat VRRP — délai < 5s]
        │
        ▼
  SRV_BACKUP prend le rôle MASTER
        │
        ▼
  VIP 192.168.50.50 migre vers SRV_BACKUP
        │
        ▼
  Services accessibles via VIP — RTO < 30 secondes
```

---

## 3. INFRASTRUCTURE DÉPLOYÉE

### Serveurs et adressage

| Serveur | IP VLAN50 | IP Réplication (DRBD) | RAM | Rôle |
|---|---|---|---|---|
| SRV_MEDIASCHOOL_MAIN | 192.168.50.10 | 192.168.56.10 | 3 Go | Serveur principal actif (tous les services) |
| SRV_MEDIASCHOOL_BACKUP | 192.168.50.20 | 192.168.56.20 | 3 Go | Serveur secondaire HA + dépôt BorgBackup |
| SRV_MONITORING | 192.168.50.30 | 192.168.56.30 | 2 Go | Supervision (Prometheus, Grafana, Alertmanager) |
| **VIP VRRP** | **192.168.50.50** | — | — | **IP virtuelle — migre automatiquement MAIN↔BACKUP** |

### Services Docker sur SRV_MAIN

| Service | Image Docker | Port | Rôle |
|---|---|---|---|
| OpenLDAP | osixia/openldap:1.5.0 | 389/636 | Annuaire LDAP (utilisateurs, groupes) |
| phpLDAPadmin | osixia/phpldapadmin | 8080 | Interface Web LDAP |
| FreeRADIUS | freeradius-server:3.2.3 | 1812/1813 UDP | Authentification 802.1X |
| Nextcloud | nextcloud:apache | 80 | Partage fichiers pédagogiques |
| WireGuard (wg-easy) | weejewel/wg-easy | 51820 UDP / 51821 | VPN administration |
| ClamAV | clamav:1.4_base | 3310 | Antivirus réseau |
| Portainer | portainer-ce | 9443 | Gestion Docker (GUI) |

### Services sur SRV_MONITORING

| Service | Port | Rôle |
|---|---|---|
| Prometheus | 9090 | Collecte métriques des 3 VMs |
| Grafana | 3000 | Dashboards supervision |
| Alertmanager | 9093 | Alertes (InstanceDown, VRRPFailover, BackupTooOld) |
| Node Exporter | 9100 | Métriques système (CPU, RAM, disque, réseau) |

---

## 4. TECHNOLOGIES UTILISÉES

| Technologie | Version | Usage |
|---|---|---|
| BorgBackup + Borgmatic | 1.2+ | Sauvegarde dédupliquée chiffrée (PRA) |
| DRBD | 9 | Réplication synchrone Protocol C (PCA) |
| Keepalived / VRRP | 2.2+ | Failover IP automatique (PCA) |
| Docker + Docker Compose | 24+ | Orchestration des services |
| OpenLDAP | 1.5 | Annuaire centralisé |
| FreeRADIUS | 3.2 | Authentification 802.1X |
| Nextcloud | latest | Stockage pédagogique partagé |
| WireGuard | latest | VPN administration |
| ClamAV | 1.4 | Antivirus |
| Prometheus + Grafana | 2.54 / latest | Supervision et dashboards |
| Alertmanager | 0.27 | Alertes infrastructure |
| Vagrant + VirtualBox | latest | Provisioning automatisé 3 VMs |
| Ubuntu 22.04 LTS | Jammy | OS des 3 VMs |

---

## 5. COMPÉTENCES BTS SIO MOBILISÉES

| Code | Compétence | Application concrète dans RP06 |
|---|---|---|
| **B1.1** | Recenser et identifier les ressources | Inventaire 3 VMs, 7 services Docker, disques DRBD séparés (sdb), plan d'adressage dual-stack |
| **B1.2** | Exploiter les documentations | Documentation DRBD (RFC), Borgmatic docs, Keepalived/VRRP IETF RFC 5798 |
| **B1.3** | Mettre en place les niveaux d'habilitation | UFW (pare-feu), SSH ed25519 avec `command="borg serve"` (restriction), droits borguser |
| **B2.1** | Intervenir sur les éléments du SI | Provisioning Vagrant (3 scripts bash), Docker Compose, configuration DRBD + Keepalived |
| **B2.2** | Garantir la disponibilité des services | DRBD + Keepalived RTO<30s (PCA), Borgmatic RPO<1h (PRA) |
| **B3.1** | Mettre en œuvre la sécurité | Chiffrement AES-256 BorgBackup, VPN WireGuard, FreeRADIUS 802.1X, authentification VRRP |
| **B3.2** | Assurer la supervision et la mesure | Prometheus (métriques), Grafana (dashboards), Alertmanager (5 règles d'alerte) |

---

## 6. TABLEAU RTO / RPO COMPARATIF

| Critère | PRA (BorgBackup) | PCA (DRBD + Keepalived) |
|---|---|---|
| **RTO** (temps de reprise) | 2 – 24 heures | **< 30 secondes** |
| **RPO** (perte de données max) | **< 1 heure** | **0** (synchrone) |
| Mécanisme | Restauration depuis archive | Basculement automatique |
| Interruption de service | Oui (pendant le RTO) | Non (transparent) |
| Cas d'usage | Catastrophe totale, ransomware | Panne serveur, crash OS |
| Coût stockage | Faible (déduplication) | Moyen (miroir complet) |

---

## 7. RÉSULTATS ET VALIDATION

### Tests PCA (à réaliser sur l'infrastructure lab)

| ID | Test | Procédure | Résultat attendu |
|---|---|---|---|
| T-PCA-01 | VIP accessible | `ping 192.168.50.50` | Réponse de SRV_MAIN |
| T-PCA-02 | Basculement VRRP | `systemctl stop keepalived` sur MAIN | VIP migre vers BACKUP < 30s |
| T-PCA-03 | Services après failover | `curl http://192.168.50.50` | Page Nextcloud accessible |
| T-PCA-04 | Retour en production | `systemctl start keepalived` sur MAIN | VIP revient sur MAIN (priorité 100 > 90) |
| T-PCA-05 | DRBD synchronisé | `drbdadm status` | Both UpToDate |
| T-PCA-06 | Alerte Grafana | Arrêter MAIN | Alerte VRRPFailover dans Alertmanager |

### Tests PRA (BorgBackup)

| ID | Test | Procédure | Résultat attendu |
|---|---|---|---|
| T-PRA-01 | Sauvegarde manuelle | `borgmatic create --verbosity 1` | Archive créée, 0 erreur |
| T-PRA-02 | Listage archives | `borgmatic list` | Archives horodatées visibles |
| T-PRA-03 | Restauration | `borgmatic restore --archive latest` | Fichiers restaurés intacts |
| T-PRA-04 | Vérification intégrité | `borgmatic check` | 0 erreur de cohérence |

---

## 8. DIFFICULTÉS ET SOLUTIONS

| Difficulté | Solution |
|---|---|
| DRBD nécessite un disque secondaire dédié | Vagrantfile crée un disque VMDK de 10 Go (sdb) à l'initialisation |
| SSH BorgBackup entre VMs sans mot de passe | Génération clé ed25519 sur MAIN, copie dans `borguser@BACKUP:~/.ssh/authorized_keys` avec restriction `command="borg serve"` |
| Keepalived interface réseau variable (`enp0s8` vs `enp0s3`) | Interface détectée dynamiquement dans le script provision ou documentée dans le guide |
| Node Exporter exposé sur le réseau DRBD (56.x) | Cible Prometheus = 192.168.56.x pour éviter le trafic de métriques sur VLAN Management |

---

## 9. LIENS

- **GitHub :** https://github.com/delcoco95/PRA-PCRA---backup-
- **Portfolio :** https://delcoco95.github.io/portfolio-nedj/
- **Annexe 7 officielle PDF :** voir fichier `Annexe7_RP06_Nedj Belloum.pdf`
- **Référence BTS SIO :** IRIS-NICE-2026-RP06

---

*Nedjmeddine Belloum — BTS SIO SISR — MEDIASCHOOL / IRIS Nice — Session 2026*