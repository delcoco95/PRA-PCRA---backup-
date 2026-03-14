# Conception et mise en place d'un PRA/PCRA avec automatisation des sauvegardes — Campus Mediaschool

## 📋 Contexte

Dans le cadre d'un projet BTS SIO option SISR, réponse à un appel d'offre du campus Mediaschool pour la conception et le déploiement d'un Plan de Reprise d'Activité (PRA) et d'un Plan de Continuité de Reprise d'Activité (PCRA). L'objectif était de garantir la continuité des services informatiques en cas de sinistre, avec une stratégie de sauvegarde automatisée et testée.

> ⚠️ **Note :** Ce projet est en cours de finalisation. L'architecture et la documentation sont produites, les tests de validation seront effectués avant fin mars 2026 suite à la validation de l'appel d'offre par le client.

---

## 🎯 Objectif

Concevoir et déployer une solution PRA/PCRA permettant de :
- Définir les RTO (Recovery Time Objective) et RPO (Recovery Point Objective) pour chaque service critique
- Automatiser les sauvegardes des données et configurations
- Tester et valider les procédures de reprise en environnement virtuel
- Produire une documentation technique complète transmissible à l'équipe

---

## 🛠️ Technologies utilisées

| Technologie | Rôle |
|---|---|
| Debian / Ubuntu Linux | Système d'exploitation des VMs de test |
| Oracle VirtualBox | Environnement de virtualisation pour les tests |
| Bash / Scripts shell | Automatisation des sauvegardes |
| Rsync | Synchronisation et sauvegarde des données |
| Cron | Planification des sauvegardes automatiques |
| Git | Versioning des scripts et configurations |

---

## ⚙️ Architecture prévue

### Stratégie de sauvegarde (règle 3-2-1)

```
3 copies des données
├── 1 copie locale (serveur principal)
├── 1 copie sur NAS dédié (réseau local)
└── 1 copie hors site (cloud ou site distant)

2 supports différents
└── Disque local + NAS réseau

1 copie hors site
└── Sauvegarde distante chiffrée
```

### Niveaux de sauvegarde

| Type | Fréquence | Rétention |
|---|---|---|
| Sauvegarde complète | Hebdomadaire (dimanche 2h00) | 4 semaines |
| Sauvegarde incrémentale | Quotidienne (lundi-samedi 2h00) | 7 jours |
| Sauvegarde de configuration | À chaque modification | 30 versions |

### Objectifs RTO / RPO définis

| Service | RTO cible | RPO cible |
|---|---|---|
| Services réseau critiques | < 4 heures | < 24 heures |
| Données utilisateurs | < 8 heures | < 24 heures |
| Infrastructure complète | < 24 heures | < 48 heures |

---

## ⚙️ Ce qui a été réalisé

### 1. Analyse et cartographie
- Inventaire des services et données critiques du campus
- Définition des RTO/RPO par service
- Identification des points de défaillance uniques (SPOF)

### 2. Scripts d'automatisation des sauvegardes

```bash
#!/bin/bash
# backup_auto.sh — Sauvegarde automatisée quotidienne

DATE=$(date +%Y%m%d_%H%M%S)
SOURCE="/data/services"
DEST_LOCAL="/backup/local/$DATE"
DEST_NAS="/mnt/nas/backup/$DATE"
LOG="/var/log/backup.log"

# Sauvegarde locale
rsync -avz --delete "$SOURCE" "$DEST_LOCAL" >> "$LOG" 2>&1

# Copie vers NAS
rsync -avz "$DEST_LOCAL" "$DEST_NAS" >> "$LOG" 2>&1

# Nettoyage des sauvegardes > 30 jours
find /backup/local -mtime +30 -exec rm -rf {} \;

echo "[$DATE] Sauvegarde terminée" >> "$LOG"
```

### 3. Planification Cron

```bash
# /etc/cron.d/backup_mediaschool
0 2 * * 0 root /opt/scripts/backup_full.sh      # Complète le dimanche
0 2 * * 1-6 root /opt/scripts/backup_incremental.sh  # Incrémentale lun-sam
```

### 4. Documentation produite
- Procédure de déclenchement du PRA (étapes pas à pas)
- Procédure de restauration par type de sinistre
- Matrice de responsabilités en cas d'incident
- Fiche de test PRA (à compléter lors des tests de validation)

---

## 📋 Tests prévus (avant fin mars 2026)

| Test | Description | Statut |
|---|---|---|
| Test de restauration fichiers | Restaurer un fichier supprimé accidentellement | ⏳ À réaliser |
| Test de restauration VM | Recréer une VM depuis une sauvegarde | ⏳ À réaliser |
| Simulation de panne serveur | Basculement sur environnement de secours | ⏳ À réaliser |
| Validation des délais RTO | Mesure du temps de reprise réel vs objectif | ⏳ À réaliser |

---

## 🔗 Compétences BTS SIO mobilisées

| Compétence | Description |
|---|---|
| **B1.1** | Gérer le patrimoine informatique (politique de sauvegarde, inventaire) |
| **B1.2** | Répondre aux incidents (PRA = réponse à un incident majeur) |
| **B1.4** | Travailler en mode projet (conception, planning, documentation) |
| **B1.5** | Mettre à disposition des utilisateurs un service informatique |

---

## 👤 Auteur

**Nedjmeddine Belloum** — BTS SIO option SISR  
Centre de formation : Mediaschool Nice — IRIS  
Période : En cours (finalisation avant fin mars 2026)  
Portfolio : [https://delcoco95.github.io/mon-portfolio/](https://delcoco95.github.io/mon-portfolio/)
