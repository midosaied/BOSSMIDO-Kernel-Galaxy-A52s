#!/usr/bin/env python3
"""BOSSMIDO KERNEL - ABI guard.

Vendor kernel modules (Wi-Fi, camera, audio, ...) are prebuilt against a specific
kernel ABI. With CONFIG_MODVERSIONS every exported symbol carries a CRC computed
from the types it touches. If a config option changes a struct layout (for example
CONFIG_NET_REDIRECT adds bits to struct sk_buff) the CRCs change and the prebuilt
modules refuse to load -> the phone hangs at boot.

This tool compares the Module.symvers of a new build with a known-good baseline
and fails when any baseline symbol has a different CRC or disappeared.

Usage:
  abi_check.py extract <Module.symvers> <baseline.symvers.gz>
  abi_check.py check   <Module.symvers> <baseline.symvers.gz> [--report FILE]
"""
import argparse
import gzip
import sys


def read_symvers(path):
    """Return {symbol: crc} from a Module.symvers (plain) or a baseline (.gz)."""
    opener = gzip.open if path.endswith(".gz") else open
    out = {}
    with opener(path, "rt", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t") if "\t" in line else line.split()
            if len(parts) < 2 or not parts[0].startswith("0x"):
                continue
            out[parts[1]] = parts[0].lower()
    return out


def cmd_extract(args):
    syms = read_symvers(args.symvers)
    if not syms:
        print("ERROR: no symbols found in %s" % args.symvers, file=sys.stderr)
        return 2
    with gzip.open(args.baseline, "wt", encoding="utf-8") as fh:
        fh.write("# BOSSMIDO KERNEL ABI baseline: <crc> <symbol>\n")
        for name in sorted(syms):
            fh.write("%s\t%s\n" % (syms[name], name))
    print("baseline written: %d symbols -> %s" % (len(syms), args.baseline))
    return 0


def cmd_check(args):
    new = read_symvers(args.symvers)
    base = read_symvers(args.baseline)
    if not new:
        print("ERROR: no symbols found in new Module.symvers", file=sys.stderr)
        return 2
    if not base:
        print("ERROR: baseline is empty or unreadable", file=sys.stderr)
        return 2
    changed = sorted(s for s in base if s in new and base[s] != new[s])
    removed = sorted(s for s in base if s not in new)
    added = sorted(s for s in new if s not in base)
    lines = [
        "ABI check: baseline=%d new=%d" % (len(base), len(new)),
        "  changed CRC : %d" % len(changed),
        "  removed     : %d" % len(removed),
        "  added (ok)  : %d" % len(added),
    ]
    for title, items, show in (("CHANGED", changed, lambda s: "%s %s -> %s" % (s, base[s], new[s])),
                               ("REMOVED", removed, lambda s: "%s (was %s)" % (s, base[s]))):
        if items:
            lines.append("")
            lines.append("%s (first 40):" % title)
            lines.extend("  " + show(s) for s in items[:40])
    ok = not changed and not removed
    lines.append("")
    lines.append("RESULT: " + ("PASS - vendor modules should still load"
                               if ok else "FAIL - prebuilt vendor modules may refuse to load (bootloop risk)"))
    text = "\n".join(lines)
    print(text)
    if args.report:
        with open(args.report, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("extract")
    e.add_argument("symvers")
    e.add_argument("baseline")
    e.set_defaults(fn=cmd_extract)
    c = sub.add_parser("check")
    c.add_argument("symvers")
    c.add_argument("baseline")
    c.add_argument("--report")
    c.set_defaults(fn=cmd_check)
    args = ap.parse_args()
    try:
        return args.fn(args)
    except FileNotFoundError as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
