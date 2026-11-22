# Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| Bootloop right after flashing | Vendor module ABI mismatch (e.g. IFB / changed struct layout) | Restore backup boot; rebuild without the change; use the [ABI guard](ABI-GUARD.md) |
| Build: `implicit declaration of ksu_handle_*` | extern inside a disabled `#ifdef` | Use the provided patch unmodified |
| Link: `undefined symbol: path_umount` | Missing backport | Patch must include `fs/namespace.c` and `fs/internal.h` parts |
| Zygisk Next / Vector not running after reboot | Built with kprobes instead of manual hooks, or KSU modules disabled | Check `CONFIG_KSU_MANUAL_HOOK=y`; `su -c 'pidof zn-daemon'` (the process is `zn-daemon`, not `zn-daemon64`) |
| Installer says device mismatch | Not an A528 | Do not flash |
| Installer aborts on verify | Write/verify failure | Nothing was left half-written by design; restore the backup and retry |
| Play Integrity fails / "Lock bootloader" message | Unlocked bootloader | Expected. Not solvable by the kernel, and not something this project supports bypassing |
| A game crashes at launch | Usually app-side detection or ROM issues | Test on stock boot first; if it crashes there too it is not the kernel |
| Phone did not boot for several minutes after flash | First boot after a repack can be slow | Wait; if still nothing, hold power + volume down into recovery and restore |

Useful logs: `dmesg`, `logcat -b crash`, `/data/local/tmp/shadownexus_tuning.log`.
