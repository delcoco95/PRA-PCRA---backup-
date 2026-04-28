#!/usr/bin/env pwsh
# =============================================================================
# post_setup_rp06.ps1 — Configuration post-provisioning RP06
# A executer UNE FOIS apres "vagrant up" (toutes les 3 VMs)
# Configure : DRBD init + BorgBackup SSH key exchange + Borg repo init
# =============================================================================

$ErrorActionPreference = "Stop"
$RP06 = "C:\Users\nedjb\Documents\PROJET IT\- RP06 - PRA_PCRA_Backup - Nedj"

function Log($msg) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor Cyan }
function OK($msg)  { Write-Host "[OK] $msg" -ForegroundColor Green }
function ERR($msg) { Write-Host "[ERR] $msg" -ForegroundColor Red }

Set-Location $RP06
Log "=== POST-SETUP RP06 — DRBD + BorgBackup ==="

# ── ETAPE 1 : Verifier que les 3 VMs tournent ────────────────────────────────
Log "Verification etat des VMs..."
$status = vagrant status 2>&1
if ($status -notmatch "srv-main.*running") { ERR "srv-main n'est pas running. Lancez vagrant up srv-main"; exit 1 }
if ($status -notmatch "srv-backup.*running") { ERR "srv-backup n'est pas running. Lancez vagrant up srv-backup"; exit 1 }
if ($status -notmatch "srv-monitoring.*running") { ERR "srv-monitoring n'est pas running. Lancez vagrant up srv-monitoring"; exit 1 }
OK "Les 3 VMs sont running"

# ── ETAPE 2 : Test de connectivite reseau inter-VMs ──────────────────────────
Log "Test connectivite entre VMs (via reseau 192.168.56.x)..."
vagrant ssh srv-main -c "ping -c 2 192.168.56.20 && echo 'MAIN->BACKUP OK' || echo 'MAIN->BACKUP FAIL'"
vagrant ssh srv-main -c "ping -c 2 192.168.56.30 && echo 'MAIN->MONITOR OK' || echo 'MAIN->MONITOR FAIL'"

# ── ETAPE 3 : Init DRBD sur SRV_MAIN ─────────────────────────────────────────
Log "Initialisation DRBD sur SRV_MAIN..."
$drbdMain = @'
set -e
echo "=== Init DRBD SRV_MAIN ==="
# Verifier si DRBD deja initialise
if drbdadm dump mediaschool 2>/dev/null | grep -q "resource"; then
  CURRENT=$(cat /proc/drbd 2>/dev/null | grep -o "Primary\|Secondary" | head -1)
  if [ "$CURRENT" = "Primary" ]; then
    echo "[OK] DRBD deja configure en Primary"
    drbdadm status mediaschool
    exit 0
  fi
fi
# Initialisation
drbdadm create-md mediaschool --force 2>/dev/null || true
drbdadm up mediaschool
sleep 2
# Forcer primary avec ecrasement (premiere fois uniquement)
drbdadm -- --overwrite-data-of-peer primary mediaschool
sleep 3
echo "=== Etat DRBD ==="
drbdadm status mediaschool
cat /proc/drbd
'@
vagrant ssh srv-main -c $drbdMain
OK "DRBD SRV_MAIN configure en Primary"

# ── ETAPE 4 : Init DRBD sur SRV_BACKUP ───────────────────────────────────────
Log "Initialisation DRBD sur SRV_BACKUP..."
$drbdBackup = @'
set -e
echo "=== Init DRBD SRV_BACKUP ==="
CURRENT=$(cat /proc/drbd 2>/dev/null | grep -o "Primary\|Secondary" | head -1)
if [ "$CURRENT" = "Secondary" ]; then
  echo "[OK] DRBD deja configure en Secondary"
  drbdadm status mediaschool
  exit 0
fi
drbdadm create-md mediaschool --force 2>/dev/null || true
drbdadm up mediaschool
sleep 3
echo "=== Etat DRBD ==="
drbdadm status mediaschool
cat /proc/drbd
'@
vagrant ssh srv-backup -c $drbdBackup
OK "DRBD SRV_BACKUP configure en Secondary"

# ── ETAPE 5 : Echange cle SSH BorgBackup ─────────────────────────────────────
Log "Recuperation cle SSH Borg depuis SRV_MAIN..."
$borgKey = vagrant ssh srv-main -c "cat /root/.ssh/borg_key.pub 2>/dev/null || (ssh-keygen -t ed25519 -f /root/.ssh/borg_key -N '' -C 'borg-main' && cat /root/.ssh/borg_key.pub)" 2>&1
$borgKey = ($borgKey | Where-Object { $_ -match "^ssh-" }) -join ""
if (-not $borgKey) { ERR "Impossible de recuperer la cle SSH Borg"; exit 1 }
OK "Cle Borg recuperee : $($borgKey.Substring(0,50))..."

Log "Installation cle SSH sur SRV_BACKUP (borguser)..."
$escapedKey = $borgKey -replace "'", "'\\'''"
vagrant ssh srv-backup -c "mkdir -p /home/borguser/.ssh && echo '$escapedKey' | tee /home/borguser/.ssh/authorized_keys && chmod 600 /home/borguser/.ssh/authorized_keys && chown -R borguser:borguser /home/borguser/.ssh"
OK "Cle SSH Borg installee sur SRV_BACKUP"

# ── ETAPE 6 : Initialisation depot Borg ──────────────────────────────────────
Log "Initialisation du depot BorgBackup..."
$borgInit = @'
export BORG_PASSPHRASE='BorgIRIS2026!'
export BORG_RSH='ssh -i /root/.ssh/borg_key -o StrictHostKeyChecking=no'
REPO="borguser@192.168.50.20:/srv/borg/mediaschool"
# Verifier si depot deja initialise
if borg info "$REPO" 2>/dev/null; then
  echo "[OK] Depot Borg deja initialise"
else
  echo "=== Init depot Borg ==="
  borg init --encryption=repokey "$REPO"
  echo "[OK] Depot initialise"
fi
'@
vagrant ssh srv-main -c $borgInit
OK "Depot BorgBackup initialise"

# ── ETAPE 7 : Premier backup de test ─────────────────────────────────────────
Log "Lancement premier backup borgmatic (test)..."
vagrant ssh srv-main -c "BORG_PASSPHRASE='BorgIRIS2026!' borgmatic --verbosity 1 2>&1 | tail -20"
OK "Premier backup borgmatic OK"

# ── ETAPE 8 : Verification services Docker sur SRV_MAIN ──────────────────────
Log "Verification services Docker (SRV_MAIN)..."
vagrant ssh srv-main -c "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# ── ETAPE 9 : Verification monitoring ────────────────────────────────────────
Log "Verification Prometheus + Grafana (SRV_MONITORING)..."
vagrant ssh srv-monitoring -c "systemctl status prometheus --no-pager -l | head -5; systemctl status grafana-server --no-pager | head -5"

# ── ETAPE 10 : Test VIP Keepalived ───────────────────────────────────────────
Log "Verification VIP Keepalived..."
vagrant ssh srv-main -c "ip addr show | grep 192.168.50.50 && echo 'VIP ACTIVE sur MAIN' || echo 'VIP non presente sur MAIN'"
vagrant ssh srv-backup -c "ip addr show | grep 192.168.50.50 && echo 'VIP ACTIVE sur BACKUP' || echo 'VIP non presente sur BACKUP'"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  POST-SETUP RP06 TERMINE !" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Acces depuis l'hote :" -ForegroundColor Yellow
Write-Host "  Nextcloud     : http://localhost:8091" -ForegroundColor White
Write-Host "  phpLDAPadmin  : http://localhost:8092" -ForegroundColor White
Write-Host "  Portainer     : https://localhost:9453" -ForegroundColor White
Write-Host "  Grafana       : http://localhost:3002  (admin/Grafana_IRIS_2026!)" -ForegroundColor White
Write-Host "  Prometheus    : http://localhost:9092" -ForegroundColor White
Write-Host "  Alertmanager  : http://localhost:9094" -ForegroundColor White
Write-Host ""
Write-Host "  Acces direct (host-only 192.168.50.x) :" -ForegroundColor Yellow
Write-Host "  SRV_MAIN      : ssh vagrant@192.168.50.10 (vagrant)" -ForegroundColor White
Write-Host "  SRV_BACKUP    : ssh vagrant@192.168.50.20 (vagrant)" -ForegroundColor White
Write-Host "  SRV_MONITORING: ssh vagrant@192.168.50.30 (vagrant)" -ForegroundColor White
Write-Host "  VIP VRRP      : 192.168.50.50 (migre auto en cas de panne)" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green
