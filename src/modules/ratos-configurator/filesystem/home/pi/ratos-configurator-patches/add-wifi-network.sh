#!/usr/bin/env bash
# RatOS Configurator — add-wifi-network.sh
# Upstream writes /etc/wpa_supplicant/wpa_supplicant.conf (needed for autohotspot SSID list).
# Raspberry Pi OS Bookworm uses NetworkManager: NM does not apply that file by itself, so we
# also connect via nmcli after tearing down the fallback hotspot (hostapd/dnsmasq).
set -euo pipefail

if [ ! "${EUID}" -eq 0 ]; then
	echo "This script must run as root"
	exit 1
fi

SSID="${1:?ssid required}"
PASS="${2:?passphrase required}"
COUNTRY="${3:-GB}"
FREQ="${4:-}"
HIDDEN="${5:-shown}"

# Do not use `sh -c "wpa_passphrase \"$1\" \"$2\" …"` — special chars in the passphrase break quoting and
# always fail the `^network` check → Configurator shows "Invalid wifi credentials" for good passwords.
WPAP_ERR="$(mktemp)"
set +e
NETWORK="$(wpa_passphrase "${SSID}" "${PASS}" 2>"${WPAP_ERR}" | sed '/^\s*#psk=\".*\"$/d' | tr -d '\r')"
set -e
if [[ -z "${NETWORK}" ]] || ! grep -q '^[[:space:]]*network[[:space:]]*={' <<<"${NETWORK}"; then
	echo "wpa_passphrase failed (WPA passphrase must be 8–63 chars, or SSID/passphrase has an unsupported character). stderr was:" >&2
	cat "${WPAP_ERR}" >&2 || true
	rm -f "${WPAP_ERR}"
	echo "Invalid wifi credentials"
	exit 1
fi
rm -f "${WPAP_ERR}"

# Optional scan frequency (omit if UI sent empty — bad value corrupts the network block)
if [ -n "${FREQ}" ]; then
	NETWORK=${NETWORK/"}"/"	scan_freq=${FREQ}
}"}
fi

if [ "${HIDDEN}" = "hidden" ]; then
	NETWORK=${NETWORK/"}"/"	scan_ssid=1
}"}
fi

cat << __EOF > /etc/wpa_supplicant/wpa_supplicant.conf
# Use this file to configure your wifi connection(s).
#
# Just uncomment the lines prefixed with a single # of the configuration
# that matches your wifi setup and fill in SSID and passphrase.
#
# You can configure multiple wifi connections by adding more 'network'
# blocks.
#
# See https://linux.die.net/man/5/wpa_supplicant.conf
# (or 'man -s 5 wpa_supplicant.conf') for advanced options going beyond
# the examples provided below (e.g. various WPA Enterprise setups).
#
# !!!!! HEADS-UP WINDOWS USERS !!!!!
#
# Do not use Wordpad for editing this file, it will mangle it and your
# configuration won't work. Use a proper text editor instead.
# Recommended: Notepad++, VSCode, Atom, SublimeText.
#
# !!!!! HEADS-UP MACOSX USERS !!!!!
#
# If you use Textedit to edit this file make sure to use "plain text format"
# and "disable smart quotes" in "Textedit > Preferences", otherwise Textedit
# will use none-compatible characters and your network configuration won't
# work!

## WPA/WPA2 secured
#network={
#  ssid="put SSID here"
#  psk="put password here"
#}

## Open/unsecured
#network={
#  ssid="put SSID here"
#  key_mgmt=NONE
#}

## WEP "secured"
##
## WEP can be cracked within minutes. If your network is still relying on this
## encryption scheme you should seriously consider to update your network ASAP.
#network={
#  ssid="put SSID here"
#  key_mgmt=NONE
#  wep_key0="put password here"
#  wep_tx_keyidx=0
#}

# Supplied by RatOS Configurator
$NETWORK

# Uncomment the country your Pi is in to activate Wifi in RaspberryPi 3 B+ and above
# For full list see: https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
#country=GB # United Kingdom
#country=CA # Canada
#country=DE # Germany
#country=FR # France
#country=US # United States
country=${COUNTRY}

### You should not have to change the lines below #####################
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
__EOF

# ── RavenOS PI5: NetworkManager (Bookworm) ────────────────────────
if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager 2>/dev/null; then
	echo "RavenOS PI5: Applying Wi-Fi via NetworkManager (stopping fallback AP if active)..."
	systemctl stop hostapd 2>/dev/null || true
	systemctl stop dnsmasq 2>/dev/null || true
	WLAN=$(iw dev 2>/dev/null | awk '$1 == "Interface" { print $2; exit }')
	if [ -z "${WLAN}" ]; then
		echo "No wireless interface found (iw dev)."
		exit 1
	fi
	iw reg set "${COUNTRY}" 2>/dev/null || true
	nmcli networking on 2>/dev/null || true
	nmcli radio wifi on 2>/dev/null || true
	nmcli device set "${WLAN}" managed yes 2>/dev/null || true
	nmcli device disconnect "${WLAN}" 2>/dev/null || true
	sleep 2
	nmcli connection delete ratos-wifi 2>/dev/null || true
	set +e
	if [ "${HIDDEN}" = "hidden" ]; then
		nmcli -w 120 device wifi connect "${SSID}" password "${PASS}" ifname "${WLAN}" name ratos-wifi hidden yes
	else
		nmcli -w 120 device wifi connect "${SSID}" password "${PASS}" ifname "${WLAN}" name ratos-wifi
	fi
	NM_EXIT=$?
	set -e
	if [ "${NM_EXIT}" -ne 0 ]; then
		echo "nmcli failed to join Wi-Fi (exit ${NM_EXIT}). Check SSID/password and range."
		exit 1
	fi
	echo "RavenOS PI5: Wi-Fi profile 'ratos-wifi' activated. Reconnect your PC to the printer on the LAN if needed."
	exit 0
fi

# autohotspotN

function get_sbc {
	grep BOARD_NAME /etc/board-release | cut -d '=' -f2
}

#CB1
if [[ -e /etc/board-release && $(get_sbc) = '"BTT-CB1"' ]]; then
	cat << __EOF > /boot/system.cfg
#-----------------------------------------#
check_interval=5        # Cycle to detect whether wifi is connected, time 5s
router_ip=8.8.8.8       # Reference DNS, used to detect network connections

eth=eth0        # Ethernet card device number
wlan=wlan0      # Wireless NIC device number

###########################################
# wifi name
#WIFI_SSID="ZYIPTest"
# wifi password
#WIFI_PASSWD="12345678"

###########################################
WIFI_AP="false"             # Whether to open wifi AP mode, default off
WIFI_AP_SSID="rtl8189"      # Hotspot name created by wifi AP mode
WIFI_AP_PASSWD="12345678"   # wifi AP mode to create hotspot connection password

# Supplied by RatOS Configurator
WIFI_SSID="$1"
WIFI_PASSWD="$2"
__EOF
fi
