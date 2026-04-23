# -*- mode: ruby -*-
# RP06 — PRA/PCA IRIS Nice | NVTech
# 3 VMs: SRV_MAIN + SRV_BACKUP + SRV_MONITORING
# DRBD replication + Keepalived/VRRP

Vagrant.configure("2") do |config|

  # ── VM 1 : Serveur principal (actif) ──
  config.vm.define "srv-main" do |main|
    main.vm.box      = "ubuntu/jammy64"
    main.vm.hostname = "srv-main"

    # Interface VLAN 50 Management (vers switch Cisco)
    main.vm.network "public_network",
      ip: "192.168.50.10",
      netmask: "255.255.255.0",
      bridge: "USB2.0 Ethernet Adapter"

    # Interface de réplication DRBD (host-only interne)
    main.vm.network "private_network",
      ip: "192.168.56.10",
      netmask: "255.255.255.0",
      virtualbox__intnet: "drbd-net"

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

  # ── VM 2 : Serveur secondaire (standby + BorgBackup) ──
  config.vm.define "srv-backup" do |backup|
    backup.vm.box      = "ubuntu/jammy64"
    backup.vm.hostname = "srv-backup"

    backup.vm.network "public_network",
      ip: "192.168.50.20",
      netmask: "255.255.255.0",
      bridge: "USB2.0 Ethernet Adapter"

    backup.vm.network "private_network",
      ip: "192.168.56.20",
      netmask: "255.255.255.0",
      virtualbox__intnet: "drbd-net"

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

  # ── VM 3 : Supervision centralisée ──
  config.vm.define "srv-monitoring" do |mon|
    mon.vm.box      = "ubuntu/jammy64"
    mon.vm.hostname = "srv-monitoring"

    mon.vm.network "public_network",
      ip: "192.168.50.30",
      netmask: "255.255.255.0",
      bridge: "USB2.0 Ethernet Adapter"

    mon.vm.network "private_network",
      ip: "192.168.56.30",
      netmask: "255.255.255.0",
      virtualbox__intnet: "drbd-net"

    mon.vm.provider "virtualbox" do |vb|
      vb.name   = "SRV_MONITORING"
      vb.memory = 2048
      vb.cpus   = 2
    end

    mon.vm.provision "shell", path: "scripts/provision_monitoring.sh"
  end
end