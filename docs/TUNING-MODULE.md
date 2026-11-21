# bossmido_tuning (KernelSU module)

**Status: unit-tested on a fake sysfs only. Not yet tested on a real device.** It makes no performance claims.

Install `BOSSMIDO-Tuning-<ver>.zip` from the KernelSU-Next manager (Modules -> Install from storage).

## What it does

After `sys.boot_completed`, `service.sh` writes best-effort values (failures are logged, never fatal) to `/data/local/tmp/bossmido_tuning.log`.

## Configuration

Default `tuning.conf` ships in the module. To customise, copy it to `/data/adb/bossmido/tuning.conf`.

| Key | Default | Effect |
|---|---|---|
| `READ_AHEAD_KB` | `512` | Block-device read-ahead |
| `SWAPPINESS` | empty (unchanged) | `vm.swappiness` |
| `VFS_CACHE_PRESSURE` | empty (unchanged) | `vm.vfs_cache_pressure` |
| `ZRAM_ALGO` | empty (unchanged) | **Experimental**: re-creates zram with another compressor (swapoff/reset/comp_algorithm/disksize/mkswap/swapon) |
| `ZRAM_MAX_USED_MB` | `300` | The zram re-create is skipped if swap in use exceeds this |

Empty means "do not touch".

## Uninstall

Remove the module in the manager. `uninstall.sh` cleans its own data. Values return to the ROM defaults after reboot.
