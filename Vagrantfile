# -*- mode: ruby -*-
# RP06 — PRA/PCA IRIS Nice | NVTech
# 3 VMs: SRV_MAIN + SRV_BACKUP + SRV_MONITORING
# DRBD replication + Keepalived/VRRP
#
# Reseau:
#   NIC1 (NAT)        : acces SSH Vagrant + port forwarding host
#   NIC2 (host-only)  : 192.168.50.x — management + services (adapter #3)
#   NIC3 (intnet)     : 192.168.56.x — replication DRBD + monitoring
#
# Acces depuis l'hote:
#   SRV_MAIN     Nextcloud   : http://localhost:8091
#   SRV_MAIN     GLPI        : http://localhost:8090
#   SRV_MAIN     phpLDAPadmin: http://localhost:8092
#   SRV_MAIN     Portainer   : https://localhost:9453
#   SRV_MONITORING Grafana   : http://localhost:3002
#   SRV_MONITORING Prometheus: http://localhost:9092
#   SRV_MONITORING Alertmgr  : http://localhost:9094

Vagrant.configure("2") do |config|

  # ── VM 1 : Serveur principal (actif) ──────────────────────────────────────
  config.vm.define "srv-main" do |main|
    main.vm.box      = "ubuntu/jammy64"
    main.vm.hostname = "srv-main"

    # NIC2 : public_network (Bridge USB) — réseau physique 192.168.50.x
    main.vm.network "public_network",
      ip: "192.168.50.10",
      netmask: "255.255.255.0",
      bridge: "USB2.0 Ethernet Adapter"

    # NIC3 : intnet DRBD 192.168.56.x
    main.vm.network "private_network",
      ip: "192.168.56.10",
      netmask: "255.255.255.0",
      virtualbox__intnet: "drbd-net"

    main.vm.network "forwarded_port", guest: 80,   host: 8091, id: "nextcloud"
    main.vm.network "forwarded_port", guest: 8090, host: 8090, id: "glpi"
    main.vm.network "forwarded_port", guest: 8080, host: 8092, id: "phpldapadmin"
    main.vm.network "forwarded_port", guest: 9443, host: 9453, id: "portainer"
    main.vm.network "forwarded_port", guest: 389,  host: 3890, id: "ldap"
    main.vm.network "forwarded_port", guest: 9100, host: 9101, id: "nodeexp-main"

    main.vm.provider "virtualbox" do |vb|
      vb.name   = "SRV_MAIN"
      vb.memory = 3072
      vb.cpus   = 2
      # Disque DRBD secondaire (10 Go)
      unless File.exist?("./disks/srv-main-drbd.vmdk")
        vb.customize ["createhd", "--filename", "./disks/srv-main-drbd.vmdk", "--size", 10240]
      end
      vb.customize ["storageattach", :id, "--storagectl", "SCSI",
                    "--port", "2", "--device", "0", "--type", "hdd",
                    "--medium", "./disks/srv-main-drbd.vmdk"]
    end

    main.vm.provision "shell", path: "scripts/provision_main.sh"
  end

  # ── VM 2 : Serveur secondaire (standby + BorgBackup) ──────────────────────
  config.vm.define "srv-backup" do |backup|
    backup.vm.box      = "ubuntu/jammy64"
    backup.vm.hostname = "srv-backup"

    # NIC2 : public_network (Bridge USB) — réseau physique 192.168.50.x
    backup.vm.network "public_network",
      ip: "192.168.50.20",
      netmask: "255.255.255.0",
      bridge: "USB2.0 Ethernet Adapter"

    # NIC3 : intnet DRBD 192.168.56.x
    backup.vm.network "private_network",
      ip: "192.168.56.20",
      netmask: "255.255.255.0",
      virtualbox__intnet: "drbd-net"

    backup.vm.network "forwarded_port", guest: 9100, host: 9102, id: "nodeexp-backup"

    backup.vm.provider "virtualbox" do |vb|
      vb.name   = "SRV_BACKUP"
      vb.memory = 3072
      vb.cpus   = 2
      # Disque DRBD secondaire (10 Go)
      unless File.exist?("./disks/srv-backup-drbd.vmdk")
        vb.customize ["createhd", "--filename", "./disks/srv-backup-drbd.vmdk", "--size", 10240]
      end
      vb.customize ["storageattach", :id, "--storagectl", "SCSI",
                    "--port", "2", "--device", "0", "--type", "hdd",
                    "--medium", "./disks/srv-backup-drbd.vmdk"]
    end

    backup.vm.provision "shell", path: "scripts/provision_backup.sh"
  end

  # ── VM 3 : Supervision centralisee ────────────────────────────────────────
  config.vm.define "srv-monitoring" do |mon|
    mon.vm.box      = "ubuntu/jammy64"
    mon.vm.hostname = "srv-monitoring"

    # NIC2 : public_network (Bridge USB) — réseau physique 192.168.50.x
    mon.vm.network "public_network",
      ip: "192.168.50.30",
      netmask: "255.255.255.0",
      bridge: "USB2.0 Ethernet Adapter"

    # NIC3 : intnet 192.168.56.x (scrape Node Exporter des autres VMs)
    mon.vm.network "private_network",
      ip: "192.168.56.30",
      netmask: "255.255.255.0",
      virtualbox__intnet: "drbd-net"

    # Port forwarding monitoring (acces depuis hote)
    mon.vm.network "forwarded_port", guest: 3000, host: 3002, id: "grafana"
    mon.vm.network "forwarded_port", guest: 9090, host: 9092, id: "prometheus"
    mon.vm.network "forwarded_port", guest: 9093, host: 9094, id: "alertmanager"
    mon.vm.network "forwarded_port", guest: 9100, host: 9103, id: "nodeexp-mon"

    mon.vm.provider "virtualbox" do |vb|
      vb.name   = "SRV_MONITORING"
      vb.memory = 2048
      vb.cpus   = 2
    end

    mon.vm.provision "shell", path: "scripts/provision_monitoring.sh"
  end
end