# RavenOS PI5 Changelog

## Unreleased

### Changed
- **Configurator fork:** image build clones and Moonraker’s `ratos-configurator` update-manager `origin` now use **[ECOM-EX/RatOS-configurator](https://github.com/ECOM-EX/RatOS-configurator)** (fork of [Rat-OS/RatOS-configurator](https://github.com/Rat-OS/RatOS-configurator), branch `v2.1.x`). Forking into **Raven3DTech** returned HTTP 403 for the account used with `gh`; transfer the repo under **Settings → General → Danger zone** if you want it under the org. Periodically merge or rebase **`upstream/v2.1.x`** into the fork to pick up Rat-OS fixes.
- **Product / license:** rebrand to **RavenOS PI5**; default hostname, hotspot SSID, first-boot and helper units use **`ravenos`**. Image build tree is **GPL-3.0** (`LICENSE`). **Hotspot:** `ravenos-nm-wlan-ap-guard` now finds whichever interface is in **AP** mode (not hardcoded `wlan0`); **`autohotspotN`** picks the first `iw dev` interface if `wlan0` is missing; **`HOTSPOT_WIFI_IF`** + hostapd/dnsmasq use the same iface at image build time.
- **RatOS printer config source:** `ratos-configuration` no longer clones [RatOS-configuration](https://github.com/Rat-OS/RatOS-configuration). It shallow-clones the **[RavenOS fork of RatOS-configurator](https://github.com/ECOM-EX/RatOS-configurator)** and copies **`configuration/`** → `~/printer_data/config/RavenOS` so boards/templates match the [bundled configurator tree](https://github.com/ECOM-EX/RatOS-configurator/tree/v2.1.x/configuration/) (merge [Rat-OS/RatOS-configurator](https://github.com/Rat-OS/RatOS-configurator) periodically). **Moonraker** drops `[update_manager ratos_configuration]`; see **BUILD.md** to rsync after updating the configurator repo.
- **SSH login shell:** add **`ensure-user-shell`** module after **`base`** to run **`usermod -s /bin/bash`** on **`BASE_USER`** in the chroot (Pi OS can ship **`pi`** with **`/usr/sbin/nologin`**, which yields **"This account is currently not available"** over SSH even with the correct password). **`ravenos-firstboot.sh`** does the same on first boot for edge cases.
- **Klipper bring-up:** default **`printer.cfg`** defines **`[mcu]`** with **`serial: /tmp/klipper_host_mcu`** (matches **`klipper-mcu.service`**) and **`[printer]`** **`kinematics: none`** so Klipper is not halted on “**`serial` in section `mcu` must be specified**” before the Configurator runs (RatOS **`initial-setup.cfg`** cannot be included from here because **`ratos-configuration`** installs after **`klipper`**).
- **Moonraker 0.10+:** **`moonraker.conf`** — replace deprecated **`env:`** with **`virtualenv:`** for Klipper/Moonraker; drop invalid **`install_script`** entries (**`ratos-configurator`’s `scripts/setup.sh` does not exist** on v2.1.x, which broke the update-manager extension and caused widespread “unparsed” warnings). Remove **`[panel_custom …]`** (no longer supported in server config the same way).
- **Mainsail / Moonraker by IP:** **`config.json`** uses same-origin Moonraker (**`hostname` `""`, port 80**) via nginx instead of **`ravenos.local:7125`**. **`moonraker.conf`** **`cors_domains`** adds **`192.168.*`**, **`10.*`**, **`172.*`** so browsers at **`http://<LAN-IP>/`** are not blocked by CORS (often surfaced as broken UI / 500-style errors).
- **CI:** stage **`raspios_lite_arm64_latest.img.xz`** into **`src/image/`** and run **`sudo -E bash …/build`** so **`BASE_ZIP_IMG`** is visible when CustomPiOS sources **`modules/base/config`** (otherwise `base` clears it and the build exits with **"could not find image"**). **`src/config`** defaults **`BASE_ZIP_IMG`** to **`${DIST_PATH}/image/…`** when unset (matches **`make download-image`**).
- **Default `pi` / `raspberry` on first boot:** add module **`prebase`** (`apt-get update` only) then CustomPiOS **`base`** so **`userconf.txt`** / **`userconf-pi`** succeed in CI, and **`BASE_SSH_ENABLE`** applies (modern Pi OS has no stock login without this — SSH matched RatOS docs but always denied until reflashed). Set **`BASE_SSH_ENABLE`**, **`DIST_NAME`**, **`DIST_VERSION`**, and **`BASE_OVERRIDE_HOSTNAME`**. Omit **`BASE_CONFIG_*`** overrides so `base` does not run **`raspi-config` locale/timezone** in the chroot before other modules’ **`apt-get update`** (CI often failed on **`en_AU.UTF-8`**).
- **RatOS-style web entry:** nginx on port **80** reverse-proxies **`/configure/*`** to RatOS Configurator (Next on **:3000**); **`/config`** and **`/config/`** redirect to **`/`** so RatOS install-doc links work. Mainsail sidebar panel, **`.env.local` `NEXT_PUBLIC_MOONRAKER_URL`**, and docs use **`http://<host>/configure`** with same-origin Moonraker via nginx. **systemd** runs Next from **`~/ratos-configurator/src`** with the correct **`node_modules`** path. First boot updates **`.env.local`** in **`src/`** (and root if present).
- **First boot (`ravenos-firstboot.sh`):** regenerate SSH host keys with **`ssh-keygen -A`** (fallback to `dpkg-reconfigure`) so a failed non-interactive reconfigure cannot leave **`/etc/ssh`** empty under **`set -e`** — which previously could brick **SSH** (connection refused) until reflashed. **`systemctl enable ssh` / `ssh.socket`** and a final **start-if-inactive** guard added.
- **Repository & docs:** GitHub remote is **`Raven3DTech/R3DTOS-PI5`** (renamed from `KlipperPi5`). **`docs/WORKSPACE.md`** covers monorepo layout, `CustomPiOS` sibling, Windows junction, and CI vs local; README/BUILD clone examples use **`https://github.com/Raven3DTech/R3DTOS-PI5.git`** with directory **`R3DTOS-PI5`** for **`R3DTOS-PI5.img`**.
- **Branding:** product name **RavenOS PI5** (RatOS v2.1.x stack port for Raspberry Pi OS / Pi 5). Default hostname **`ravenos`**, mDNS **`ravenos.local`**, fallback hotspot SSID **`ravenos`**, first-boot service and scripts renamed to **`ravenos-firstboot`** (see README).
- **hotspot:** install `autohotspot.service` but **do not** enable it in the chroot; **`ravenos-firstboot.sh`** enables and **starts** it once after first boot (oneshot) so **NetworkManager** is less likely to conflict on a cold Pi 5 boot, without requiring a second reboot for the AP.
- **CI:** `workflow_dispatch` input **`skip_pishrink`** — skip PiShrink for a **much larger** artifact when debugging “image will not boot” after shrink.

## v1.0.0 — Initial Release

*(Earlier releases were shipped under the working name “KlipperPi”; same image lineage.)*

### Components
- Klipper (Klipper3d/klipper @ master)
- Moonraker (Arksine/moonraker @ master)
- Mainsail (mainsail-crew/mainsail @ latest stable)
- Configurator ([ECOM-EX/RatOS-configurator](https://github.com/ECOM-EX/RatOS-configurator) fork @ v2.1.x; track Rat-OS upstream)

### Base OS
- Raspberry Pi OS Lite 64-bit (arm64; tracks current `raspios_lite_arm64_latest`, e.g. Bookworm or newer)
- Root partition enlarged by **14000 MiB** during build (`BASE_IMAGE_ENLARGEROOT`) so heavy modules (KlipperScreen, crowsnest, RatOS Configurator `pnpm install`) do not hit **ENOSPC** in CI

### Targets
- Raspberry Pi 5 ✅
- Raspberry Pi 4 ✅

### Features
- **hotspot** module: [RatOS v2.1.x](https://github.com/Rat-OS/RatOS/tree/v2.1.x/src/modules/hotspot) auto-hotspot (hostapd, dnsmasq, `autohotspotN`); **RavenOS PI5 tweaks:** default SSID **`ravenos`**, skip blanking `/etc/network/interfaces` when **NetworkManager** is installed, patch **`eth0` → `end0`** when present
- **GitHub Actions**: free runner disk (remove dotnet/android/ghc/agent tools) before build; PiShrink uses **`-s -n`**, **`df -h`** logging, and **retry with `-r`** if shrink fails (large enlarged images need headroom for zero-fill + truncate); **`sudo xz`** + **`chown`** on `*.img.xz` after PiShrink (workspace stayed root-owned → `xz: … Permission denied` on some runners)
- **ratos-configurator** module: patch `src/app/fonts.tsx` to **`next/font/local`** with `fonts-inter` (or DejaVu fallback) so `pnpm run build` does not call **fonts.gstatic.com** (CI/chroot often hits **ETIMEDOUT** on `next/font/google`)
- **network-support** module: wpasupplicant, WiFi firmware, rfkill, iw (NM stays from base image; ModemManager masked on first boot); first-boot `rfkill unblock` + Pi 5 serial + Mainsail hostname; Next `pnpm build` uses `NODE_OPTIONS=--max-old-space-size=4096` for CI
- **sonar** module: install `iputils-ping` explicitly (upstream dropped `PKGLIST=`); set default **`SONAR_SYSTEMD_PATH`** to `~/printer_data/systemd` and create it before `make install` (unattended install otherwise `cp`s `sonar.env` to an empty path)
- **klipperscreen** module: **do not run** upstream `KlipperScreen-install.sh` in the image build — CI/chroot **nosuid** breaks `/usr/bin/sudo` for non-root users; install X stack, venv + pip, systemd unit, polkit rules, and desktop file **directly as root** then `chown` to `pi` (same outcome as the installer without any `sudo`). **Deps:** `libgtk-3-dev`, `libffi-dev`, `gobject-introspection`, `libdbus-1-dev` so PyGObject pip builds succeed; optional fonts on a separate `apt` line; **piwheels** extra index on `arm*` / `aarch*` for faster pip on Pi images.
- **rpi_mcu** module: install `klipper-mcu.service` with **`install -m 0644` as root** — `sudo -u pi cp … /etc/systemd/system/` runs `cp` as `pi`, which cannot write there (CI failure: Permission denied).
- [RatOS-configuration](https://github.com/Rat-OS/RatOS-configuration) `v2.1.x` preinstalled under `~/printer_data/config/RatOS`; build patches `ratos-update.sh` for Bookworm Python venv path and skips forced Node 18 (see **BUILD.md**)
- Optional extras (from [RatOS v2.1.x modules](https://github.com/Rat-OS/RatOS/tree/v2.1.x/src/modules), adapted for RavenOS PI5): **crowsnest** (camera-streamer from [mryel00/camera-streamer](https://github.com/mryel00/camera-streamer) `main` for Bookworm FFmpeg `avio_alloc_context` compatibility), **sonar**, **moonraker-timelapse**, **KlipperScreen**, **dfu-util** (source build), **klipper-mcu** (uses `boards/rpi/firmware.config` from RatOS-configuration when present; else Linux-process preset)
- Full Klipper + Moonraker + Mainsail stack
- Configurator accessible from Mainsail sidebar
- Board detection and automatic firmware flashing
- Config generation wizard
- Automatic filesystem expansion on first boot
- Unique hostname generation per device (`ravenos-XXXX`)
- mDNS via Avahi (`ravenos.local`)
- Update Manager integration for all components
- STM32 / AVR / RP2040 flashing tools pre-installed
- udev rules for USB flashing devices
- PolicyKit rules for Moonraker power/service management
