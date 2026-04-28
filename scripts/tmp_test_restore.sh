#!/bin/bash
export BORG_RSH='ssh -i /home/vagrant/.ssh/borg_key -o StrictHostKeyChecking=no'
export BORG_PASSPHRASE='BorgIRIS2026!'
REPO="borguser@192.168.50.20:/srv/borg/mediaschool"

echo "=== ETAPE 1 : Creation donnees test ==="
mkdir -p /home/vagrant/donnees-critiques
echo "fichier important - $(date)" > /home/vagrant/donnees-critiques/test.txt
echo "config serveur" > /home/vagrant/donnees-critiques/config.conf
ls /home/vagrant/donnees-critiques/

echo "=== ETAPE 2 : Backup borgmatic ==="
sudo borgmatic --verbosity 1 2>&1 | tail -5

echo "=== ETAPE 3 : Liste des archives ==="
borg list $REPO

echo "=== ETAPE 4 : Suppression des donnees ==="
rm -rf /home/vagrant/donnees-critiques
echo "Supprime : $(ls /home/vagrant/donnees-critiques 2>&1)"

echo "=== ETAPE 5 : Restauration ==="
ARCHIVE=$(borg list $REPO --short | tail -1)
echo "Archive selectionnee : $ARCHIVE"
rm -rf /tmp/restauration && mkdir -p /tmp/restauration
cd /tmp/restauration
borg extract ${REPO}::${ARCHIVE} home/vagrant/donnees-critiques

echo "=== ETAPE 6 : Verification ==="
echo "Fichiers restaures :"
ls -la /tmp/restauration/home/vagrant/donnees-critiques/
cat /tmp/restauration/home/vagrant/donnees-critiques/test.txt
echo "=== TEST RESTAURATION OK ==="
