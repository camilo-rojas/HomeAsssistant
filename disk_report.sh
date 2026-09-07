#!/bin/sh
# Disk usage investigation - writes a single report file for later review.
# Run as root, ideally from the HA OS host shell or SSH add-on with protection mode off.

# Pick the first writable location that maps into the HA config dir.
OUT=""
for d in /config /mnt/data/supervisor/homeassistant /homeassistant /tmp; do
    if [ -d "$d" ] && [ -w "$d" ]; then
        OUT="$d/disk_report.txt"
        break
    fi
done
[ -z "$OUT" ] && { echo "No writable output dir found."; exit 1; }

: > "$OUT"

run() {
    title=$1
    shift
    {
        echo ""
        echo "===================================================================="
        echo "== $title"
        echo "== \$ $*"
        echo "===================================================================="
        sh -c "$*" 2>&1
        echo "[exit: $?]"
    } >> "$OUT"
}

{
    echo "Disk report"
    echo "date:    $(date 2>/dev/null)"
    echo "host:    $(hostname 2>/dev/null)"
    echo "kernel:  $(uname -a 2>/dev/null)"
    echo "whoami:  $(id -un 2>/dev/null) (uid $(id -u 2>/dev/null))"
    echo ""
    echo "tool availability:"
    for t in docker du find lsof sort awk sed; do
        p=$(command -v "$t" 2>/dev/null)
        echo "  $t: ${p:-NOT FOUND}"
    done
} >> "$OUT"

# ---- Baseline: where is the space actually gone, at the filesystem level ----
run "0a. Filesystem usage" "df -h"
run "0b. Inode usage (a full inode table also reports 'disk full')" "df -i"

# ---- 1. Docker's own accounting, including the volumes section ----
run "1a. docker system df (summary)" "docker system df"
run "1b. docker system df -v (volumes section onward)" "docker system df -v | sed -n '/Local Volumes/,\$p'"
run "1c. docker system df -v (full, in case the split above misses)" "docker system df -v"

# ---- 2. Per-area supervisor usage ----
run "2. Supervisor areas" "du -sh /mnt/data/supervisor/* 2>/dev/null | sort -rh | head -30"

# ---- 3. Per-addon data volumes ----
run "3. Add-on data volumes (this HA OS uses apps/; addons/ kept for older layouts)" "du -sh /mnt/data/supervisor/apps/data/* /mnt/data/supervisor/addons/data/* 2>/dev/null | sort -rh"

# ---- 4. Docker's tree ----
run "4. Docker tree" "du -sh /mnt/data/docker/* 2>/dev/null | sort -rh"

# ---- 5. Large files anywhere on the data disk ----
# 512-byte blocks: portable across busybox and GNU find (the "+200M" suffix form silently matched nothing)
run "5. Files over 200M on /mnt/data" "find /mnt/data -xdev -type f -size +409600 -exec ls -lh {} + 2>/dev/null | awk '{print \$5, \$9}' | sort -rh | head -20"

# ---- 6. Deleted-but-open files ----
run "6. Deleted files still held open" "lsof -nP 2>/dev/null | grep -i deleted | awk '{print \$1, \$7, \$9}' | sort -u | head -20"

# ---- 7. Container writable layers ----
run "7. Container writable layer sizes" "docker ps -s --format '{{.Names}}\t{{.Size}}' | sort -k2 -rh | head -20"

# ---- Extras: common HA-specific culprits not in the original list ----
run "8. Backups dir (frequent multi-GB culprit)" "du -sh /mnt/data/supervisor/backup 2>/dev/null; ls -lh /mnt/data/supervisor/backup 2>/dev/null | head -30"
run "9. Config dir top-level, largest first" "du -sh /mnt/data/supervisor/homeassistant/* 2>/dev/null | sort -rh | head -25"
run "10. Recorder database size" "ls -lh /mnt/data/supervisor/homeassistant/home-assistant_v2.db* 2>/dev/null"
run "11. Dangling/unused docker images" "docker images -a --format '{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.ID}}' | sort -k2 -rh | head -25"
run "12. Journal / log usage" "du -sh /var/log 2>/dev/null; journalctl --disk-usage 2>/dev/null"
run "13. Deepest 25 directories over 100M on /mnt/data" "du -xh /mnt/data 2>/dev/null | sort -rh | head -25"

run "14. app_configs and share" "du -sh /mnt/data/supervisor/app_configs/* /mnt/data/supervisor/share/* 2>/dev/null | sort -rh | head -20"

# ---- 15. Resolve the ~4.5G unaccounted for at the top of /mnt/data ----
run "15. Top level of /mnt/data (accounts for the gap)" "du -xh -d 1 /mnt/data 2>/dev/null | sort -rh"
run "15b. Top level of /mnt/data/supervisor" "du -xh -d 1 /mnt/data/supervisor 2>/dev/null | sort -rh"

# ---- 16. ESPHome cache, broken out by version so stale toolchains are visible ----
run "16a. ESPHome data dir, top level" "du -xh -d 1 /mnt/data/supervisor/apps/data/5c53de3b_esphome 2>/dev/null | sort -rh"
run "16b. ESPHome cache breakdown" "du -xh -d 2 /mnt/data/supervisor/apps/data/5c53de3b_esphome/cache 2>/dev/null | sort -rh | head -30"
run "16c. IDF toolchains, per version dir (stale versions show here)" "du -sh /mnt/data/supervisor/apps/data/5c53de3b_esphome/cache/idf/tools/*/* 2>/dev/null | sort -rh"
run "16d. IDF dist (downloaded tarballs, pure cache)" "du -sh /mnt/data/supervisor/apps/data/5c53de3b_esphome/cache/idf/dist 2>/dev/null; ls -lh /mnt/data/supervisor/apps/data/5c53de3b_esphome/cache/idf/dist 2>/dev/null | head -40"
run "16e. Installed ESP-IDF versions" "ls -la /mnt/data/supervisor/apps/data/5c53de3b_esphome/cache/idf/ 2>/dev/null; ls -la /mnt/data/supervisor/apps/data/5c53de3b_esphome/cache/idf/tools/ 2>/dev/null"
run "16f. ESPHome build dirs (per-device, regenerable)" "du -sh /mnt/data/supervisor/apps/data/5c53de3b_esphome/build/* 2>/dev/null | sort -rh | head -30"

echo "" >> "$OUT"
echo "== end of report ==" >> "$OUT"

echo "Report written to: $OUT"
echo "Size: $(wc -c < "$OUT") bytes"
