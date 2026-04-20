#!/bin/bash
# ============================================================
# RatOS PI5 â€” First Boot Setup Script
# Runs once on first boot via the ratos-firstboot service.
# Raspberry Pi OS image derived from the RatOS v2.1.x ecosystem (see README for upstream credit).
# Handles things that cannot be done inside the chroot build:
#   - Expand filesystem
#   - Set machine hostname uniquely
#   - Generate SSH host keys
#   - Final service starts
# ============================================================
set -e

# Short hostname baked into the image (must match BASE_HOSTNAME in src/config).
DEFAULT_HOST="ratos"

LOG=/var/log/ratos-firstboot.log
exec > >(tee -a ${LOG}) 2>&1

echo "============================================"
echo "RatOS PI5 First Boot Setup"
echo "Started: $(date)"
echo "============================================"

# â”€â”€ SSH: Pi OS may leave `pi` on nologin (password OK but "account not available") â”€
echo "[0/7] Ensuring user pi has an interactive login shell..."
if id -u pi >/dev/null 2>&1; then
    _pishell=$(getent passwd pi | cut -d: -f7)
    case "${_pishell}" in
        /usr/sbin/nologin|/sbin/nologin|/bin/false|"")
            echo "  Adjusting pi shell from '${_pishell:-empty}' â†’ /bin/bash"
            usermod -s /bin/bash pi
            ;;
        *)
            echo "  pi shell already: ${_pishell}"
            ;;
    esac
fi

# â”€â”€ Wireless: ensure not soft-blocked (common on fresh images / some boards) â”€
echo "[1/7] Unblocking rfkill (WiFi)..."
rfkill unblock all 2>/dev/null || true

# ModemManager can capture USB-serial devices used for printer flashing; keep it off.
systemctl stop ModemManager 2>/dev/null || true
systemctl disable ModemManager 2>/dev/null || true
systemctl mask ModemManager 2>/dev/null || true

# â”€â”€ Expand root filesystem â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo "[2/7] Expanding filesystem..."
raspi-config --expand-rootfs || true

# â”€â”€ Set hostname â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Plain "ratos" so http://ratos.local/ resolves on every fresh flash â€” matches the
# RatOS first-boot UX. mDNS (Avahi) auto-appends "-2"/"-3" on the rare LAN with multiple
# RatOS Pis, so collisions self-resolve without baking serial suffixes into the image.
# The user can rename via the Configurator's hostname step, which persists through
# hostnamectl + /etc/hosts rewrite just like upstream.
echo "[3/7] Setting hostname..."
NEW_HOSTNAME="${DEFAULT_HOST}"

echo "${NEW_HOSTNAME}" > /etc/hostname
# sudo resolves gethostname() via NSS: kernel name, /etc/hosts and /etc/hostname must agree
# or NOPASSWD sudo (iw, scripts) starts failing with "unable to resolve host".
hostnamectl set-hostname "${NEW_HOSTNAME}" 2>/dev/null || hostname "${NEW_HOSTNAME}"

# Update moonraker.conf with new hostname
sed -i "s/${DEFAULT_HOST}.local/${NEW_HOSTNAME}.local/g" \
    /home/pi/printer_data/config/moonraker.conf

# RatOS Configurator .env.local (root copy optional; src is canonical)
for _cfg_env in /home/pi/configurator/.env.local /home/pi/configurator/src/.env.local; do
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
cat > /etc/dnsmasq.d/ratos-hotspot-local.conf << EOF
# Written by ratos-firstboot â€” autohotspot AP subnet
address=/${NEW_HOSTNAME}.local/192.168.50.1
EOF

echo "Hostname set to: ${NEW_HOSTNAME}"

# â”€â”€ Regenerate SSH host keys â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

# â”€â”€ Set correct ownership on printer_data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo "[5/7] Setting file ownership..."
mkdir -p /home/pi/printer_data/ratos /home/pi/printer_data/logs /home/pi/timelapse
touch /home/pi/printer_data/logs/sonar.log
# nginx (www-data) must be able to traverse /home/pi to serve /home/pi/mainsail.
# Without execute on the home directory, Mainsail routes return HTTP 500.
chmod 755 /home/pi
chown -R pi:pi /home/pi/printer_data
chown -R pi:pi /home/pi/timelapse
chown -R pi:pi /home/pi/configurator
chown -R pi:pi /home/pi/klipper
chown -R pi:pi /home/pi/moonraker
[ -d /home/pi/mainsail ] && chown -R pi:pi /home/pi/mainsail

# â”€â”€ Enable mDNS / Avahi â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo "[6/7] Enabling Avahi mDNS..."
systemctl enable avahi-daemon
systemctl start avahi-daemon

# â”€â”€ Start all services â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
echo "[7/7] Starting RatOS PI5 services..."
systemctl daemon-reload
systemctl start klipper
sleep 3
systemctl start moonraker
sleep 3
systemctl start ratos-configurator
systemctl restart nginx

# â”€â”€ Enable auto-hotspot after first boot (avoids fighting NM during initial bring-up) â”€
if systemctl list-unit-files autohotspot.service 2>/dev/null | grep -q autohotspot.service; then
  echo "[post] Enabling autohotspot.service for subsequent boots..."
  systemctl enable autohotspot.service 2>/dev/null || true
  # Oneshot unit â€” start once now so fallback AP works without an extra reboot.
  systemctl start autohotspot.service 2>/dev/null || true
fi

# â”€â”€ Disable this service so it never runs again â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
systemctl disable ratos-firstboot.service

# â”€â”€ SSH safety net (if a later step failed, ssh may still need a kick) â”€
systemctl enable ssh ssh.socket 2>/dev/null || true
systemctl is-active --quiet ssh || systemctl start ssh 2>/dev/null || true

echo "============================================"
echo "RatOS PI5 First Boot Complete: $(date)"
echo "First-run: open http://${NEW_HOSTNAME}.local/ â†’ hardware wizard /configure/wizard/ (printer profile + hardware)."
echo "After setup: finish the hardware wizard in the UI (then / opens Mainsail). Mainsail early: http://${NEW_HOSTNAME}.local/index.html"
echo "RatOS Configurator: http://${NEW_HOSTNAME}.local/configure/  |  Wizard: .../configure/wizard/"
echo "On fallback hotspot Wi-Fi: http://192.168.50.1 (same / â†’ configurator until wizard complete)"
echo "============================================"
