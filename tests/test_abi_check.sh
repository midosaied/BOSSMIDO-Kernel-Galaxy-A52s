#!/bin/sh
# Self-test for tools/abi_check.py using synthetic Module.symvers files.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tool="$here/../tools/abi_check.py"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

printf '0x11111111\tskb_push\tvmlinux\tEXPORT_SYMBOL\n0x22222222\tkfree\tvmlinux\tEXPORT_SYMBOL\n0x33333333\talloc_skb\tvmlinux\tEXPORT_SYMBOL_GPL\n' > "$tmp/base.symvers"
python3 "$tool" extract "$tmp/base.symvers" "$tmp/base.gz" >/dev/null

# 1) identical -> pass
python3 "$tool" check "$tmp/base.symvers" "$tmp/base.gz" >/dev/null || { echo "FAIL: identical should pass"; exit 1; }

# 2) added symbol only -> pass
cp "$tmp/base.symvers" "$tmp/added.symvers"
printf '0x44444444\tnew_symbol\tvmlinux\tEXPORT_SYMBOL\n' >> "$tmp/added.symvers"
python3 "$tool" check "$tmp/added.symvers" "$tmp/base.gz" >/dev/null || { echo "FAIL: added should pass"; exit 1; }

# 3) changed CRC -> fail
sed 's/0x11111111/0x99999999/' "$tmp/base.symvers" > "$tmp/changed.symvers"
if python3 "$tool" check "$tmp/changed.symvers" "$tmp/base.gz" >/dev/null; then echo "FAIL: changed CRC should fail"; exit 1; fi

# 4) removed symbol -> fail
grep -v kfree "$tmp/base.symvers" > "$tmp/removed.symvers"
if python3 "$tool" check "$tmp/removed.symvers" "$tmp/base.gz" >/dev/null; then echo "FAIL: removed should fail"; exit 1; fi

# 5) empty new file -> error (exit 2), not pass
: > "$tmp/empty.symvers"
if python3 "$tool" check "$tmp/empty.symvers" "$tmp/base.gz" >/dev/null 2>&1; then echo "FAIL: empty should not pass"; exit 1; fi

echo "abi_check self-test: OK"
