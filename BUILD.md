# RavenOS PI5 — Build Guide

**RavenOS PI5** is a **RatOS v2.1.x–class** printer stack (Moonraker, Mainsail, **RavenOS Configurator** from upstream RatOS-configurator, modular `~/printer_data/config/RatOS`, RatOS-derived hotspot) on **Raspberry Pi OS Lite arm64** for **Raspberry Pi 5** (Pi 4 compatible). It is **not** the upstream RatOS CB1 image; it tracks RatOS behaviour where Pi OS allows, with Pi‑5‑specific fixes called out below.

This document covers the full build process, troubleshooting, and how to
customise the image.

---

## Prerequisites

### Operating System
Build must be done on a **Linux** machine (native or VM).
- Ubuntu 22.04 LTS is recommended.
- WSL2 on Windows works but is slower.
- macOS is **not** supported for building (no QEMU chroot support).

### Required packages
```bash
sudo apt-get update
sudo apt-get install -y \
    gawk make build-essential util-linux \
    qemu-user-static qemu-system-arm \
    git p7zip-full python3 curl unzip wget
```

### Disk space
Allow at least **25 GB free** on the build machine — the base image grows a lot once the root
partition is enlarged for the full module stack, and the workspace holds intermediate files.

### Why RavenOS PI5 “feels huge” while RatOS / other images look smaller

- **Build-time enlarge** (`BASE_IMAGE_ENLARGEROOT` in `src/config`) adds **empty MiB** on the root partition so the chroot can install a **full** stack (RatOS Configurator `pnpm`, KlipperScreen, camera-streamer, etc.) without **`ENOSPC`**. That makes the **raw `.img` during the build** large; **PiShrink + `xz`** in CI then shrink and compress, so the **downloaded `.img.xz`** is usually **much smaller** than the workspace peak.
- **Upstream RatOS** images often combine a **different base**, **fewer in-image dev steps**, and a **smaller enlarge** in their recipe—so their **pre-shrink** file can start smaller. You can **try lowering** `BASE_IMAGE_ENLARGEROOT` in **2–4 GiB steps** only after CI proves the install still fits.
- **Further wins** (optional, later): `pnpm store prune` after `pnpm run build` in the configurator module, drop optional modules you do not ship, or split “dev” vs “release” module sets.

### Auto-hotspot (RatOS-derived)

The **`hotspot`** module follows [Rat-OS/RatOS `v2.1.x` `hotspot`](https://github.com/Rat-OS/RatOS/tree/v2.1.x/src/modules/hotspot) (Guy Sheffer / RaspberryConnect.com pattern): **hostapd**, **dnsmasq**, **`autohotspot.service`**, and **`/usr/bin/autohotspotN`**.

- **NetworkManager:** Pi OS Lite **Bookworm+** often uses **NetworkManager** for Wi‑Fi. `autohotspotN` was written around **wpa_supplicant + dhcpcd**. **R3DTOS** extends **`createAdHocNetwork`**: `nmcli device disconnect` + **`managed no`** on `wlan0` before **hostapd**, and skips **`dhcpcd` restart** when NM is active, so the fallback AP can start. **`KillHotspot`** sets **`managed yes`** again when leaving AP mode. If the AP still fails, check **`journalctl -u hostapd -b`** and **`iw dev`** (interface name).
- This port **does not blank `/etc/network/interfaces` when `network-manager` is installed** (unlike stock RatOS) to avoid breaking NM-managed installs.
- **Ethernet interface:** many Pis use **`end0`** instead of **`eth0`**; the module **patches `autohotspotN`** when `end0` exists.
- Defaults: SSID **`ravenos`**, WPA passphrase **`raspberry`**, channel **`6`** — override via `HOTSPOT_NAME` / `HOTSPOT_PASSWORD` / `HOTSPOT_CHANNEL` in `src/modules/hotspot/config` or `config.local`.
- **First boot:** `autohotspot.service` is **not** enabled during the image build. **`ravenos-firstboot.sh`** enables it **after** rootfs expand, hostname, SSH keys, and core services, then runs **`systemctl start autohotspot.service`** once (oneshot) so the fallback AP works **without** an extra reboot, while still avoiding autohotspot during the **initial** cold boot before firstboot runs.

---

## Step-by-Step Build

### 1. Clone both repos side by side

```
~/
├── CustomPiOS/     ← https://github.com/guysoft/CustomPiOS
└── R3DTOS-PI5/     ← this repo (clone folder; CustomPiOS names `.img` after this folder)
```

```bash
cd ~
git clone https://github.com/guysoft/CustomPiOS.git
git clone https://github.com/Raven3DTech/R3DTOS-PI5.git R3DTOS-PI5
```

### 2. Download the base Raspberry Pi OS image

```bash
cd ~/R3DTOS-PI5
make download-image
```

Or manually:
```bash
mkdir -p src/image
wget -c https://downloads.raspberrypi.org/raspios_lite_arm64_latest \
     -O src/image/raspios_lite_arm64_latest.img.xz
```

> ⚠️ Use the **Lite** (no desktop) **arm64** image for Pi 5.  
> The same image also works on Pi 4.

### 3. Update CustomPiOS paths

This links CustomPiOS scripts into the RavenOS PI5 source tree:

```bash
cd ~/R3DTOS-PI5
make update-paths
```

Or manually:
```bash
cd src
../../CustomPiOS/src/update-custompios-paths
```

### 4. (Optional) Customise the config

Edit `src/config` to change:
- `BASE_HOSTNAME` — default `ravenos`
- `BASE_TIMEZONE` — default `Australia/Sydney`
- `BASE_LOCALE` — default `en_AU.UTF-8`

### 5. Build

```bash
cd ~/R3DTOS-PI5
make build
```

This takes **30–90 minutes** depending on your internet speed and machine.
The build downloads packages inside the chroot.

The finished image will be at:
```
src/workspace/R3DTOS-PI5.img
```

---

## Flashing

### Raspberry Pi Imager (Recommended)
1. Open Raspberry Pi Imager
2. Choose OS → Use Custom → select `R3DTOS-PI5.img` (or whatever `.img` name matches your clone folder)
3. Choose your SD card or NVMe
4. Write

### dd (Linux)
```bash
sudo dd if=src/workspace/R3DTOS-PI5.img of=/dev/sdX bs=4M status=progress
sync
```

Replace `/dev/sdX` with your actual device (check with `lsblk`).

---

## First Boot

Match the [RatOS 2.1.x installation](https://os.ratrig.com/docs/installation/) flow: **network/hostname in the Configurator first** (`/configure`), then **Mainsail** for updates, then the rest of the wizard. Klipper + Moonraker + web services start together on boot (Klipper may error until hardware is set up; Moonraker should still be up for Mainsail).

1. Insert the media into your Pi 5 and wait for first-boot (~2 minutes).
2. **Wi‑Fi path:** join hotspot **`ravenos`** / **`raspberry`**, open **`http://192.168.50.1/configure`**. **Ethernet:** open **`http://ravenos.local/configure`** (hostname may get a suffix after first boot).
3. Complete Wi‑Fi + hostname; reboot onto your LAN when prompted (upstream pattern).
4. Open **`http://<hostname>.local`** or **`http://<hostname>.local/config`** for **Mainsail** (port 80; `/config` redirects to `/` like RatOS docs). Run **Update Manager** before continuing the wizard.
5. Continue in **Configurator** at **`http://<hostname>.local/configure`** for board detection and hardware steps.

> **Tip:** nginx proxies **`/configure`** to Next on **:3000** (stock RatOS URL shape). Direct **`http://<host>:3000/configure`** still works. If `.local` fails, use the Pi’s IP from your router.

---

## RatOS printer config tree (`~/printer_data/config/RatOS`)

The image fills `~/printer_data/config/RatOS` from [RatOS-configurator **`configuration/`**](https://github.com/Rat-OS/RatOS-configurator/tree/v2.1.x/configuration/) on branch **`v2.1.x`** (same source the Configurator ships with). The older standalone [RatOS-configuration](https://github.com/Rat-OS/RatOS-configuration) repository is **deprecated** upstream (merged into the configurator; new work targets the configurator repo). That keeps board definitions and templates aligned with the wizard instead of lagging the split repo.

Note the following **compatibility** points versus a stock RatOS image:

| Topic | RavenOS PI5 behaviour |
|--------|---------------------|
| **OS** | Raspberry Pi OS Lite **Bookworm arm64** — same Debian family RatOS targets; no Armbian/CB1-specific paths. |
| **User / paths** | RatOS scripts often assume `/home/pi`; RavenOS PI5 uses `BASE_USER=pi`, so paths align. |
| **Configurator on :80 (RatOS parity)** | Stock RatOS uses **`http://<host>/configure`**. RavenOS PI5 **nginx** reverse-proxies **`/configure/*`** to Next.js on **127.0.0.1:3000** and redirects **`/config`** → **`/`** so RatOS install-doc Mainsail links work. The Configurator’s **`NEXT_PUBLIC_MOONRAKER_URL`** targets **`http://<host>`** so the browser hits Moonraker through the same nginx site. |
| **Moonraker ↔ Klipper socket** | RavenOS PI5 keeps `klippy_uds_address: /tmp/klippy_uds` in the **live** `moonraker.conf`. Reference `moonraker.conf` snippets **inside** the copied RatOS tree are not overlaid on the system config, so Moonraker and `klipper.service` stay in sync. |
| **`scripts/ratos-install.sh`** | Upstream expects to be run as **`pi` (not root)**, replaces `printer.cfg` from RatOS templates, installs many udev symlinks, and calls the **`ratos` CLI** (Configurator API) to register Klipper extensions. The image build **only copies** the modular tree and installs `python3-matplotlib` / `curl`; run `ratos-install.sh` manually after first boot if you want the full RatOS wiring. |
| **Moonraker Update Manager** | There is **no** `[update_manager ratos_configuration]` entry: `~/printer_data/config/RatOS` is **not** its own Git checkout. **Update Manager** still updates **`ratos-configurator`** (`~/ratos-configurator`). After a configurator `git pull`, sync boards/macros into Klipper’s tree if you need new hardware on disk without reflashing, for example: `rsync -a --delete ~/ratos-configurator/configuration/ ~/printer_data/config/RatOS/` then restart **Klipper** (and re-apply the **`ratos-update.sh` patches** in this doc if that script was overwritten). |
| **Raspberry Pi 5** | RatOS board packs do **not** gate on a specific Pi model. Boards, macros, and `boards/rpi/firmware.config` are plain Klipper Kconfig snippets; the RPi “MCU” preset is the **Linux process** build, which is valid on **Pi 4 and Pi 5** under **64-bit** Pi OS. |
| **`ratos-update.sh` (if you run it)** | The image build **patches** `~/printer_data/config/RatOS/scripts/ratos-update.sh` after the copy: `python3.9` in the matplotlib path is replaced with the **actual** `python3.*` folder under `~/klippy-env/lib/` (Bookworm is usually 3.11), and the **`ensure_node_18` line is commented out** so Node **20** from RavenOS PI5 is not downgraded to Node 18. If you rsync fresh files from `~/ratos-configurator/configuration/` and that resets `ratos-update.sh`, re-apply those edits or re-flash. |

### Raspberry Pi 5 — “full compatibility” checklist

What “Pi 5 ready” means in practice is **hardware + OS + stack + validation**. RavenOS PI5 already targets 64-bit Pi OS Lite Bookworm (the family Raspberry Pi tests on Pi 5). To tighten further:

1. **Power / thermals** — Use a **5 V** supply appropriate for load (official **5 A** unit if you use many USB devices or NVMe). Adequate cooling avoids throttling during long builds or camera encode.
2. **Bootloader / firmware** — Keep **EEPROM / bootloader** current (Raspberry Pi Imager advanced menu, or `raspi-eeprom-update` on the Pi). Pi 5 gains fixes for USB, PCIe, and power sequencing over time.
3. **Base image** — Continue using **`raspios_lite_arm64_latest`** so the rootfs matches Pi 5 expectations.
4. **`/boot/firmware/config.txt`** — Only add **dtoverlay=** lines you need (cameras, HATs, PCIe). Wrong overlays are a common source of “works on Pi 4, fails on Pi 5” reports; headless Klipper images usually need **no** extra overlays.
5. **Klipper / printer MCU** — The main board is independent of Pi generation; **`klipper-mcu`** on the Pi uses RatOS `boards/rpi/firmware.config` when present (Linux-process style), which is valid on Pi 5 under 64-bit OS.
6. **Full RatOS wiring** — Templates, udev, and `ratos extensions` still require running **`ratos-install.sh` as user `pi`** when the Configurator API is available (see table above); the image does not run that automatically.
7. **Proof** — **Smoke-test on a real Pi 5**: Ethernet or WiFi, Mainsail, Configurator, one serial device, optional crowsnest/timelapse. Automated CI does not replace hardware validation.

---

## WiFi Setup

WiFi can be configured after first boot via SSH:

```bash
ssh pi@ravenos.local
# password: raspberry

sudo nmtui
# Select "Activate a connection" → choose your network → enter password
```

Or use `raspi-config`:
```bash
sudo raspi-config
# → System Options → Wireless LAN
```

---

## Troubleshooting: no Ethernet lights / no network (Pi 5)

The image recipe includes a **`network-support`** module that installs **wpasupplicant**, **Broadcom WiFi firmware** (`firmware-brcm80211`), **rfkill**, **iw**, and **wireless-regdb**. **NetworkManager** and Ethernet drivers come from the stock Raspberry Pi OS base image (we avoid reinstalling NM inside the chroot so CI/chroot builds stay reliable). **ModemManager** is **masked on first boot** so it does not grab USB-serial printer devices.

**Important:** On Raspberry Pi OS **Bookworm**, the built-in Ethernet interface is often named **`end0`**, not `eth0`. WiFi is usually **`wlan0`**. Check link status with:

```bash
nmcli device status
ip -br link
```

1. **RJ45 LEDs off** — If the **board’s green activity LED** is also not blinking, the OS may not be booting (bad flash, wrong image, power, or storage). HDMI + keyboard helps confirm boot. Link LEDs can stay dark if **no cable** is plugged in.
2. **Cable / switch / router** — Try another cable, another switch port, and confirm DHCP is offered on the LAN.
3. **First boot** — Inspect `cat /var/log/ravenos-firstboot.log` and `journalctl -u NetworkManager -b --no-pager` once you have local console or serial.
4. **WiFi** — Not preconfigured: use **Raspberry Pi Imager** “Wireless LAN” options when writing the image, or run `sudo nmtui` from a console after Ethernet works once.

### SD / USB image will not boot at all (no activity LED, no HDMI)

Use this when the Pi **never reaches a login prompt** or **shows no boot progress** (not the same as “no Ethernet” once the OS is running).

1. **Hardware** — Official **5 V** supply with enough **current** for Pi 5; quality **SD** or **USB SSD**; try another card / reader / cable.
2. **Flash** — [Raspberry Pi Imager](https://www.raspberrypi.com/software/); correct model (**Pi 5**); **64-bit** image if you built **arm64**; verify the write (Imager can do it); re-download the `.img.xz` in case of corruption.
3. **EEPROM / boot** — If other known-good images boot, compare [Pi 5 boot troubleshooting](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html) (recovery / bootloader updates).
4. **Shrink vs raw image** — Rarely, a **PiShrink**-processed image can disagree with a specific card or bootloader. In GitHub Actions, run **Build RavenOS PI5 Image** via **workflow_dispatch** and set **`skip_pishrink`** to **true** (artifact will be **much larger**). If that image boots, focus on PiShrink / partition geometry.
5. **Hotspot module** — If you still suspect the hotspot stack, temporarily **remove `hotspot`** from `MODULES` in `src/config`, rebuild, and retest.
6. **Logs** — If anything appears on HDMI, note the last line. With a **USB-serial** adapter on the UART pins, capture early boot messages.

---

## Default Credentials

| Service | URL | User | Password |
|---|---|---|---|
| SSH | `ssh pi@ravenos.local` | `pi` | `raspberry` |
| Mainsail | `http://ravenos.local` | — | — |
| Configurator | `http://ravenos.local/configure` | — | — |

> **Security:** Change the default SSH password immediately:
> ```bash
> passwd pi
> ```

---

## Service Management

```bash
# Check status of all RavenOS PI5 services
systemctl status klipper moonraker ratos-configurator nginx

# Restart a service
sudo systemctl restart klipper
sudo systemctl restart moonraker
sudo systemctl restart ratos-configurator

# View live logs
journalctl -fu klipper
journalctl -fu moonraker
journalctl -fu ratos-configurator

# First boot log
cat /var/log/ravenos-firstboot.log
```

---

## Updating Components

All components update through Mainsail's built-in Update Manager:

1. Open Mainsail → `http://ravenos.local`
2. Go to **Settings → Update Manager**
3. Click **Check for updates**
4. Update each component individually

---

## Troubleshooting

### Image build logs: long "Unmounting …/mount/…" then `BUILD FAILED`

CustomPiOS runs **`unmount_image`** whenever a module script errors (`set -e`). The lines that unmount `…/mount/sys`, `proc`, `dev`, `boot`, etc. are **cleanup after the real failure**, not the root cause. Scroll **up** in `build.log` (or the Actions step log) for the first **`cp:` / `pip` / `apt` / `make`** error *before* that block.

### Image build: PiShrink / `resize2fs` / `parted failed` / `No space left on device` on GitHub Actions

The workflow runs **PiShrink** on the raw `.img` after CustomPiOS finishes. PiShrink **mounts** the image and **writes zeros** into free blocks before truncating the file, so the runner needs **several GB of free disk on `/`** in addition to the image size. The workflow removes preinstalled **dotnet / Android / GHC / hosted tool cache** to make room, then retries PiShrink once with **`-r`** (filesystem repair) if the first pass fails.

### Image build: `next/font` / `Failed to fetch Inter from Google Fonts` / `ETIMEDOUT`

The RatOS Configurator build uses Next.js; **`next/font/google`** downloads fonts at **build** time. Inside the CustomPiOS chroot (especially on GitHub Actions), HTTPS to **fonts.gstatic.com** can time out. The RavenOS PI5 `ratos-configurator` module replaces that with **`next/font/local`** and a system **Inter** (or DejaVu) TTF so the image build stays offline-safe.

### Image build: `ERR_PNPM_ENOSPC` / `no space left on device` during RatOS Configurator

The root filesystem inside the loop-mounted image is full. The build already enlarges the root partition (`BASE_IMAGE_ENLARGEROOT` in `src/config`); if you add modules or upstream grows (e.g. `pnpm` dependencies), increase that value (MiB) and rebuild. On GitHub Actions, the artifact is still compressed afterward (PiShrink + `xz`), so a larger **build** image does not mean you ship that much raw space to users in the same proportion.

### Image build: `umount: … target is busy` (local / WSL)

Something still has the chroot open (file descriptor, shell cwd, `apt`, `qemu`). From the host:

```bash
sync
M=/path/to/R3DTOS-PI5/src/workspace/mount   # adjust to your clone
sudo lsof +D "$M" 2>/dev/null | head
sudo umount -R -l "$M"   # lazy recursive unmount; safe if paths match CustomPiOS
sudo losetup -D
```

Then `make clean` or remove `src/workspace` only after mounts are gone. If unmount still fails, reboot the VM/WSL session and delete the workspace folder before rebuilding.

### Mainsail not loading
```bash
sudo systemctl status nginx
sudo nginx -t
sudo journalctl -fu nginx
```

### Moonraker not connecting
```bash
sudo systemctl status moonraker
journalctl -fu moonraker
cat ~/printer_data/logs/moonraker.log
```

### Klipper not starting
```bash
sudo systemctl status klipper
cat ~/printer_data/logs/klippy.log
```
> The shipped **`printer.cfg`** includes **`[mcu]`** with **`serial: /tmp/klipper_host_mcu`** (host MCU) so Klipper starts before the Configurator runs. If Klipper still fails, check **`klipper-mcu.service`** and **`~/printer_data/logs/klippy.log`**.

### Configurator link in Mainsail sidebar
Moonraker **0.10+** no longer uses **`[panel_custom …]`** in **`moonraker.conf`** for this stack. Open the Configurator at **`http://<hostname>.local/configure`** (or **`http://<IP>/configure`**) from the address bar or a browser bookmark.

```bash
sudo systemctl status ratos-configurator
journalctl -fu ratos-configurator
```

### Configurator can't flash board
Check USB connection, then verify sudo rules are in place:
```bash
sudo -l -U pi | grep dfu
sudo -l -U pi | grep flash
```

---

## Module System

Each directory under `src/modules/` is a CustomPiOS module:

```
src/modules/<name>/
    config              ← env vars sourced by start_chroot_script
    start_chroot_script ← install script run inside the image chroot
    filesystem/         ← files copied into the image filesystem
```

To add a new module (e.g., KlipperScreen):
1. Create `src/modules/klipperscreen/`
2. Add `config` and `start_chroot_script`
3. Add `klipperscreen` to `MODULES=` in `src/config`
4. Rebuild

---

## Architecture Reference

```
Pi 5 (Bookworm 64-bit arm64)
├── systemd services
│   ├── klipper.service          :  klippy.py → /tmp/klippy_uds
│   ├── moonraker.service        :  moonraker.py → :7125
│   ├── NetworkManager.service   :  Ethernet + WiFi (from base Pi OS image)
│   ├── autohotspot.service      :  RatOS-style fallback AP if no known WiFi (hostapd + dnsmasq)
│   ├── nginx.service            :  → :80 (Mainsail) + proxy :7125
│   ├── ratos-configurator.service: next start → :3000; nginx /configure → :3000
│   ├── crowsnest.service         :  webcam streaming
│   ├── sonar.service             :  WiFi keepalive (optional)
│   ├── KlipperScreen.service     :  touchscreen UI (if installed)
│   ├── klipper-mcu.service       :  Pi as secondary MCU (Linux process build)
│   ├── avahi-daemon.service     :  mDNS → ravenos.local
│   └── ravenos-firstboot.service (runs once, then disables itself)
│
├── /home/pi/
│   ├── klipper/                 Klipper source + klippy-env/
│   ├── moonraker/               Moonraker source + moonraker-env/
│   ├── mainsail/                Mainsail web app (symlinked to /var/www/mainsail)
│   ├── ratos-configurator/      Next.js app
│   ├── crowsnest/               webcam stack (if module enabled)
│   ├── sonar/                   WiFi keepalive (if module enabled)
│   ├── KlipperScreen/           touchscreen UI (if module enabled)
│   ├── moonraker-timelapse/     timelapse plugin source (if module enabled)
│   ├── scripts/                 firstboot + helper scripts
│   └── printer_data/
│       ├── config/              printer.cfg, moonraker.conf, RatOS/
│       ├── logs/                klippy.log, moonraker.log
│       ├── gcodes/              uploaded gcode files
│       └── comms/               unix sockets
│
└── /etc/
    ├── nginx/sites-enabled/mainsail
    ├── systemd/system/*.service
    ├── sudoers.d/ravenos-flash
    └── udev/rules.d/49-ravenos.rules
```
