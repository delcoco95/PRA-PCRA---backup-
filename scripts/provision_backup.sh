#!/bin/bash
set -e
echo "[BACKUP] === Provisioning SRV_BACKUP ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y drbd-utils keepalived borgbackup curl wget net-tools ufw

useradd -m -s /bin/bash borguser 2>/dev/null || true
mkdir -p /srv/borg/mediaschool
chown -R borguser:borguser /srv/borg
mkdir -p /home/borguser/.ssh
chmod 700 /home/borguser/.ssh
chown borguser:borguser /home/borguser/.ssh

# Node Exporter
useradd -rs /bin/false node_exporter 2>/dev/null || true
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz
tar xf node_exporter-*.tar.gz
cp node_exporter-*/node_exporter /usr/local/bin/
rm -rf node_exporter-*
cat > /etc/systemd/system/node_exporter.service << 'SVCEOF'
[Unit]
Description=Node Exporter
After=network.target
[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload && systemctl enable --now node_exporter

# DRBD configuration
cat > /etc/drbd.d/mediaschool.res << 'DRBDEOF'
resource mediaschool {
  protocol C;
  device /dev/drbd1;
  disk /dev/sdb;
  meta-disk internal;
  on srv-main {
    address 192.168.56.10:7789;
  }
  on srv-backup {
    address 192.168.56.20:7789;
  }
}
DRBDEOF

# Keepalived BACKUP
cat > /etc/keepalived/keepalived.conf << 'KVEOF'
vrrp_instance VI_1 {
  state BACKUP
  interface enp0s8
  virtual_router_id 51
  priority 90
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass VRRP_IRIS_2026!
  }
  virtual_ipaddress {
    192.168.50.50/24
  }
}
KVEOF
systemctl enable --now keepalived

ufw allow 22/tcp
ufw allow 9100/tcp
ufw allow 7789/tcp
ufw --force enable

echo "[BACKUP] === Provisioning termine ==="
echo "[ACTION REQUISE] Copier la cle SSH de SRV_MAIN dans /home/borguser/.ssh/authorized_keys"
