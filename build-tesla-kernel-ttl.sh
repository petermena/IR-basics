#!/bin/bash
#
# Tesla Android Kernel Build Script with TTL Mangling Support
#
# This script builds a custom kernel for Raspberry Pi 4 running Tesla Android
# with TTL pre/post route mangling enabled for hotspot bypass.
#
# Prerequisites:
#   - Ubuntu 22.04 or WSL2 with Ubuntu
#   - Run: sudo apt install -y build-essential bc bison flex libssl-dev libncurses-dev gcc-aarch64-linux-gnu git
#
# Usage:
#   1. Extract config from your working device:
#      adb shell su -c "zcat /proc/config.gz" > tesla_config
#   2. Place tesla_config in the same directory as this script
#   3. Run: ./build-tesla-kernel-ttl.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} Tesla Android Kernel Build Script${NC}"
echo -e "${GREEN} With TTL Mangling Support${NC}"
echo -e "${GREEN}============================================${NC}"

# Configuration
KERNEL_REPO="https://github.com/GloDroid/glodroid_forks.git"
KERNEL_BRANCH="kernel-broadcom-2024w50"
KERNEL_DIR="$HOME/tesla-kernel-build"
OUTPUT_DIR="$HOME/tesla-kernel-output"
CONFIG_FILE="tesla_config"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for config file
if [ -f "$SCRIPT_DIR/$CONFIG_FILE" ]; then
    CONFIG_PATH="$SCRIPT_DIR/$CONFIG_FILE"
elif [ -f "./$CONFIG_FILE" ]; then
    CONFIG_PATH="./$CONFIG_FILE"
else
    echo -e "${RED}ERROR: tesla_config not found!${NC}"
    echo ""
    echo "Please extract the kernel config from your working Tesla Android device:"
    echo ""
    echo "  1. Connect to your Pi via ADB"
    echo "  2. Run: adb shell su -c \"zcat /proc/config.gz\" > tesla_config"
    echo "  3. Place tesla_config in: $SCRIPT_DIR"
    echo "  4. Re-run this script"
    echo ""
    exit 1
fi

echo -e "${GREEN}Found config: $CONFIG_PATH${NC}"

# Check for required tools
echo -e "${YELLOW}Checking dependencies...${NC}"
MISSING_DEPS=""
for cmd in git make bc bison flex aarch64-linux-gnu-gcc; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_DEPS="$MISSING_DEPS $cmd"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo -e "${RED}Missing dependencies:$MISSING_DEPS${NC}"
    echo ""
    echo "Install with:"
    echo "  sudo apt update"
    echo "  sudo apt install -y build-essential bc bison flex libssl-dev libncurses-dev gcc-aarch64-linux-gnu git"
    exit 1
fi
echo -e "${GREEN}All dependencies found.${NC}"

# Clone or update kernel source
echo -e "${YELLOW}Setting up kernel source...${NC}"
if [ -d "$KERNEL_DIR" ]; then
    echo "Kernel directory exists, updating..."
    cd "$KERNEL_DIR"
    git fetch origin
    git checkout "$KERNEL_BRANCH"
    git pull origin "$KERNEL_BRANCH" || true
else
    echo "Cloning kernel source (this may take a while)..."
    git clone --branch "$KERNEL_BRANCH" --depth 1 "$KERNEL_REPO" "$KERNEL_DIR"
    cd "$KERNEL_DIR"
fi

# Set up build environment
echo -e "${YELLOW}Configuring build environment...${NC}"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# Copy the extracted config
echo -e "${YELLOW}Applying Tesla Android config...${NC}"
cp "$CONFIG_PATH" .config

# Enable TTL mangling support
echo -e "${YELLOW}Enabling TTL mangling options...${NC}"
./scripts/config --enable CONFIG_NETFILTER_XT_TARGET_HL
./scripts/config --enable CONFIG_IP_NF_TARGET_TTL
./scripts/config --enable CONFIG_NETFILTER_XT_MATCH_HL
./scripts/config --enable CONFIG_IP_NF_MATCH_TTL

# Resolve any dependency issues
echo -e "${YELLOW}Resolving config dependencies...${NC}"
make olddefconfig

# Verify TTL options are enabled
echo -e "${YELLOW}Verifying TTL configuration...${NC}"
echo ""
echo "TTL Configuration:"
grep -E "TARGET_TTL|TARGET_HL|MATCH_TTL|MATCH_HL" .config | grep -v "^#" || true
echo ""

# Check if options are properly enabled
if grep -q "CONFIG_IP_NF_TARGET_TTL=y" .config && grep -q "CONFIG_NETFILTER_XT_TARGET_HL=y" .config; then
    echo -e "${GREEN}TTL support properly configured!${NC}"
else
    echo -e "${RED}WARNING: TTL options may not be fully enabled. Check .config manually.${NC}"
    grep -E "TARGET_TTL|TARGET_HL" .config
fi

# Build the kernel
echo -e "${YELLOW}Building kernel (this will take 30-60 minutes)...${NC}"
echo "Using $(nproc) CPU cores"
echo ""

make -j$(nproc) Image dtbs

# Create output directory
echo -e "${YELLOW}Collecting build artifacts...${NC}"
mkdir -p "$OUTPUT_DIR"

# Copy kernel image
cp arch/arm64/boot/Image "$OUTPUT_DIR/"

# Copy device tree blobs for RPi4
if [ -f arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb ]; then
    cp arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb "$OUTPUT_DIR/"
fi

# Copy all RPi4 related DTBs
find arch/arm64/boot/dts/broadcom -name "bcm2711*.dtb" -exec cp {} "$OUTPUT_DIR/" \; 2>/dev/null || true

# Create a readme with instructions
cat > "$OUTPUT_DIR/README.txt" << 'EOF'
Tesla Android Kernel with TTL Mangling Support
===============================================

Files included:
- Image: The kernel image
- bcm2711-rpi-4-b.dtb: Device tree blob for Raspberry Pi 4

Installation:
1. Mount the boot partition of your Tesla Android SD card
2. Backup the existing kernel: cp Image Image.backup
3. Copy the new Image to the boot partition
4. Copy the .dtb file(s) to the boot partition
5. Unmount and boot your Pi

After booting, test TTL mangling:
    adb shell
    su
    iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64
    iptables -t mangle -L -v

To make persistent, add the iptables command to an init script.
EOF

# Show summary
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} BUILD COMPLETE!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Output files are in: ${YELLOW}$OUTPUT_DIR${NC}"
echo ""
ls -la "$OUTPUT_DIR"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy files from $OUTPUT_DIR to your SD card's boot partition"
echo "2. Boot the Pi and verify with:"
echo "   adb shell su -c 'iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64'"
echo ""
echo -e "${GREEN}Done!${NC}"
