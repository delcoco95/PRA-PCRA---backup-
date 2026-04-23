#!/bin/bash
set -e
echo "[MAIN] === Provisioning SRV_MAIN ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get upgrade -y -qq

apt-get install -y drbd-utils keepalived borgbackup borgmatic docker.io docker-compose-v2 curl wget net-tools ufw

usermod -aG docker vagrant

cd /vagrant && docker compose up -d

if [ ! -f /root/.ssh/borg_key ]; then
  mkdir -p /root/.ssh
  ssh-keygen -t ed25519 -C 'borg-main' -f /root/.ssh/borg_key -N ''
fi

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
ExecStart=/usr/local/bin/node_exporter --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
[Install]
WantedBy=multi-user.target
SVCEOF
mkdir -p /var/lib/node_exporter/textfile_collector
systemctl daemon-reload && systemctl enable --now node_exporter

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

cat > /etc/keepalived/keepalived.conf << 'KVEOF'
vrrp_script chk_services {
  script "/usr/local/bin/check_services.sh"
  interval 5
  weight -20
}
vrrp_instance VI_1 {
  state MASTER
  interface enp0s8
  virtual_router_id 51
  priority 100
  advert_int 1
  authentication {
    auth_type PASS
    auth_pass VRRP_IRIS_2026!
  }
  virtual_ipaddress {
    192.168.50.50/24
  }
  track_script {
    chk_services
  }
}
KVEOF

cat > /usr/local/bin/check_services.sh << 'CHKEOF'
#!/bin/bash
docker inspect --format='{{.State.Running}}' freeradius 2>/dev/null | grep -q true || exit 1
docker inspect --format='{{.State.Running}}' openldap 2>/dev/null | grep -q true || exit 1
exit 0
CHKEOF
chmod +x /usr/local/bin/check_services.sh
systemctl enable --now keepalived

mkdir -p /etc/borgmatic
cat > /etc/borgmatic/config.yaml << 'BORGEOF'
location:
  source_directories:
    - /home/vagrant
    - /etc
    - /var/lib/docker/volumes
  repositories:
    - borguser@192.168.50.20:/srv/borg/mediaschool
storage:
  encryption_passphrase: 'BorgIRIS2026!'
  compression: lz4
  ssh_command: ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no
retention:
  keep_hourly: 24
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 6
hooks:
  before_backup:
    - echo "=== Backup demarre $(date) ===" >> /var/log/borgmatic.log
  after_backup:
    - echo "=== Backup termine $(date) ===" >> /var/log/borgmatic.log
  on_error:
    - echo "=== ERREUR backup $(date) ===" >> /var/log/borg-errors.log
BORGEOF

echo "0 * * * * root borgmatic --verbosity 0 2>> /var/log/borg-errors.log" > /etc/cron.d/borgmatic

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 389/tcp
ufw allow 636/tcp
ufw allow 1812/udp
ufw allow 1813/udp
ufw allow 7789/tcp
ufw allow 9100/tcp
ufw allow 51820/udp
ufw allow 51821/tcp
ufw --force enable

echo "[MAIN] === Provisioning termine ==="
echo "[INFO] Cle publique Borg a copier sur SRV_BACKUP:"
cat /root/.ssh/borg_key.pub
