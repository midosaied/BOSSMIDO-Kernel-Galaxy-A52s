# Changelog

## v1.0

- KernelSU-Next (legacy) with manual hooks for Linux 5.4.302; `path_umount` backport.
- Optional BBR + fq_codel, CAKE, TTL/HL targets, Samsung USB VID/PID option.
- Recovery-flashable zip (repacks existing boot, backup + verification).
- ABI guard with a shipped baseline (13,940 symbols) from a booted build; CI check passed with no differences.
- `bossmido_tuning` module, verified on one device (read-ahead only).
- GitHub Actions workflow. Differs from the device-tested build only by the pinned KernelSU-Next ref and optional inputs.
- Not included: IFB (breaks vendor ABI), WQ_POWER_EFFICIENT (opt-in, experimental).
