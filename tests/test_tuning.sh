#!/bin/sh
# Self-test for module/shadownexus_tuning/service.sh against a fake /sys and /proc tree.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
svc="$here/../module/shadownexus_tuning/service.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

mkfake() {
  rm -rf "$tmp/root"; mkdir -p "$tmp/root/sys/block/sda/queue" "$tmp/root/sys/block/zram0" "$tmp/root/proc/sys/vm" "$tmp/bin"
  echo 128 > "$tmp/root/sys/block/sda/queue/read_ahead_kb"
  echo 60  > "$tmp/root/proc/sys/vm/swappiness"
  echo 100 > "$tmp/root/proc/sys/vm/vfs_cache_pressure"
  echo "lzo [lzo-rle] lz4 zstd" > "$tmp/root/sys/block/zram0/comp_algorithm"
  echo 3854651392 > "$tmp/root/sys/block/zram0/disksize"
  echo 0 > "$tmp/root/sys/block/zram0/reset"
  printf 'Filename Type Size Used Priority\n/dev/block/zram0 partition 3763932 %s 32758\n' "${1:-1000}" > "$tmp/root/proc/swaps"
  for c in swapoff mkswap swapon; do printf '#!/bin/sh\necho "%s $*" >> "%s/cmds"\n' "$c" "$tmp" > "$tmp/bin/$c"; chmod +x "$tmp/bin/$c"; done
  printf '#!/bin/sh\necho 1\n' > "$tmp/bin/getprop"; chmod +x "$tmp/bin/getprop"
  : > "$tmp/cmds"
}
run() { PATH="$tmp/bin:$PATH" SHADOWNEXUS_ROOT="$tmp/root" SHADOWNEXUS_CONF="$tmp/conf" SHADOWNEXUS_LOG="$tmp/log" SHADOWNEXUS_WAIT=0 sh "$svc"; }
val() { cat "$tmp/root/$1"; }
fail() { echo "FAIL: $1"; cat "$tmp/log"; exit 1; }

# 1) no config -> only safe default read-ahead 512, nothing else touched
mkfake; rm -f "$tmp/conf"; run
[ "$(val sys/block/sda/queue/read_ahead_kb)" = 512 ] || fail "default read_ahead"
[ "$(val proc/sys/vm/swappiness)" = 60 ] || fail "swappiness must be untouched"
[ ! -s "$tmp/cmds" ] || fail "no swap commands expected"

# 2) config sets sysctls
mkfake; printf 'READ_AHEAD_KB=256\nSWAPPINESS=100\nVFS_CACHE_PRESSURE=50\n' > "$tmp/conf"; run
[ "$(val sys/block/sda/queue/read_ahead_kb)" = 256 ] || fail "read_ahead 256"
[ "$(val proc/sys/vm/swappiness)" = 100 ] || fail "swappiness 100"
[ "$(val proc/sys/vm/vfs_cache_pressure)" = 50 ] || fail "vfs 50"

# 3) bad values are ignored
mkfake; printf 'READ_AHEAD_KB=abc\nSWAPPINESS=-5\n' > "$tmp/conf"; run
[ "$(val sys/block/sda/queue/read_ahead_kb)" = 128 ] || fail "bad read_ahead must be ignored"
[ "$(val proc/sys/vm/swappiness)" = 60 ] || fail "bad swappiness must be ignored"

# 4) zram algo change runs the full sequence
mkfake; printf 'READ_AHEAD_KB=\nZRAM_ALGO=lz4\n' > "$tmp/conf"; run
grep -q '^swapoff /dev/block/zram0' "$tmp/cmds" || fail "swapoff expected"
grep -q '^mkswap /dev/block/zram0' "$tmp/cmds" || fail "mkswap expected"
grep -q '^swapon -p 32758 /dev/block/zram0' "$tmp/cmds" || fail "swapon with original priority expected"
[ "$(val sys/block/zram0/comp_algorithm)" = lz4 ] || fail "algorithm must be written"

# 5) too much swap in use -> skipped
mkfake 900000; printf 'ZRAM_ALGO=lz4\nZRAM_MAX_USED_MB=300\n' > "$tmp/conf"; run
[ ! -s "$tmp/cmds" ] || fail "zram change must be skipped when swap is busy"

# 6) unsupported algorithm -> skipped
mkfake; printf 'ZRAM_ALGO=deflate\n' > "$tmp/conf"; run
[ ! -s "$tmp/cmds" ] || fail "unsupported algo must be skipped"

# 7) algorithm not offered by kernel -> skipped
mkfake; echo "lzo [lzo-rle]" > "$tmp/root/sys/block/zram0/comp_algorithm"; printf 'ZRAM_ALGO=zstd\n' > "$tmp/conf"; run
[ ! -s "$tmp/cmds" ] || fail "unavailable algo must be skipped"

echo "tuning self-test: OK"
