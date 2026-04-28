#!/bin/bash
# Setup BorgBackup: génère clé SSH root si absente et affiche la clé publique
if [ ! -f /root/.ssh/id_rsa ]; then
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
  echo "KEY_CREATED"
else
  echo "KEY_EXISTS"
fi
cat /root/.ssh/id_rsa.pub
