#!/bin/sh
# One retry after boot: Wi-Fi / iw scan is often not ready when autohotspot.service runs first.
set -u
systemctl is-enabled --quiet autohotspot.service 2>/dev/null || exit 0
systemctl is-active --quiet hostapd.service 2>/dev/null && exit 0
exec /usr/bin/autohotspotN
