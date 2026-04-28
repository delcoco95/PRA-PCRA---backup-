# Guide de déploiement Cisco — RP06
## Projet IRIS Nice — NVTech — BTS SIO SISR

---

## Pré-requis

| Élément | État requis |
|---------|-------------|
| PC Ethernet 4 | IP statique 192.168.50.100 / 255.255.255.0 |
| SRV_MEDIASCHOOL_COPY | VM Vagrant avec interface bridgée 192.168.50.11 |
| FreeRADIUS | Conteneur UP, port 1812 exposé |
| Câble console USB → Cisco | Branché sur PC et switch/routeur |
| PuTTY (ou minicom) | Pour accès console |

---

## Étape 1 — Préparer la VM (à faire avant le switch)

### 1a — Changer l'IP du PC (Ethernet 4)

```
ncpa.cpl → Ethernet 4 → IPv4 → Manuel :
  IP       : 192.168.50.100
  Masque   : 255.255.255.0
  Passerelle: (laisser vide pour l'instant)
```

### 1b — Modifier le Vagrantfile

Fichier déjà modifié : `SRV_MEDIASCHOOL_COPY/Vagrantfile`
La ligne `private_network` est maintenant `public_network bridge: "USB2.0 Ethernet Adapter"`.

### 1c — Recharger la VM

```powershell
cd "C:\Users\nedjb\Documents\PROJET IT\- RP06 - PRA_PCRA_Backup - Nedj\SRV_MEDIASCHOOL_COPY"
vagrant reload
```

> ⚠️ Vagrant demande de choisir l'interface bridge. Sélectionner **"Ethernet 4"** (USB2.0 Ethernet Adapter).

### 1d — Vérifier la VM

```bash
# Sur la VM (vagrant ssh)
ip addr show
# Doit afficher : inet 192.168.50.11/24 sur enp0s9 (ou enp0s8)
```

```powershell
# Sur le PC Windows
ping 192.168.50.11
# Doit répondre
```

### 1e — Redémarrer FreeRADIUS (pour prendre en compte le nouveau clients.conf)

```bash
# Sur la VM
cd /vagrant
docker compose restart freeradius
docker logs freeradius --tail=20
```

---

## Étape 2 — Configurer le Switch Catalyst 2960-S

### 2a — Connexion console

```
PuTTY :
  Connection type : Serial
  Port : COM3 (ou COM4, vérifier dans Gestionnaire de périphériques)
  Speed : 9600
  Data bits : 8
  Stop bits : 1
  Parity : None
  Flow control : None
```

### 2b — Réinitialisation complète

```
Switch> enable
Switch# write erase
Erasing the nvram filesystem will remove all configuration files! Continue? [confirm] → Entrée
Switch# reload
Proceed with reload? [confirm] → Entrée
```

### 2c — Appliquer la configuration

Après le reboot (≈2 min), coller le contenu de **`configs-cisco/switch-SW-IRIS.txt`**.

> La commande `crypto key generate rsa modulus 2048` prend ~30 secondes.

### 2d — Vérification switch

```
SW-IRIS# show vlan brief
! Doit afficher les VLANs 10,20,30,40,50,99

SW-IRIS# show interfaces trunk
! Doit montrer Fa0/1 et Gi0/1 en trunk

SW-IRIS# show ip interface brief
! Doit montrer Vlan50 : 192.168.50.2 UP/UP

SW-IRIS# ping 192.168.50.100
! Doit répondre (PC Windows)

SW-IRIS# ping 192.168.50.11
! Doit répondre (SRV_MEDIASCHOOL_COPY)
```

---

## Étape 3 — Configurer le Routeur ISR 1941W

### 3a — Connexion console

Même procédure que le switch, changer le port COM si nécessaire.

### 3b — Réinitialisation complète

```
Router> enable
Router# write erase
Router# reload
```

### 3c — Appliquer la configuration

Coller le contenu de **`configs-cisco/routeur-RTR-IRIS.txt`**.

### 3d — Vérification routeur

```
RTR-IRIS# show ip interface brief
! Gi0/0.10 : 192.168.10.1 UP
! Gi0/0.20 : 192.168.20.1 UP
! Gi0/0.30 : 192.168.30.1 UP
! Gi0/0.40 : 192.168.40.1 UP
! Gi0/0.50 : 192.168.50.1 UP
! Gi0/0.99 : 192.168.99.1 UP

RTR-IRIS# ping 192.168.50.2
! Switch SVI → doit répondre

RTR-IRIS# ping 192.168.50.11
! SRV_MEDIASCHOOL_COPY → doit répondre
```

---

## Étape 4 — Test 802.1X end-to-end

### 4a — Test RADIUS depuis la VM

```bash
# Sur SRV_MEDIASCHOOL_COPY (vagrant ssh)
docker exec freeradius radtest nedj.belloum "NVTech_Admin2026!" 192.168.50.11 1812 RadiusTest_IRIS_2026!
# Résultat attendu : Access-Accept + Tunnel-Private-Group-Id = 30 (VLAN Admin)
```

### 4b — Test RADIUS depuis le switch

```
SW-IRIS# test aaa group radius server FREERADIUS-IRIS nedj.belloum NVTech_Admin2026! legacy
! Résultat attendu : User successfully authenticated
```

### 4c — Test 802.1X avec un client

1. Brancher un PC client sur Fa0/2 du switch
2. Configurer le PC : `ncpa.cpl → Ethernet → Authentification → Activer 802.1X`
3. Se connecter avec un compte LDAP (ex: `etudiant1` / `Student1_IRIS!`)
4. Vérifier l'assignation VLAN :
```
SW-IRIS# show authentication sessions interface FastEthernet0/2
! Doit montrer : Vlan 10 (étudiant) ou Vlan 20 (prof) ou Vlan 30 (admin)
```

---

## Plan d'adressage final

| Équipement | IP | VLAN |
|------------|-----|------|
| Routeur RTR-IRIS | 192.168.50.1 | MGMT (50) |
| Switch SW-IRIS SVI | 192.168.50.2 | MGMT (50) |
| AP WiFi | 192.168.50.3 | MGMT (50) |
| SRV_MEDIASCHOOL_COPY | 192.168.50.11 | MGMT (50) |
| SRV_BACKUP | 192.168.56.20 | Host-only |
| SRV_MONITORING | 192.168.56.30 | Host-only |
| PC Windows (Ethernet 4) | 192.168.50.100 | MGMT (50) |
| Clients VLAN 10 | 192.168.10.11-254 | Étudiants |
| Clients VLAN 20 | 192.168.20.11-254 | Profs |
| Clients VLAN 30 | 192.168.30.11-254 | Admin |
| Clients VLAN 40 | 192.168.40.11-254 | Guest |

---

## En cas de problème

### FreeRADIUS ne répond pas depuis le switch

```bash
# Vérifier que FreeRADIUS écoute sur toutes les interfaces
docker exec freeradius netstat -ulnp | grep 1812

# Vérifier les logs en temps réel
docker logs freeradius -f

# Le client 192.168.50.2 est-il dans clients.conf ?
grep -A5 "SW_IRIS" /vagrant/freeradius/clients.conf
```

### Le switch ne ping pas 192.168.50.11

```
SW-IRIS# show interfaces FastEthernet0/1 trunk
! Fa0/1 doit être en mode trunk
! Native VLAN doit être 50
```

### Vagrant ne monte pas le réseau bridgé

```powershell
# Dans le répertoire SRV_MEDIASCHOOL_COPY
vagrant halt
vagrant up
# Quand demandé, sélectionner "Ethernet 4"
```
