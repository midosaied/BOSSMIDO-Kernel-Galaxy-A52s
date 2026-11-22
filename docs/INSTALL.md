# Install and restore

> Flashing a kernel can bootloop your phone. Make sure you can reach recovery/download mode and have a stock or known-good boot image.

## Before you start

- SM-A528B with unlocked bootloader and a custom recovery that can flash zips.
- Copy your current boot image somewhere safe (PC or cloud). From a root shell:

```sh
dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/my_boot_backup.img
```

## Flash

1. Download `ShadowNexus-A528B-<version>.zip` (Releases, or the workflow artifact; if you got an artifact zip, unzip once so you flash the inner zip's content as a zip).
2. Boot to recovery -> Install -> select the zip.
3. The installer prints the banner, checks the model, backs up boot to `/data/media/0/boot_backup_before_a52kernel.img`, writes, and verifies.
4. Reboot system.

## Verify

```sh
uname -r                      # 5.4.302-... with your build suffix
su -c 'ls /data/adb/modules'
su -c 'pidof zn-daemon'       # Zygisk Next daemon (process name is zn-daemon)
su -c 'sysctl net.ipv4.tcp_congestion_control'
su -c 'tc qdisc add dev lo root cake && tc qdisc del dev lo root'   # CAKE present
```

## Restore

From recovery (adb shell) or root shell:

```sh
dd if=/data/media/0/boot_backup_before_a52kernel.img of=/dev/block/bootdevice/by-name/boot
```

(or the path of your own backup). Or flash your ROM's original `boot.img` from recovery/fastboot.

## Updating

Flash a newer zip over the old one; the installer repacks whatever boot image is currently installed.
