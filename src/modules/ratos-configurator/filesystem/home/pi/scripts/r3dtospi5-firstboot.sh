#!/bin/bash
# ============================================================
# R3DTOS PI5 — First Boot Setup Script
# Runs once on first boot via the r3dtospi5-firstboot service.
# Port of RatOS v2.1.x stack for Raspberry Pi OS / Pi 5 (see README).
# Handles things that cannot be done inside the chroot build:
#   - Expand filesystem
#   - Set machine hostname uniquely
#   - Generate SSH host keys
#   - Final service starts
# ============================================================
set -e

# Short hostname baked into the image (must match BASE_HOSTNAME in src/config).
DEFAULT_HOST="r3dtospi5"

LOG=/var/log/r3dtospi5-firstboot.log
exec > >(tee -a ${LOG}) 2>&1

echo "============================================"
echo "R3DTOS PI5 First Boot Setup"
echo "Started: $(date)"
echo "============================================"

# ── SSH: Pi OS may leave `pi` on nologin (password OK but "account not available") ─
echo "[0/7] Ensuring user pi has an interactive login shell..."
if id -u pi >/dev/null 2>&1; then
    _pishell=$(getent passwd pi | cut -d: -f7)
    case "${_pishell}" in
        /usr/sbin/nologin|/sbin/nologin|/bin/false|"")
            echo "  Adjusting pi shell from '${_pishell:-empty}' → /bin/bash"
            usermod -s /bin/bash pi
            ;;
        *)
            echo "  pi shell already: ${_pishell}"
            ;;
    esac
fi

# ── Wireless: ensure not soft-blocked (common on fresh images / some boards) ─
echo "[1/7] Unblocking rfkill (WiFi)..."
rfkill unblock all 2>/dev/null || true

# ModemManager can capture USB-serial devices used for printer flashing; keep it off.
systemctl stop ModemManager 2>/dev/null || true
systemctl disable ModemManager 2>/dev/null || true
systemctl mask ModemManager 2>/dev/null || true

# ── Expand root filesystem ───────────────────────────────────
echo "[2/7] Expanding filesystem..."
raspi-config --expand-rootfs || true

# ── Set unique hostname ───────────────────────────────────────
# Appends last 4 chars of Pi serial for uniqueness on networks
# with multiple R3DTOS PI5 instances.
echo "[3/7] Setting hostname..."
SERIAL=$(grep -m1 '^Serial' /proc/cpuinfo 2>/dev/null | awk '{print $3}' | tail -c 5 | head -c 4)
if [ -z "${SERIAL}" ] || [ "${SERIAL}" = "0000" ]; then
    # Pi 5 / newer kernels: full serial in device tree (hex string)
    DT_SERIAL=$(tr -d '\0' </proc/device-tree/serial-number 2>/dev/null || true)
    if [ -n "${DT_SERIAL}" ]; then
        SERIAL=$(echo -n "${DT_SERIAL}" | tail -c 4)
    fi
fi
if [ -n "${SERIAL}" ] && [ "${SERIAL}" != "0000" ]; then
    NEW_HOSTNAME="${DEFAULT_HOST}-${SERIAL}"
else
    NEW_HOSTNAME="${DEFAULT_HOST}"
fi

echo "${NEW_HOSTNAME}" > /etc/hostname
sed -i "s/${DEFAULT_HOST}/${NEW_HOSTNAME}/g" /etc/hosts

# Update moonraker.conf with new hostname
sed -i "s/${DEFAULT_HOST}.local/${NEW_HOSTNAME}.local/g" \
    /home/pi/printer_data/config/moonraker.conf

# Update RatOS configurator .env.local (root copy optional; src is canonical)
for _cfg_env in /home/pi/ratos-configurator/.env.local /home/pi/ratos-configurator/src/.env.local; do
    if [ -f "${_cfg_env}" ]; then
        sed -i "s/${DEFAULT_HOST}.local/${NEW_HOSTNAME}.local/g" "${_cfg_env}"
    fi
done

if [ -f /home/pi/mainsail/config.json ]; then
    sed -i "s/${DEFAULT_HOST}.local/${NEW_HOSTNAME}.local/g" /home/pi/mainsail/config.json
fi

# Hotspot AP uses 192.168.50.1; dnsmasq hands clients DHCP but they need this name
# to resolve to the Pi so Mainsail (Moonraker host from config.json) connects reliably.
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/r3dtospi5-hotspot-local.conf << EOF
# Written by r3dtospi5-firstboot — autohotspot wlan0 subnet
address=/${NEW_HOSTNAME}.local/192.168.50.1
EOF

echo "Hostname set to: ${NEW_HOSTNAME}"

# ── Regenerate SSH host keys ──────────────────────────────────
# Never leave the system without host keys: with `set -e`, a failed
# `dpkg-reconfigure` after `rm` would exit the script and sshd would
# refuse all connections until fixed from local console.
echo "[4/7] Regenerating SSH host keys..."
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true
if ! ssh-keygen -A; then
    echo "WARN: ssh-keygen -A failed; attempting dpkg-reconfigure..."
    dpkg-reconfigure -f noninteractive openssh-server || true
fi
systemctl enable ssh 2>/dev/null || true
systemctl enable ssh.socket 2>/dev/null || true
systemctl restart ssh 2>/dev/null || systemctl start ssh 2>/dev/null || true

# ── Set correct ownership on printer_data ────────────────────
echo "[5/7] Setting file ownership..."
mkdir -p /home/pi/printer_data/ratos /home/pi/printer_data/logs /home/pi/timelapse
touch /home/pi/printer_data/logs/sonar.log
chown -R pi:pi /home/pi/printer_data
chown -R pi:pi /home/pi/timelapse
chown -R pi:pi /home/pi/ratos-configurator
chown -R pi:pi /home/pi/klipper
chown -R pi:pi /home/pi/moonraker
[ -d /home/pi/mainsail ] && chown -R pi:pi /home/pi/mainsail

# ── Enable mDNS / Avahi ───────────────────────────────────────
echo "[6/7] Enabling Avahi mDNS..."
systemctl enable avahi-daemon
systemctl start avahi-daemon

# ── Start all services ────────────────────────────────────────
echo "[7/7] Starting R3DTOS PI5 services..."
systemctl daemon-reload
systemctl start klipper
sleep 3
systemctl start moonraker
sleep 3
systemctl start ratos-configurator
systemctl restart nginx

# ── Enable auto-hotspot after first boot (avoids fighting NM during initial bring-up) ─
if systemctl list-unit-files autohotspot.service 2>/dev/null | grep -q autohotspot.service; then
  echo "[post] Enabling autohotspot.service for subsequent boots..."
  systemctl enable autohotspot.service 2>/dev/null || true
  # Oneshot unit — start once now so fallback AP works without an extra reboot.
  systemctl start autohotspot.service 2>/dev/null || true
fi

# ── Disable this service so it never runs again ───────────────
systemctl disable r3dtospi5-firstboot.service

# ── SSH safety net (if a later step failed, ssh may still need a kick) ─
systemctl enable ssh ssh.socket 2>/dev/null || true
systemctl is-active --quiet ssh || systemctl start ssh 2>/dev/null || true

echo "============================================"
echo "R3DTOS PI5 First Boot Complete: $(date)"
echo "First-run: open http://${NEW_HOSTNAME}.local/ → RatOS wizard /configure/wizard/ (printer profile + hardware)."
echo "After setup: sudo r3dtos-wizard-complete  (then / opens Mainsail). Mainsail early: http://${NEW_HOSTNAME}.local/index.html"
echo "Configurator: http://${NEW_HOSTNAME}.local/configure/  |  Wizard: .../configure/wizard/"
echo "On fallback hotspot Wi-Fi: http://192.168.50.1 (same / → configurator until wizard complete)"
echo "============================================"
