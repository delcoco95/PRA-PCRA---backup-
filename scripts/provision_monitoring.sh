#!/bin/bash
set -e
echo "[MONITORING] === Provisioning SRV_MONITORING ==="

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y wget curl net-tools apt-transport-https software-properties-common gnupg

# Prometheus
useradd -rs /bin/false prometheus 2>/dev/null || true
mkdir -p /etc/prometheus /var/lib/prometheus
wget -q https://github.com/prometheus/prometheus/releases/download/v2.54.1/prometheus-2.54.1.linux-amd64.tar.gz
tar xf prometheus-*.tar.gz
cp prometheus-*/prometheus prometheus-*/promtool /usr/local/bin/
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
rm -rf prometheus-*

cat > /etc/prometheus/prometheus.yml << 'PROMEOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']
rule_files:
  - /etc/prometheus/alerts.yml
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node-main'
    static_configs:
      - targets: ['192.168.56.10:9100']
        labels:
          instance: 'SRV_MAIN'
  - job_name: 'node-backup'
    static_configs:
      - targets: ['192.168.56.20:9100']
        labels:
          instance: 'SRV_BACKUP'
  - job_name: 'node-monitoring'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'SRV_MONITORING'
PROMEOF

cat > /etc/prometheus/alerts.yml << 'ALERTEOF'
groups:
  - name: infrastructure
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} DOWN"
      - alert: DRBDOutOfSync
        expr: drbd_disk_state != 4
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "DRBD hors synchronisation"
      - alert: BackupDiskFull
        expr: (node_filesystem_avail_bytes{mountpoint="/srv"} / node_filesystem_size_bytes{mountpoint="/srv"}) < 0.15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disque backup > 85% - espace insuffisant"
ALERTEOF

cat > /etc/systemd/system/prometheus.service << 'SVCEOF'
[Unit]
Description=Prometheus
After=network.target
[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus --web.listen-address=0.0.0.0:9090
[Install]
WantedBy=multi-user.target
SVCEOF

wget -q https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar xf alertmanager-*.tar.gz
cp alertmanager-*/alertmanager /usr/local/bin/
mkdir -p /etc/alertmanager
rm -rf alertmanager-*

cat > /etc/alertmanager/alertmanager.yml << 'AMEOF'
global:
  resolve_timeout: 5m
route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: 'webhook-iris'
receivers:
  - name: 'webhook-iris'
    webhook_configs:
      - url: 'http://192.168.50.10:5001/alert'
        send_resolved: true
AMEOF

cat > /etc/systemd/system/alertmanager.service << 'SVCEOF'
[Unit]
Description=Alertmanager
After=network.target
[Service]
ExecStart=/usr/local/bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --web.listen-address=0.0.0.0:9093
[Install]
WantedBy=multi-user.target
SVCEOF

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

wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt-get update -qq && apt-get install -y grafana

systemctl daemon-reload
for svc in prometheus alertmanager node_exporter grafana-server; do
  systemctl enable --now $svc 2>/dev/null || true
done
# Attendre que Grafana soit pret avant de changer le mot de passe
sleep 8
grafana-cli --homepath /usr/share/grafana admin reset-admin-password 'Grafana_IRIS_2026!' 2>/dev/null || true

apt-get install -y ufw
ufw allow 22/tcp
ufw allow 9090/tcp
ufw allow 9093/tcp
ufw allow 9100/tcp
ufw allow 3000/tcp
ufw --force enable

echo "[MONITORING] === Provisioning termine ==="
echo "[INFO] Grafana: http://192.168.50.30:3000 - admin / Grafana_IRIS_2026!"
echo "[INFO] Prometheus: http://192.168.50.30:9090"
echo "[INFO] Alertmanager: http://192.168.50.30:9093"
