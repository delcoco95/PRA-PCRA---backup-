# Procedures d'Urgence — RP06 PRA/PCA
## NVTech | Mediaschool IRIS Nice

**Auteur:** Nedjmeddine Belloum — BTS SIO SISR  
**Date:** 2025-2026  

---

## Contacts d'Urgence

| Role | Contact | IP/Acces |
|---|---|---|
| Admin systeme | Nedjmeddine Belloum | SSH vagrant@192.168.50.10 |
| Passerelle/Routeur | RT2-IRIS | 192.168.50.1 |
| VIP Services | IP Virtuelle VRRP | 192.168.50.50 |
| Supervision | Grafana | http://192.168.50.30:3000 |

---

## Situation 0 (PRIORITAIRE) — Basculement Automatique PCA

> **"Le serveur MAIN est tombe. Le PCA bascule automatiquement en moins de 30 secondes."**

### Actions requises: NE RIEN FAIRE (c'est automatique)

**Verification que le PCA fonctionne:**
```bash
# 1. Verifier que la VIP repond encore
ping 192.168.50.50
# Si ping repond -> PCA actif, services OK

# 2. Acceder aux services normalement via la VIP
curl http://192.168.50.50  # Nextcloud
# Tous les services continuent sur 192.168.50.50

# 3. Verifier quel serveur est MASTER
# Sur SRV_BACKUP:
ip addr show enp0s8 | grep 192.168.50.50
# Si affiche: SRV_BACKUP est MASTER (PCA actif)
```

### Communication
- Prevenir les equipes que **SRV_BACKUP est maintenant MASTER** temporairement
- Les services sont disponibles sans interruption
- Planifier la remise en production de SRV_MAIN

### Remise en production SRV_MAIN
```bash
# 1. Demarrer SRV_MAIN
vagrant up srv-main  # ou demarrage physique

# 2. DRBD resynchronise automatiquement en tache de fond
# Surveiller: watch -n5 'cat /proc/drbd'

# 3. Keepalived reprend MASTER automatiquement (priorite 100 > 90)
# VIP revient sur SRV_MAIN

# 4. Verifier
ip addr show enp0s8 | grep 192.168.50.50  # sur SRV_MAIN
drbdadm status  # Both: UpToDate/UpToDate
```

---

## Situation 1 — Panne Materielle MAIN (PRA — Restauration BorgBackup)

> **RTO: 8-24h — Utiliser UNIQUEMENT si le PCA ne peut pas fonctionner (BACKUP aussi tombe)**

### Etapes
```bash
# 1. Preparer un nouveau serveur
vagrant up srv-main  # ou nouveau materiel + OS Ubuntu 22.04

# 2. Installer BorgBackup
apt-get install -y borgbackup borgmatic

# 3. Recuperer la cle SSH Borg
# (depuis sauvegarde de cle, ou contacter admin BACKUP)
scp vagrant@192.168.50.20:/home/borguser/.ssh/authorized_keys /tmp/borg_key.pub

# 4. Lister les archives disponibles
BORG_PASSPHRASE='BorgIRIS2026!' \
  BORG_RSH='ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no' \
  borg list borguser@192.168.50.20:/srv/borg/mediaschool

# 5. Restaurer la derniere archive
BORG_PASSPHRASE='BorgIRIS2026!' \
  BORG_RSH='ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no' \
  borg extract --progress \
  borguser@192.168.50.20:/srv/borg/mediaschool::ARCHIVE_NAME \
  /

# 6. Relancer Docker
cd /vagrant && docker compose up -d

# 7. Verifier
docker ps  # tous les services up
curl http://localhost  # Nextcloud accessible
```

---

## Situation 2 — Panne Reseau / Switch

### Symptomes
- Perte de connectivite vers plusieurs VMs
- VIP 192.168.50.50 ne repond plus
- Alertes Prometheus multiples

### Diagnostic
```bash
# Depuis RT2-IRIS
ping 192.168.50.2   # Switch SW2-IRIS
ping 192.168.50.10  # SRV_MAIN
ping 192.168.50.20  # SRV_BACKUP
ping 192.168.50.30  # SRV_MONITORING

# Verifier les interfaces
show interfaces status  # sur SW2-IRIS (Cisco)
show ip interface brief  # sur RT2-IRIS

# Verifier les VLANs
show vlan brief  # sur SW2-IRIS
```

### Escalade
1. Verifier les cables physiques et les LEDs des ports switch
2. Verifier la configuration trunk VLAN 50 sur SW2-IRIS
3. Tester depuis un poste VLAN 10 (etudiants) vers 192.168.50.10
4. Si probleme persiste: contact fournisseur/responsable reseau

---

## Situation 3 — Services Docker Ne Demarrent Pas

```bash
# Verifier l'etat des containers
docker ps -a  # voir les containers en erreur

# Logs d'un service specifique
docker logs freeradius --tail 50
docker logs openldap --tail 50
docker logs nextcloud --tail 50

# Forcer le redemarrage
docker compose down && docker compose up -d

# Si probleme de volumes
docker volume ls
docker volume inspect nextcloud_data
```

---

## Checklist Urgence Generale

- [ ] Verifier que la VIP 192.168.50.50 repond (ping)
- [ ] Acceder a Grafana: http://192.168.50.30:3000
- [ ] Verifier les alertes Alertmanager: http://192.168.50.30:9093
- [ ] `drbdadm status` — DRBD synchronise ?
- [ ] `docker ps` sur SRV_MAIN ou SRV_BACKUP (MASTER)
- [ ] Journaux Keepalived: `journalctl -u keepalived -n 50`
- [ ] Journaux borgmatic: `tail -50 /var/log/borgmatic.log`