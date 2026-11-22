# Changelog

## Unreleased

- Rebrand to **Shadow Nexus Kernel** (SNK v1.0, codename OBSIDIAN, Shadow Engineering): new name, artwork, installer banner, zip names (`ShadowNexus-A528B-<ver>.zip`, `ShadowNexus-Tuning-<ver>.zip`).
- Tuning module renamed: id `shadownexus_tuning`, config `/data/adb/shadownexus/tuning.conf`, log `/data/local/tmp/shadownexus_tuning.log`. If you installed the old `bossmido_tuning` module, remove it and copy your config if you had one.

- Optional `mglru` workflow input (Multi-Gen LRU backport from ghost_kernel_a52s_5g). Experimental, untested on device.

## v1.0

- KernelSU-Next (legacy) with manual hooks for Linux 5.4.302; `path_umount` backport.
- Optional BBR + fq_codel, CAKE, TTL/HL targets, Samsung USB VID/PID option.
- Recovery-flashable zip (repacks existing boot, backup + verification).
- ABI guard with a shipped baseline (13,940 symbols) from a booted build; CI check passed with no differences.
- `shadownexus_tuning` module, verified on one device (read-ahead only).
- GitHub Actions workflow. Differs from the device-tested build only by the pinned KernelSU-Next ref and optional inputs.
- Not included: IFB (breaks vendor ABI), WQ_POWER_EFFICIENT (opt-in, experimental).
