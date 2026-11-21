# How it works

## 1. KernelSU-Next with manual hooks

KernelSU-Next can intercept syscalls in two ways: **kprobes** (runtime hooking) or **manual hooks** (small calls patched into the kernel source). On this kernel, with kprobes, KernelSU's boot-stage (`post-fs-data`, `service`, module execution) did not run modules, so `zn-daemon` (Zygisk Next) and `vectord` (Vector) never started on their own. With manual hooks they do.

`patches/ksu-manual-hooks-5.4.302.patch` adds these hook points:

| File | Hook | Purpose |
|---|---|---|
| `fs/exec.c` | `ksu_handle_execveat` | observe/redirect `execve` (su, init.rc handling) |
| `fs/open.c` | `ksu_handle_faccessat` | `access()` checks |
| `fs/stat.c` | `ksu_handle_stat`, `ksu_handle_newfstat_ret` | `stat` family |
| `fs/read_write.c` | `ksu_handle_vfs_read` | early read of `init.rc` |
| `kernel/reboot.c` | `ksu_handle_sys_reboot` | KernelSU's reboot-syscall channel |
| `drivers/input/input.c` | `ksu_handle_input_handle_event` | safe-mode key detection |

Config used: `CONFIG_KSU=y`, `CONFIG_KSU_MANUAL_HOOK=y`, `CONFIG_KSU_KPROBES_HOOK` disabled, SUSFS disabled.

Pitfall fixed: the `extern` declarations must not sit inside unrelated `#ifdef` blocks (e.g. `CONFIG_SECURITY_DEFEX`), otherwise they vanish when that option is off and the build gets an implicit-declaration error.

## 2. `path_umount` backport

KernelSU-Next calls `path_umount()` and `can_umount()`, which exist upstream from Linux 5.9 but not in 5.4. The patch backports them in `fs/namespace.c` (guarded by `CONFIG_KSU`) and declares them in `fs/internal.h`. Without it the link fails with `undefined symbol: path_umount`.

## 3. Samsung USB VID/PID (`CONFIG_USB_CONFIGFS_SAMSUNG_VIDPID`)

In `drivers/usb/gadget/configfs.c`, when binding to the UDC, if the gadget's VID is `0x18d1` (Google) and the PID is one of `0x4ee1`, `0x4ee2`, `0x4ee7` (MTP / PTP variants), they are replaced with `0x04e8` / `0x6860` (Samsung MTP). This makes Windows/Samsung tools recognise the phone. New bool Kconfig symbol in `drivers/usb/gadget/Kconfig`.

## 4. Network options

- `TCP_CONG_BBR` + `NET_SCH_FQ_CODEL` as default (the `tweaks` input).
- `NET_SCH_CAKE`.
- `NETFILTER_XT_TARGET_HL`, `IP_NF_TARGET_TTL`, `IP6_NF_TARGET_HL` for TTL/hop-limit mangling.
- Plain USB RNDIS/ECM is optional (`usb_extra`) because the ROM already uses `gsi.rndis` and `ncm`.

## 5. Why IFB is **not** enabled

`CONFIG_IFB` selects `NET_REDIRECT`, which adds `redirected` / `from_ingress` bits to `struct sk_buff`. The vendor's prebuilt modules (Wi-Fi, camera, adsprpc, ...) were built against the original layout and are protected by `CONFIG_MODVERSIONS` CRCs. A different layout changes exported-symbol CRCs, the modules refuse to load, and the device bootloops. This was reproduced on the device and removed. The [ABI guard](ABI-GUARD.md) exists to catch this class of mistake in CI.

## 6. Options deliberately dropped

Debug options such as `DEBUG_LIST` would remove/alter `__list_add_valid`, which prebuilt modules import. The CPU governor tweak was dropped because the device already runs `schedutil`.

## 7. Recovery installer

`installer/update-binary` (shell, uses bundled static `magiskboot` and `busybox`):

1. checks the device model (`A528`);
2. backs up the current boot partition to `/data/media/0/boot_backup_before_a52kernel.img`;
3. unpacks the existing boot image, replaces only the kernel, repacks (ramdisk, cmdline, vendor_boot untouched);
4. checks size and the `ANDROID!` header;
5. writes with `dd` and verifies with an md5 comparison; aborts without writing if any check fails.

## Honest note

The earlier crash of Vector (an `mprotect`-related tombstone) disappeared after switching to manual hooks, but the exact root cause was **not proven**. The manual-hook build is a verified working configuration, not a root-cause analysis.
