#!/bin/sh
# RatOS PI5 â€” set nginx routing for "/" based on wizard-complete state.
#
# Matches the upstream RatOS UX:
#   - Pre-setup (no marker file)   â†’ "/" redirects to /configure/ (wizard/Wi-Fi)
#   - Post-setup (marker present)  â†’ "/" serves Mainsail SPA (try_files)
#
# The marker is written by the Configurator at the end of its hardware wizard
# (see the wizard-complete step). It deliberately lives on printer_data (user
# partition) so that reflashing or re-running the wizard resets the UX.
#
# Called from:
#   - nginx ExecStartPre (so every reload picks up the current state)
#   - NetworkManager dispatcher on link up/down (cheap no-op if state unchanged)
#   - the Configurator itself, with --reload, right after writing the marker

set -u

STATE_DIR=/var/lib/ratos
CONF="${STATE_DIR}/nginx-mainsail-root.conf"
MARKER=/home/pi/printer_data/ratos/wizard-complete
mkdir -p "${STATE_DIR}"

if [ -f "${MARKER}" ]; then
	cat >"${CONF}" <<'EOF'
# Wizard complete: http://<host>/ serves Mainsail.
location / {
    try_files $uri $uri/ /index.html;
}
EOF
else
	cat >"${CONF}" <<'EOF'
# Pre-setup: http://<host>/ sends users to the Configurator wizard.
# Mainsail stays reachable at /index.html for users who want to run Machine-page
# updates before configuring their printer (mirrors RatOS flow).
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
