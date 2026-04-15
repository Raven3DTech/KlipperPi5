# KlipperPi Changelog

## v1.0.0 — Initial Release

### Components
- Klipper (Klipper3d/klipper @ master)
- Moonraker (Arksine/moonraker @ master)
- Mainsail (mainsail-crew/mainsail @ latest stable)
- Configurator (Rat-OS/RatOS-configurator @ v2.1.x)

### Base OS
- Raspberry Pi OS Lite Bookworm 64-bit (arm64)

### Targets
- Raspberry Pi 5 ✅
- Raspberry Pi 4 ✅

### Features
- **network-support** module: wpasupplicant, WiFi firmware, rfkill, iw (NM stays from base image; ModemManager masked on first boot); first-boot `rfkill unblock` + Pi 5 serial + Mainsail hostname; Next `pnpm build` uses `NODE_OPTIONS=--max-old-space-size=4096` for CI
- **sonar** module: install `iputils-ping` explicitly (upstream dropped `PKGLIST=`); set default **`SONAR_SYSTEMD_PATH`** to `~/printer_data/systemd` and create it before `make install` (unattended install otherwise `cp`s `sonar.env` to an empty path)
- **klipperscreen** module: chroot/CI mounts can be **nosuid** — running `KlipperScreen-install.sh` as `pi` + `sudo apt` fails; patch installer (allow root, strip `sudo`), run as root with `HOME`/`USER` set to `pi`, **`NETWORK=n`**; `git clone` as root then `chown`. **Fix:** Python patch must pass the install script path via **`KLIPPERSCREEN_INSTALL_SCRIPT`** (`python3 - file` put `-` in `sys.argv[1]`, so the patch never edited the real file and the build still ran the unpatched installer).
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
