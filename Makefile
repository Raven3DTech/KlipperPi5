# ============================================================
# RatOS PI5 Makefile
# ============================================================

CUSTOMPIOS_PATH ?= ../CustomPiOS
SRC_DIR         := src
WORKSPACE_DIR   := $(SRC_DIR)/workspace
IMAGE_DIR       := $(SRC_DIR)/image

.PHONY: help build clean update-paths check-deps download-image

help:
	@echo "RatOS PI5 Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make check-deps       Check build dependencies are installed"
	@echo "  make download-image   Download the base Raspberry Pi OS image"
	@echo "  make update-paths     Link CustomPiOS paths into this project"
	@echo "  make build            Build the RatOS PI5 image"
	@echo "  make clean            Remove build workspace"
	@echo ""
	@echo "Variables:"
	@echo "  CUSTOMPIOS_PATH=../CustomPiOS  Path to CustomPiOS checkout"

check-deps:
	@echo "Checking build dependencies..."
	@which gawk        || (echo "âŒ gawk not found"        && exit 1)
	@which make        || (echo "âŒ make not found"        && exit 1)
	@which git         || (echo "âŒ git not found"         && exit 1)
	@(which qemu-aarch64-static >/dev/null 2>&1 || which qemu-arm-static >/dev/null 2>&1) || \
		(echo "âŒ qemu-user-static not found â€” run: sudo apt install qemu-user-static" && exit 1)
	@which unzip       || (echo "âŒ unzip not found"       && exit 1)
	@which wget        || (echo "âŒ wget not found"        && exit 1)
	@(test -f "$(CUSTOMPIOS_PATH)/src/build" || test -f "$(CUSTOMPIOS_PATH)/src/build_dist") || \
		(echo "âŒ CustomPiOS not found at $(CUSTOMPIOS_PATH) â€” git clone https://github.com/guysoft/CustomPiOS.git" && exit 1)
	@echo "âœ… All dependencies satisfied"

download-image:
	@echo "Downloading Raspberry Pi OS Lite arm64 (Bookworm)..."
	mkdir -p $(IMAGE_DIR)
	wget -c \
		https://downloads.raspberrypi.org/raspios_lite_arm64_latest \
		-O $(IMAGE_DIR)/raspios_lite_arm64_latest.img.xz
	@echo "âœ… Base image downloaded"

update-paths:
	cd $(SRC_DIR) && "$(abspath $(CUSTOMPIOS_PATH))/src/update-custompios-paths"
	@ln -sf "$(abspath $(CUSTOMPIOS_PATH))/src/build" "$(SRC_DIR)/build_dist"
	@echo "âœ… Paths updated (src/build_dist â†’ CustomPiOS src/build)"

build: check-deps
	@echo "Building RatOS PI5 image..."
	sudo modprobe loop
	cd $(SRC_DIR) && sudo bash -x ./build_dist
	@echo ""
	@echo "âœ… Build complete!"
	@echo "Image: $(WORKSPACE_DIR)/<clone-folder-name>.img  (e.g. RAVENOS-PI5.img â€” name matches the parent directory of src/)"

clean:
	@echo "Cleaning workspace..."
	sudo rm -rf $(WORKSPACE_DIR)
	@echo "âœ… Clean done"
