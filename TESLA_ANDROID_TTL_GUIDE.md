# Tesla Android Kernel TTL Mangling Guide

This guide explains how to build a custom Tesla Android kernel for Raspberry Pi 4 with TTL (Time To Live) mangling support enabled. This is useful for bypassing hotspot/tethering detection.

## Problem

The stock Tesla Android kernel has TTL matching enabled but **TTL modification disabled**:

| Kernel Option | Stock Status | Needed |
|---------------|--------------|--------|
| `CONFIG_IP_NF_MATCH_TTL` | ✓ Enabled | Match packets by TTL |
| `CONFIG_IP_NF_TARGET_TTL` | ✗ Disabled | **Modify TTL (needed!)** |
| `CONFIG_NETFILTER_XT_TARGET_HL` | ✗ Disabled | **Generic TTL target (needed!)** |

This means you cannot run:
```bash
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64
```

## Solution

Build a custom kernel with TTL modification enabled.

## Prerequisites

- Ubuntu 22.04 (or WSL2 on Windows)
- Working Tesla Android device with ADB access
- ~10GB disk space
- ~1 hour build time

### Install Dependencies

```bash
sudo apt update
sudo apt install -y build-essential bc bison flex libssl-dev \
    libncurses-dev gcc-aarch64-linux-gnu git
```

## Quick Start

### 1. Extract Config from Working Device

Connect to your Pi via ADB and extract the kernel config:

```bash
# From your PC (not inside adb shell)
adb shell su -c "zcat /proc/config.gz" > tesla_config
```

### 2. Run the Build Script

```bash
# Place tesla_config in the same directory as the script
./build-tesla-kernel-ttl.sh
```

The script will:
1. Clone the GloDroid kernel source
2. Apply your Tesla Android config
3. Enable TTL mangling options
4. Build the kernel
5. Output files to `~/tesla-kernel-output/`

### 3. Flash to SD Card

1. Insert your Tesla Android SD card into your PC
2. Mount the boot partition
3. Backup existing files:
   ```bash
   cp Image Image.backup
   cp bcm2711-rpi-4-b.dtb bcm2711-rpi-4-b.dtb.backup
   ```
4. Copy new files from `~/tesla-kernel-output/`
5. Unmount and boot

### 4. Test TTL Mangling

```bash
adb shell
su
# Set TTL to 64 for all outgoing packets
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64

# Verify
iptables -t mangle -L -v
```

## Manual Build (Without Script)

If you prefer to build manually:

```bash
# Clone kernel
git clone --branch kernel-broadcom-2024w50 --depth 1 \
    https://github.com/GloDroid/glodroid_forks.git ~/rpi4-kernel
cd ~/rpi4-kernel

# Setup environment
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# Apply your config
cp /path/to/tesla_config .config

# Enable TTL options
./scripts/config --enable CONFIG_NETFILTER_XT_TARGET_HL
./scripts/config --enable CONFIG_IP_NF_TARGET_TTL

# Resolve dependencies
make olddefconfig

# Build
make -j$(nproc) Image dtbs
```

Output files:
- `arch/arm64/boot/Image`
- `arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb`

## Making TTL Changes Persistent

To apply TTL rules on every boot, create an init script:

```bash
# Create script
adb shell
su
cat > /data/local/ttl-fix.sh << 'EOF'
#!/system/bin/sh
sleep 30
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64
ip6tables -t mangle -A POSTROUTING -j HL --hl-set 64
EOF
chmod +x /data/local/ttl-fix.sh
```

Then add to init or use a boot completion receiver in an Android app.

## Kernel Source Information

- **Repository**: https://github.com/GloDroid/glodroid_forks
- **Branch**: `kernel-broadcom-2024w50` (or latest `kernel-broadcom-*`)
- **Base**: Linux 6.1.x LTS
- **Platform**: BCM2711 (Raspberry Pi 4)

## Troubleshooting

### Boot Loop After Flashing

- Restore backup: copy `Image.backup` back to `Image`
- Verify you're using the correct DTB file
- Check serial console output (GPIO 14/15, 115200 baud)

### "Unknown option --ttl-set" Error

The kernel doesn't have TTL target support. Verify your build:
```bash
adb shell su -c "zcat /proc/config.gz | grep TARGET_TTL"
```
Should show: `CONFIG_IP_NF_TARGET_TTL=y`

### Modules Not Loading

Tesla Android uses a monolithic kernel (no modules). Ensure options are set to `=y` not `=m`.

## References

- [Tesla Android GitHub](https://github.com/tesla-android)
- [GloDroid Project](https://github.com/GloDroid)
- [Raspberry Pi Kernel Building](https://www.raspberrypi.com/documentation/computers/linux_kernel.html)
