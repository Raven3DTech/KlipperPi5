#!/bin/sh
# RavenOS PI5 — set nginx routing for "/" based on wired Ethernet carrier.
# - end0/eth0 link up  → Mainsail SPA (try_files)
# - no wired link      → redirect "/" to RavenOS Configurator (Wi-Fi / hotspot / wizard)
# Called from: nginx ExecStartPre, NetworkManager dispatcher (link up/down).

set -u

STATE_DIR=/var/lib/ravenos
CONF="${STATE_DIR}/nginx-mainsail-root.conf"
mkdir -p "${STATE_DIR}"

eth_up=0
for dev in end0 eth0; do
	c="/sys/class/net/${dev}/carrier"
	if [ -r "${c}" ] && [ "$(cat "${c}" 2>/dev/null)" = "1" ]; then
		eth_up=1
		break
	fi
done

if [ "${eth_up}" = "1" ]; then
	cat >"${CONF}" <<'EOF'
location / {
    try_files $uri $uri/ /index.html;
}
EOF
else
	cat >"${CONF}" <<'EOF'
# No Ethernet carrier: send http://<host>/ to Configurator (wizard, Wi-Fi setup).
location = / {
    return 302 /configure/;
}

location / {
    try_files $uri $uri/ /index.html;
}
EOF
fi

if [ "${1:-}" = "--reload" ]; then
	if systemctl is-active --quiet nginx 2>/dev/null; then
		nginx -t 2>/dev/null && systemctl reload nginx
	fi
fi

exit 0
