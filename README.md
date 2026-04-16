# KlipperPi

A custom Raspberry Pi OS image for 3D printers, built with CustomPiOS.

Includes:
- **Klipper** — 3D printer firmware
- **Moonraker** — Klipper API server
- **Mainsail** — Web UI for Klipper
- **Configurator** — Board configuration, flashing and provisioning wizard

Targets **Raspberry Pi 5** running **Bookworm 64-bit**, but is compatible with Pi 4 as well.

---

## Requirements

### Build Machine
- Ubuntu 22.04 LTS (or any Debian-based Linux, or WSL2 on Windows)
- At least 8GB free disk space
- Internet connection during build

### Tools
```bash
sudo apt-get install -y \
  gawk make build-essential util-linux \
  qemu-user-static qemu-system-arm \
  git p7zip-full python3 curl unzip
```

---

## Quick Start

### 1. Clone this repo and CustomPiOS

```bash
git clone https://github.com/YOUR_USERNAME/KlipperPi.git
git clone https://github.com/guysoft/CustomPiOS.git
```

### 2. Download the base Raspberry Pi OS image

```bash
cd KlipperPi/src/image
wget -c https://downloads.raspberrypi.org/raspios_lite_arm64_latest -O raspios_lite_arm64_latest.img.xz
```

> **Note:** Use the Bookworm Lite 64-bit image for Pi 5. For Pi 4, use the same image — it is compatible.

### 3. Update CustomPiOS paths

```bash
cd KlipperPi/src
../../CustomPiOS/src/update-custompios-paths
```

### 4. Build the image

```bash
cd KlipperPi/src
sudo modprobe loop
sudo bash -x ./build_dist
```

The finished image will be at:
```
KlipperPi/src/workspace/KlipperPi.img
```

### 5. Flash the image

Use **Raspberry Pi Imager** (recommended) and select the `.img` file, or:

```bash
sudo dd if=KlipperPi.img of=/dev/sdX bs=4M status=progress
sync
```

---

## First Boot

1. Insert the SD card / NVMe into your Pi 5
2. Connect to your network via Ethernet (recommended for first boot)
3. Browse to `http://klipperpi.local`  — Mainsail loads
4. Click **Configurator** in the left sidebar
5. Follow the wizard to detect your board, generate config, and flash firmware

---

## Default Credentials

| Item | Value |
|---|---|
| Hostname | `klipperpi.local` |
| SSH user | `pi` |
| SSH password | `raspberry` *(change on first login)* |
| Mainsail URL | `http://klipperpi.local` |
| Configurator URL | `http://klipperpi.local:3000` |

---

## Architecture

```
Browser
  └── http://klipperpi.local          → Mainsail (nginx → /var/www/mainsail)
  └── http://klipperpi.local:3000     → Configurator (Next.js / port 3000)

Mainsail  ──────────────────────────► Moonraker API (:7125)
Configurator ───────────────────────► Moonraker API (:7125)
                                       └──► Klipper (unix socket)
                                       └──► Board flash scripts (sudo)
```

---

## Updating Components

Each component can be updated independently via Moonraker's update manager
(built into Mainsail under **Settings → Update Manager**).

---

## Modules

| Module | Source |
|---|---|
| network-support | WiFi firmware + WPA tools (NM from base Pi OS; ModemManager masked on first boot) |
| hotspot | [RatOS v2.1.x hotspot](https://github.com/Rat-OS/RatOS/tree/v2.1.x/src/modules/hotspot) — autohotspot / hostapd / dnsmasq (see **BUILD.md**) |
| Klipper | https://github.com/Klipper3d/klipper |
| Moonraker | https://github.com/Arksine/moonraker |
| Mainsail | https://github.com/mainsail-crew/mainsail |
| Configurator | https://github.com/Rat-OS/RatOS-configurator |
| RatOS-configuration | https://github.com/Rat-OS/RatOS-configuration (branch v2.1.x, path ~/printer_data/config/RatOS) |
| Crowsnest | https://github.com/mainsail-crew/crowsnest |
| Sonar | https://github.com/mainsail-crew/sonar |
| moonraker-timelapse | https://github.com/mainsail-crew/moonraker-timelapse |
| KlipperScreen | https://github.com/jordanruthe/KlipperScreen |
| dfu-util | https://gitlab.com/dfu-util/dfu-util (RatOS-style source build) |

---

## License

MIT — This build system is open source. Klipper, Moonraker, Mainsail and the RatOS
Configurator each carry their own respective licenses.
