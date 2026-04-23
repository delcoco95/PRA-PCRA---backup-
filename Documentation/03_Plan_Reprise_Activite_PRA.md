# Plan de Reprise d'Activite (PRA)
## NVTech | Mediaschool IRIS Nice | RP06

**Auteur:** Nedjmeddine Belloum — BTS SIO SISR  
**Date:** 2025-2026  
**Version:** 2.0 (avec PCA integre)

---

## Introduction — Difference PRA / PCA

| | PRA — Plan de Reprise | PCA — Plan de Continuite |
|---|---|---|
| Definition | Procedures de restauration apres sinistre | Maintien des services sans interruption |
| RTO | 2–24 heures | < 30 secondes |
| RPO | < 1 heure | 0 (synchrone) |
| Mecanisme | BorgBackup + restauration manuelle | DRBD + Keepalived automatique |
| Declencheur | Sinistre majeur (incendie, ransomware) | Panne serveur/crash OS |

---

## Scenario 1 — Defaillance Disque Dur (RTO: 4-6h, RPO: <1h)

### Detection
- Alertes Prometheus/Grafana sur metriques disque
- Journaux systeme: `smartctl -a /dev/sda`, `dmesg | grep -i error`
- Notification Alertmanager

### Restauration
```bash
# 1. Remplacer le disque physique (hors ligne)

# 2. Reinstaller le systeme de base
vagrant destroy srv-main
vagrant up srv-main

# 3. Identifier l'archive Borg la plus recente
BORG_RSH="ssh -i /root/.ssh/borg_key" borgmatic list

# 4. Restaurer les donnees
BORG_RSH="ssh -i /root/.ssh/borg_key" borgmatic restore \
  --repository borguser@192.168.50.20:/srv/borg/mediaschool \
  --archive latest

# 5. Relancer les services Docker
cd /vagrant && docker compose up -d
```

### Verification
- `docker ps` — tous les services running
- `curl http://localhost` — Nextcloud accessible
- `radtest etudiant1 Etudiant2026! localhost 0 testing123` — RADIUS OK

---

## Scenario 2 — Defaillance Serveur Complet (RTO: 8-24h, RPO: <1h)

### Detection
- Perte de ping vers 192.168.50.10
- Alertes Prometheus: InstanceDown pour SRV_MAIN
- Verification physique du serveur

### Restauration
```bash
# 1. Preparer une nouvelle VM de remplacement
vagrant up srv-main  # ou sur nouveau materiel

# 2. Copier la cle SSH Borg depuis le backup ou regenerer
ssh-keygen -t ed25519 -C 'borg-main' -f /root/.ssh/borg_key -N ''
# Ajouter la cle publique dans /home/borguser/.ssh/authorized_keys sur SRV_BACKUP

# 3. Lister les archives disponibles
BORG_PASSPHRASE='BorgIRIS2026!' borgmatic list \
  --repository borguser@192.168.50.20:/srv/borg/mediaschool

# 4. Restaurer
BORG_PASSPHRASE='BorgIRIS2026!' borgmatic restore \
  --repository borguser@192.168.50.20:/srv/borg/mediaschool \
  --archive latest --destination /

# 5. Relancer Docker
cd /vagrant && docker compose up -d

# 6. Reconnecter DRBD
drbdadm create-md mediaschool
drbdadm up mediaschool
drbdadm primary --force mediaschool  # UNIQUEMENT sur MAIN
```

---

## Scenario 3 — Corruption de Donnees (RTO: 1-2h, RPO: variable)

### Detection
- Erreurs applicatives dans logs Docker
- Rapport utilisateur de donnees corrompues
- Echec de verification Borgmatic

### Restauration d'archive specifique
```bash
# Lister les archives pour trouver le bon point de restauration
BORG_PASSPHRASE='BorgIRIS2026!' borg list \
  borguser@192.168.50.20:/srv/borg/mediaschool

# Exemple de sortie:
# iris-2025-10-15T10:00:00  Wed, 2025-10-15 10:00:00
# iris-2025-10-15T09:00:00  Wed, 2025-10-15 09:00:00

# Restaurer une archive specifique (point AVANT la corruption)
BORG_PASSPHRASE='BorgIRIS2026!' borg extract \
  borguser@192.168.50.20:/srv/borg/mediaschool::iris-2025-10-15T09:00:00 \
  /var/lib/docker/volumes

# Relancer les services
docker compose down && docker compose up -d
```

---

## Scenario 4 (PCA) — Defaillance Noeud MAIN — Basculement Automatique

> **Ce scenario ne necessite AUCUNE intervention humaine pour la continuite de service.**

### Declenchement Automatique
1. **SRV_MAIN tombe** (panne hardware, crash OS, reboot inopiné)
2. **Keepalived detecte** la perte des advertisements VRRP (timeout ~3 secondes)
3. **SRV_BACKUP passe MASTER** automatiquement (priorite 90, pas de preemption)
4. **VIP 192.168.50.50 migre** vers SRV_BACKUP (gratuitous ARP)
5. **Services continuent** sur la VIP — **RTO < 30 secondes**

### Verification apres basculement
```bash
# Depuis un poste admin: verifier que la VIP repond
ping 192.168.50.50

# Sur SRV_BACKUP: confirmer qu'il est MASTER
ip addr show enp0s8 | grep 192.168.50.50
# Doit afficher: inet 192.168.50.50/24 scope global secondary enp0s8

# Verifier les logs Keepalived
journalctl -u keepalived -n 20

# Tester les services via la VIP
curl http://192.168.50.50  # Nextcloud
```

### Etat DRBD pendant le failover
```bash
# Sur SRV_BACKUP: verifier l'etat DRBD
drbdadm status
# Pendant que MAIN est down: SRV_BACKUP sera Primary/Unknown
# Donnees integres (derniere sync synchrone)
```

### Procedure de Retour en Production (MAIN)
```bash
# 1. Demarrer SRV_MAIN
vagrant up srv-main  # ou demarrage physique

# 2. DRBD resynchronise automatiquement
drbdadm connect mediaschool
# Attendre la fin de sync: watch -n2 'cat /proc/drbd'

# 3. Keepalived sur MAIN reprend automatiquement le role MASTER
# (priorite 100 > 90 = preemption automatique)
systemctl start keepalived  # si necessaire

# 4. Verifier que VIP est revenue sur MAIN
ip addr show enp0s8 | grep 192.168.50.50
```

---

## Tableau RTO/RPO — Synthese

| Scenario | RTO | RPO | Automatique | Intervention |
|---|---|---|---|---|
| Defaillance disque | 4-6h | < 1h | Non | Remplacement + restore |
| Defaillance serveur | 8-24h | < 1h | Non | Reinstall + restore |
| Corruption donnees | 1-2h | Variable | Non | Restore archive specifique |
| **Panne noeud (PCA)** | **< 30s** | **0** | **Oui** | **Aucune** |