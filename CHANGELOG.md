# R3DTOS PI5 Changelog

## Unreleased

### Changed
- **Default `pi` / `raspberry` on first boot:** include CustomPiOS **`base`** as the first module so **`userconf.txt`** is written on the boot partition and **`BASE_SSH_ENABLE`** applies (modern Pi OS has no stock login without this — SSH matched RatOS docs but always denied until reflashed). Set **`BASE_SSH_ENABLE`**, **`DIST_NAME`**, **`DIST_VERSION`**, **`BASE_OVERRIDE_HOSTNAME`**, and **`BASE_CONFIG_*`** so `base` matches existing hostname/locale/timezone variables.
- **RatOS-style web entry:** nginx on port **80** reverse-proxies **`/configure/*`** to RatOS Configurator (Next on **:3000**); **`/config`** and **`/config/`** redirect to **`/`** so RatOS install-doc links work. Mainsail sidebar panel, **`.env.local` `NEXT_PUBLIC_MOONRAKER_URL`**, and docs use **`http://<host>/configure`** with same-origin Moonraker via nginx. **systemd** runs Next from **`~/ratos-configurator/src`** with the correct **`node_modules`** path. First boot updates **`.env.local`** in **`src/`** (and root if present).
- **First boot (`r3dtospi5-firstboot.sh`):** regenerate SSH host keys with **`ssh-keygen -A`** (fallback to `dpkg-reconfigure`) so a failed non-interactive reconfigure cannot leave **`/etc/ssh`** empty under **`set -e`** — which previously could brick **SSH** (connection refused) until reflashed. **`systemctl enable ssh` / `ssh.socket`** and a final **start-if-inactive** guard added.
- **Repository & docs:** GitHub remote is **`Raven3DTech/R3DTOS-PI5`** (renamed from `KlipperPi5`). **`docs/WORKSPACE.md`** covers monorepo layout, `CustomPiOS` sibling, Windows junction, and CI vs local; README/BUILD clone examples use **`https://github.com/Raven3DTech/R3DTOS-PI5.git`** with directory **`R3DTOS-PI5`** for **`R3DTOS-PI5.img`**.
- **Branding:** product name **R3DTOS PI5** (RatOS v2.1.x stack port for Raspberry Pi OS / Pi 5). Default hostname **`r3dtospi5`**, mDNS **`r3dtospi5.local`**, fallback hotspot SSID **`r3dtospi5`**, first-boot service and scripts renamed to **`r3dtospi5-firstboot`** (see README).
- **hotspot:** install `autohotspot.service` but **do not** enable it in the chroot; **`r3dtospi5-firstboot.sh`** enables and **starts** it once after first boot (oneshot) so **NetworkManager** is less likely to conflict on a cold Pi 5 boot, without requiring a second reboot for the AP.
- **CI:** `workflow_dispatch` input **`skip_pishrink`** — skip PiShrink for a **much larger** artifact when debugging “image will not boot” after shrink.

## v1.0.0 — Initial Release

*(Earlier releases were shipped under the working name “KlipperPi”; same image lineage.)*

### Components
- Klipper (Klipper3d/klipper @ master)
- Moonraker (Arksine/moonraker @ master)
- Mainsail (mainsail-crew/mainsail @ latest stable)
- Configurator (Rat-OS/RatOS-configurator @ v2.1.x)

### Base OS
- Raspberry Pi OS Lite 64-bit (arm64; tracks current `raspios_lite_arm64_latest`, e.g. Bookworm or newer)
- Root partition enlarged by **14000 MiB** during build (`BASE_IMAGE_ENLARGEROOT`) so heavy modules (KlipperScreen, crowsnest, RatOS Configurator `pnpm install`) do not hit **ENOSPC** in CI

### Targets
- Raspberry Pi 5 ✅
- Raspberry Pi 4 ✅

### Features
- **hotspot** module: [RatOS v2.1.x](https://github.com/Rat-OS/RatOS/tree/v2.1.x/src/modules/hotspot) auto-hotspot (hostapd, dnsmasq, `autohotspotN`); **R3DTOS PI5 tweaks:** default SSID **`r3dtospi5`**, skip blanking `/etc/network/interfaces` when **NetworkManager** is installed, patch **`eth0` → `end0`** when present
- **GitHub Actions**: free runner disk (remove dotnet/android/ghc/agent tools) before build; PiShrink uses **`-s -n`**, **`df -h`** logging, and **retry with `-r`** if shrink fails (large enlarged images need headroom for zero-fill + truncate); **`sudo xz`** + **`chown`** on `*.img.xz` after PiShrink (workspace stayed root-owned → `xz: … Permission denied` on some runners)
- **ratos-configurator** module: patch `src/app/fonts.tsx` to **`next/font/local`** with `fonts-inter` (or DejaVu fallback) so `pnpm run build` does not call **fonts.gstatic.com** (CI/chroot often hits **ETIMEDOUT** on `next/font/google`)
- **network-support** module: wpasupplicant, WiFi firmware, rfkill, iw (NM stays from base image; ModemManager masked on first boot); first-boot `rfkill unblock` + Pi 5 serial + Mainsail hostname; Next `pnpm build` uses `NODE_OPTIONS=--max-old-space-size=4096` for CI
- **sonar** module: install `iputils-ping` explicitly (upstream dropped `PKGLIST=`); set default **`SONAR_SYSTEMD_PATH`** to `~/printer_data/systemd` and create it before `make install` (unattended install otherwise `cp`s `sonar.env` to an empty path)
- **klipperscreen** module: **do not run** upstream `KlipperScreen-install.sh` in the image build — CI/chroot **nosuid** breaks `/usr/bin/sudo` for non-root users; install X stack, venv + pip, systemd unit, polkit rules, and desktop file **directly as root** then `chown` to `pi` (same outcome as the installer without any `sudo`). **Deps:** `libgtk-3-dev`, `libffi-dev`, `gobject-introspection`, `libdbus-1-dev` so PyGObject pip builds succeed; optional fonts on a separate `apt` line; **piwheels** extra index on `arm*` / `aarch*` for faster pip on Pi images.
- **rpi_mcu** module: install `klipper-mcu.service` with **`install -m 0644` as root** — `sudo -u pi cp … /etc/systemd/system/` runs `cp` as `pi`, which cannot write there (CI failure: Permission denied).
- [RatOS-configuration](https://github.com/Rat-OS/RatOS-configuration) `v2.1.x` preinstalled under `~/printer_data/config/RatOS`; build patches `ratos-update.sh` for Bookworm Python venv path and skips forced Node 18 (see **BUILD.md**)
- Optional extras (from [RatOS v2.1.x modules](https://github.com/Rat-OS/RatOS/tree/v2.1.x/src/modules), adapted for R3DTOS PI5): **crowsnest** (camera-streamer from [mryel00/camera-streamer](https://github.com/mryel00/camera-streamer) `main` for Bookworm FFmpeg `avio_alloc_context` compatibility), **sonar**, **moonraker-timelapse**, **KlipperScreen**, **dfu-util** (source build), **klipper-mcu** (uses `boards/rpi/firmware.config` from RatOS-configuration when present; else Linux-process preset)
- Full Klipper + Moonraker + Mainsail stack
- Configurator accessible from Mainsail sidebar
- Board detection and automatic firmware flashing
- Config generation wizard
- Automatic filesystem expansion on first boot
- Unique hostname generation per device (`r3dtospi5-XXXX`)
- mDNS via Avahi (`r3dtospi5.local`)
- Update Manager integration for all components
- STM32 / AVR / RP2040 flashing tools pre-installed
- udev rules for USB flashing devices
- PolicyKit rules for Moonraker power/service management
