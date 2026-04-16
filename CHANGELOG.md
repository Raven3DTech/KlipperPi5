# KlipperPi Changelog

## v1.0.0 — Initial Release

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
- **hotspot** module: [RatOS v2.1.x](https://github.com/Rat-OS/RatOS/tree/v2.1.x/src/modules/hotspot) auto-hotspot (hostapd, dnsmasq, `autohotspotN`); **KlipperPi tweaks:** default SSID **KlipperPi**, skip blanking `/etc/network/interfaces` when **NetworkManager** is installed, patch **`eth0` → `end0`** when present
- **GitHub Actions**: free runner disk (remove dotnet/android/ghc/agent tools) before build; PiShrink uses **`-s -n`**, **`df -h`** logging, and **retry with `-r`** if shrink fails (large enlarged images need headroom for zero-fill + truncate); **`sudo xz`** + **`chown`** on `*.img.xz` after PiShrink (workspace stayed root-owned → `xz: … Permission denied`)
- **ratos-configurator** module: patch `src/app/fonts.tsx` to **`next/font/local`** with `fonts-inter` (or DejaVu fallback) so `pnpm run build` does not call **fonts.gstatic.com** (CI/chroot often hits **ETIMEDOUT** on `next/font/google`)
- **network-support** module: wpasupplicant, WiFi firmware, rfkill, iw (NM stays from base image; ModemManager masked on first boot); first-boot `rfkill unblock` + Pi 5 serial + Mainsail hostname; Next `pnpm build` uses `NODE_OPTIONS=--max-old-space-size=4096` for CI
- **sonar** module: install `iputils-ping` explicitly (upstream dropped `PKGLIST=`); set default **`SONAR_SYSTEMD_PATH`** to `~/printer_data/systemd` and create it before `make install` (unattended install otherwise `cp`s `sonar.env` to an empty path)
- **klipperscreen** module: **do not run** upstream `KlipperScreen-install.sh` in the image build — CI/chroot **nosuid** breaks `/usr/bin/sudo` for non-root users; install X stack, venv + pip, systemd unit, polkit rules, and desktop file **directly as root** then `chown` to `pi` (same outcome as the installer without any `sudo`). **Deps:** `libgtk-3-dev`, `libffi-dev`, `gobject-introspection`, `libdbus-1-dev` so PyGObject pip builds succeed; optional fonts on a separate `apt` line; **piwheels** extra index on `arm*` / `aarch*` for faster pip on Pi images.
- **rpi_mcu** module: install `klipper-mcu.service` with **`install -m 0644` as root** — `sudo -u pi cp … /etc/systemd/system/` runs `cp` as `pi`, which cannot write there (CI failure: Permission denied).
- [RatOS-configuration](https://github.com/Rat-OS/RatOS-configuration) `v2.1.x` preinstalled under `~/printer_data/config/RatOS`; build patches `ratos-update.sh` for Bookworm Python venv path and skips forced Node 18 (see **BUILD.md**)
- Optional extras (from [RatOS v2.1.x modules](https://github.com/Rat-OS/RatOS/tree/v2.1.x/src/modules), adapted for KlipperPi): **crowsnest** (camera-streamer from [mryel00/camera-streamer](https://github.com/mryel00/camera-streamer) `main` for Bookworm FFmpeg `avio_alloc_context` compatibility), **sonar**, **moonraker-timelapse**, **KlipperScreen**, **dfu-util** (source build), **klipper-mcu** (uses `boards/rpi/firmware.config` from RatOS-configuration when present; else Linux-process preset)
- Full Klipper + Moonraker + Mainsail stack
- Configurator accessible from Mainsail sidebar
- Board detection and automatic firmware flashing
- Config generation wizard
- Automatic filesystem expansion on first boot
- Unique hostname generation per device (klipperpi-XXXX)
- mDNS via Avahi (klipperpi.local)
- Update Manager integration for all components
- STM32 / AVR / RP2040 flashing tools pre-installed
- udev rules for USB flashing devices
- PolicyKit rules for Moonraker power/service management
