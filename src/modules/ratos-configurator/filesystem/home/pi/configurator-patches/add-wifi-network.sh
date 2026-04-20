#!/usr/bin/env bash
# RatOS Configurator â€” add-wifi-network.sh
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

# Do not use `sh -c "wpa_passphrase \"$1\" \"$2\" â€¦"` â€” special chars in the passphrase break quoting and
# always fail the `^network` check â†’ Configurator shows "Invalid wifi credentials" for good passwords.
WPAP_ERR="$(mktemp)"
set +e
NETWORK="$(wpa_passphrase "${SSID}" "${PASS}" 2>"${WPAP_ERR}" | sed '/^\s*#psk=\".*\"$/d' | tr -d '\r')"
set -e
if [[ -z "${NETWORK}" ]] || ! grep -q '^[[:space:]]*network[[:space:]]*={' <<<"${NETWORK}"; then
	echo "wpa_passphrase failed (WPA passphrase must be 8â€“63 chars, or SSID/passphrase has an unsupported character). stderr was:" >&2
	cat "${WPAP_ERR}" >&2 || true
	rm -f "${WPAP_ERR}"
	echo "Invalid wifi credentials"
	exit 1
fi
rm -f "${WPAP_ERR}"

# Optional scan frequency (omit if UI sent empty â€” bad value corrupts the network block)
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

# â”€â”€ RatOS PI5: NetworkManager (Bookworm) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Design:
#   1. SYNCHRONOUSLY create the NM Wi-Fi profile on disk with autoconnect=yes.
#      Writing to /etc/NetworkManager/system-connections/ is a local filesystem
#      op â€” since wlan0 is currently "unmanaged" (under hostapd for the AP),
#      NM will NOT auto-activate yet. No disruption to the running AP.
#   2. Disable autohotspot.service so it does not race NM for wlan0 on the
#      next boot. The periodic AP-guard (ratos-nm-wlan-ap-guard.timer)
#      still re-invokes /usr/bin/autohotspotN if Wi-Fi later becomes orphaned.
#   3. Schedule a detached systemd-run unit to do the *live* transition
#      (stop AP, hand wlan0 to NM, activate the ratos-wifi profile) after a
#      short grace so the tRPC 200 and the follow-up hostname/reboot round
#      trips can complete over the still-up AP.
#
# If the user reboots before the deferred job fires: NO HARM. The profile is
# already on disk, autohotspot is disabled for next boot, so when NM starts
# it auto-connects to the user's Wi-Fi. Previously this was the ONE thing
# that caused the "Pi never joined my Wi-Fi" bug â€” the deferred job used to
# be the *only* thing that created the profile.
if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager 2>/dev/null; then
	WLAN=$(iw dev 2>/dev/null | awk '$1 == "Interface" { print $2; exit }')
	if [ -z "${WLAN}" ]; then
		echo "No wireless interface found (iw dev)."
		exit 1
	fi

	# Safe, non-disruptive prep (does not kill the AP):
	iw reg set "${COUNTRY}" 2>/dev/null || true

	LOG_FILE="/var/log/ratos-wifi-apply.log"

	# â”€â”€â”€ Step 1: create/refresh the NM profile SYNCHRONOUSLY â”€â”€â”€â”€â”€â”€â”€â”€â”€
	# Delete any stale profile so re-runs don't accumulate duplicates.
	nmcli connection delete ratos-wifi 2>/dev/null || true

	# Build the `nmcli connection add` invocation. For an open network we
	# skip the security fields entirely (NM defaults to no security).
	NMCLI_ADD_ARGS=(
		connection add
		type wifi
		con-name ratos-wifi
		ifname "${WLAN}"
		ssid "${SSID}"
		connection.autoconnect yes
		connection.autoconnect-priority 50
		connection.autoconnect-retries 0   # 0 = infinite retries
		ipv4.method auto
		ipv6.method auto
	)
	if [ -n "${PASS}" ]; then
		NMCLI_ADD_ARGS+=(
			wifi-sec.key-mgmt wpa-psk
			wifi-sec.psk "${PASS}"
		)
	fi
	if [ "${HIDDEN}" = "hidden" ]; then
		NMCLI_ADD_ARGS+=(wifi.hidden yes)
	fi

	if ! nmcli "${NMCLI_ADD_ARGS[@]}" >/dev/null 2>"${LOG_FILE}.err"; then
		echo "nmcli failed to create ratos-wifi profile. stderr:" >&2
		cat "${LOG_FILE}.err" >&2 || true
		rm -f "${LOG_FILE}.err"
		echo "Invalid wifi credentials"
		exit 1
	fi
	rm -f "${LOG_FILE}.err"
	echo "RatOS PI5: NM profile 'ratos-wifi' created (autoconnect=yes) at /etc/NetworkManager/system-connections/."

	# â”€â”€â”€ Step 2: make sure autohotspot won't race NM on next boot â”€â”€â”€â”€
	# The AP-guard script still calls autohotspotN on demand when wlan is
	# orphaned, so failure recovery remains intact.
	systemctl disable autohotspot.service 2>/dev/null || true

	# â”€â”€â”€ Step 3: schedule the live transition (best-effort, cancelable by reboot) â”€â”€
	if ! command -v systemd-run >/dev/null 2>&1; then
		echo "systemd-run not available; skipping live transition â€” reboot to apply."
		exit 0
	fi
	UNIT="ratos-wifi-apply-$(date +%s%N)"
	systemd-run \
		--no-block \
		--quiet \
		--unit="${UNIT}" \
		--setenv=RV_WLAN="${WLAN}" \
		--setenv=RV_LOG="${LOG_FILE}" \
		/bin/bash -c '
			exec >>"${RV_LOG}" 2>&1
			echo "=== ratos-wifi-apply $(date -Iseconds) iface=${RV_WLAN} ==="
			# After wifi.join returns the UI still needs hostname + reboot
			# round-trips on the same AP. Give that a generous window.
			sleep 45
			# AP teardown + hand wlan to NM, then activate ratos-wifi profile.
			systemctl stop hostapd 2>/dev/null || true
			systemctl stop dnsmasq 2>/dev/null || true
			nmcli networking on 2>/dev/null || true
			nmcli radio wifi on 2>/dev/null || true
			nmcli device set "${RV_WLAN}" managed yes 2>/dev/null || true
			sleep 2
			nmcli -w 120 connection up ratos-wifi ifname "${RV_WLAN}"
			NM_EXIT=$?
			echo "nmcli up ratos-wifi exit: ${NM_EXIT}"
			if [ "${NM_EXIT}" -ne 0 ]; then
				echo "Wi-Fi join failed. Restoring RatOS hotspot on ${RV_WLAN}..."
				nmcli device disconnect "${RV_WLAN}" 2>/dev/null || true
				nmcli device set "${RV_WLAN}" managed no 2>/dev/null || true
				sleep 2
				ip link set dev "${RV_WLAN}" down 2>/dev/null || true
				ip addr flush dev "${RV_WLAN}" 2>/dev/null || true
				ip addr add 192.168.50.1/24 brd + dev "${RV_WLAN}" 2>/dev/null || true
				ip link set dev "${RV_WLAN}" up
				# Re-enable autohotspot so the user has the full fallback next reboot.
				systemctl enable autohotspot.service 2>/dev/null || true
				systemctl start dnsmasq 2>/dev/null || true
				systemctl start hostapd 2>/dev/null || true
				echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
				sleep 2
				if systemctl is-active --quiet hostapd 2>/dev/null; then
					echo "RatOS hotspot: UP (reconnect your device to RatOS and retry)."
				else
					echo "RatOS hotspot: FAILED to start â€” check journalctl -u hostapd."
				fi
			fi
			exit "${NM_EXIT}"
		'

	echo "RatOS PI5: Wi-Fi apply scheduled via ${UNIT}."
	echo "Profile already on disk â€” Pi will auto-join on next boot regardless."
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
