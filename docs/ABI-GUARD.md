# ABI guard

## Why

The phone's vendor modules are prebuilt. With `CONFIG_MODVERSIONS`, each exported symbol has a CRC; if a kernel change alters a struct or function signature, the CRC changes and the module is refused, which can mean no Wi-Fi, no camera, or a bootloop. The IFB experiment caused exactly this.

## How

`tools/abi_check.py` compares `Module.symvers` from a build with a stored baseline.

```sh
python3 tools/abi_check.py extract Module.symvers abi/baseline.symvers.gz
python3 tools/abi_check.py check   Module.symvers abi/baseline.symvers.gz --report report.txt
```

Exit codes: `0` ok (added symbols are fine), `1` changed or removed CRCs, `2` empty or missing input.

## Creating the baseline (one-time, required)

The baseline must come from a build you have **booted successfully**:

1. Run the workflow once and flash/boot that build.
2. If it works, download the `abi-files` artifact of that run.
3. Commit its baseline as `abi/baseline.symvers.gz`.

Without a baseline the workflow only warns. The repository now ships `abi/baseline.symvers.gz`, exported from a build that booted on the device (13,940 symbols). A later run against it passed with 0 changed, 0 removed, 0 added. If you build a different kernel tree or toolchain, create your own baseline.

## Limits

It protects the kernel's exported-symbol ABI only. It cannot detect runtime behaviour problems.
