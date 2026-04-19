#!/bin/sh
# RavenOS PI5 — NetworkManager often sets the Wi-Fi iface back to "managed" after hostapd starts, which
# kills the fallback AP within seconds. Re-assert unmanaged on whichever interface is in AP mode.
set -u
command -v nmcli >/dev/null 2>&1 || exit 0
systemctl is-active --quiet NetworkManager 2>/dev/null || exit 0
systemctl is-active --quiet hostapd 2>/dev/null || exit 0

for w in $(iw dev 2>/dev/null | awk '/Interface /{print $2}'); do
	if iw "$w" info 2>/dev/null | grep -q "type AP"; then
		nmcli device set "$w" managed no 2>/dev/null || true
	fi
done
exit 0
