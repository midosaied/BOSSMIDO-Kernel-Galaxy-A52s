#!/system/bin/sh
# Shadow Nexus Tuning - runs once after boot. Conservative by design:
# only touches settings that have a value in tuning.conf, logs every change,
# and never aborts the boot (every step is best-effort).

MODDIR=${0%/*}
ROOT=${SHADOWNEXUS_ROOT:-}                      # test hook: prefix for /sys and /proc
CONF=${SHADOWNEXUS_CONF:-/data/adb/shadownexus/tuning.conf}
LOG=${SHADOWNEXUS_LOG:-/data/local/tmp/shadownexus_tuning.log}
WAIT=${SHADOWNEXUS_WAIT:-1}                     # set to 0 in tests

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# write_val <file> <value> : write only if the node exists; log old -> new
write_val() {
  f="$1"; v="$2"
  [ -n "$v" ] || return 0
  if [ ! -e "$f" ]; then log "skip  $f (missing)"; return 0; fi
  old=$(cat "$f" 2>/dev/null)
  if echo "$v" > "$f" 2>/dev/null; then log "ok    $f: $old -> $(cat "$f" 2>/dev/null)"; else log "fail  $f (could not write $v)"; fi
}

is_uint() { case "$1" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }

: > "$LOG"
log "Shadow Nexus Tuning start (kernel $(uname -r))"

# wait for the system to finish booting (up to ~3 min)
if [ "$WAIT" = "1" ]; then
  i=0
  while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 90 ]; do sleep 2; i=$((i+1)); done
  sleep 20
fi

# defaults (used when no user config exists)
READ_AHEAD_KB=512; SWAPPINESS=; VFS_CACHE_PRESSURE=; ZRAM_ALGO=; ZRAM_MAX_USED_MB=300
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1090
  . "$CONF"
  log "config: $CONF"
else
  log "config: none ($CONF) - using safe defaults"
fi

# ---- read-ahead ----
if is_uint "$READ_AHEAD_KB"; then
  for q in "$ROOT"/sys/block/sd*/queue/read_ahead_kb "$ROOT"/sys/block/mmcblk*/queue/read_ahead_kb; do
    [ -e "$q" ] && write_val "$q" "$READ_AHEAD_KB"
  done
elif [ -n "$READ_AHEAD_KB" ]; then log "bad READ_AHEAD_KB='$READ_AHEAD_KB' ignored"; fi

# ---- vm sysctls ----
if is_uint "$SWAPPINESS"; then write_val "$ROOT/proc/sys/vm/swappiness" "$SWAPPINESS"
elif [ -n "$SWAPPINESS" ]; then log "bad SWAPPINESS='$SWAPPINESS' ignored"; fi
if is_uint "$VFS_CACHE_PRESSURE"; then write_val "$ROOT/proc/sys/vm/vfs_cache_pressure" "$VFS_CACHE_PRESSURE"
elif [ -n "$VFS_CACHE_PRESSURE" ]; then log "bad VFS_CACHE_PRESSURE='$VFS_CACHE_PRESSURE' ignored"; fi

# ---- optional zram algorithm (experimental) ----
if [ -n "$ZRAM_ALGO" ]; then
  Z="$ROOT/sys/block/zram0"
  case "$ZRAM_ALGO" in lzo|lzo-rle|lz4|zstd) ;; *) log "zram: unsupported algo '$ZRAM_ALGO' ignored"; ZRAM_ALGO= ;; esac
fi
if [ -n "$ZRAM_ALGO" ]; then
  Z="$ROOT/sys/block/zram0"
  cur=$(sed -n 's/.*\[\(.*\)\].*/\1/p' "$Z/comp_algorithm" 2>/dev/null)
  avail=$(cat "$Z/comp_algorithm" 2>/dev/null)
  used_kb=$(awk '/zram0/ {print $4}' "$ROOT/proc/swaps" 2>/dev/null)
  [ -n "$used_kb" ] || used_kb=0
  prio=$(awk '/zram0/ {print $5}' "$ROOT/proc/swaps" 2>/dev/null)
  if [ ! -d "$Z" ]; then log "zram: $Z missing, skipped"
  elif [ "$cur" = "$ZRAM_ALGO" ]; then log "zram: already $ZRAM_ALGO, nothing to do"
  elif ! echo "$avail" | grep -qw "$ZRAM_ALGO"; then log "zram: kernel does not offer $ZRAM_ALGO ($avail), skipped"
  elif [ "$used_kb" -gt $((ZRAM_MAX_USED_MB*1024)) ]; then log "zram: ${used_kb}KB swap in use > ${ZRAM_MAX_USED_MB}MB, skipped to avoid stalls"
  else
    size=$(cat "$Z/disksize")
    log "zram: $cur -> $ZRAM_ALGO (size $size, prio ${prio:-default})"
    if swapoff /dev/block/zram0 2>>"$LOG"; then
      echo 1 > "$Z/reset"
      echo "$ZRAM_ALGO" > "$Z/comp_algorithm" 2>>"$LOG"
      echo "$size" > "$Z/disksize"
      mkswap /dev/block/zram0 >>"$LOG" 2>&1
      if [ -n "$prio" ]; then swapon -p "$prio" /dev/block/zram0 >>"$LOG" 2>&1; else swapon /dev/block/zram0 >>"$LOG" 2>&1; fi
      log "zram: now $(cat "$Z/comp_algorithm")"
    else
      log "zram: swapoff failed, left untouched"
    fi
  fi
fi

log "done"
exit 0
