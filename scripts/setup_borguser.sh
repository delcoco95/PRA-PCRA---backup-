#!/bin/bash
# Setup borguser sur SRV-BACKUP: créer dossier + autoriser clé SSH
PUBKEY="$1"

# Créer dossier backup
mkdir -p /backup/borg/main
chown -R borguser:borguser /backup/borg

# Autoriser la clé SSH
sudo -u borguser bash -c "
  mkdir -p /home/borguser/.ssh
  chmod 700 /home/borguser/.ssh
  echo '$PUBKEY' >> /home/borguser/.ssh/authorized_keys
  chmod 600 /home/borguser/.ssh/authorized_keys
"
echo "borguser setup OK"
ls -la /backup/borg/
