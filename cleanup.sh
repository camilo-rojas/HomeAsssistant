#!/bin/sh
# Reclaim disk: journal vacuum + docker image prune.
# Every destructive step shows what it will do and asks first.
# Run from the HA OS host shell (needs docker + journalctl).

LOG=/mnt/data/supervisor/homeassistant/cleanup_log.txt
[ -d /mnt/data/supervisor/homeassistant ] || LOG=/tmp/cleanup_log.txt
: > "$LOG"

say() { echo "$*"; echo "$*" >> "$LOG"; }

confirm() {
    printf '%s [y/N]: ' "$1"
    read ans
    echo "PROMPT: $1 -> ${ans:-N}" >> "$LOG"
    case "$ans" in [yY]*) return 0 ;; *) return 1 ;; esac
}

free_now() { df -h /mnt/data | awk 'NR==2 {print $3" used, "$4" free ("$5")"}'; }

say "=== cleanup started: $(date) ==="
say "Before: $(free_now)"
say ""

# ---------------------------------------------------------------
# 1. systemd journal
# ---------------------------------------------------------------
say "--- 1. systemd journal ---"
say "Current: $(journalctl --disk-usage 2>&1)"
if confirm "Vacuum journal down to 100M?"; then
    journalctl --vacuum-size=100M 2>&1 | tee -a "$LOG"
    say "After: $(journalctl --disk-usage 2>&1)"
else
    say "skipped"
fi
say ""

# ---------------------------------------------------------------
# 2. Dangling docker images (untagged layers - always safe)
# ---------------------------------------------------------------
say "--- 2. Dangling docker images ---"
DANGLING=$(docker images -f dangling=true -q 2>/dev/null | wc -l)
say "Dangling image count: $DANGLING"
docker images -f dangling=true --format '{{.ID}}  {{.Size}}  {{.CreatedSince}}' 2>&1 | tee -a "$LOG"
if [ "$DANGLING" -gt 0 ] 2>/dev/null; then
    if confirm "Remove $DANGLING dangling image(s)?"; then
        docker image prune -f 2>&1 | tee -a "$LOG"
    else
        say "skipped"
    fi
else
    say "nothing to do"
fi
say ""

# ---------------------------------------------------------------
# 3. Unused tagged images
# ---------------------------------------------------------------
# These are images no container currently references. On HA OS the Supervisor
# will re-pull one automatically if you later start an add-on that needs it,
# so this is recoverable but costs a download. Listed explicitly, never blind.
say "--- 3. Unused (but tagged) images ---"
say "These belong to no running container. Supervisor re-pulls on demand if needed."
docker images --format '{{.ID}} {{.Repository}}:{{.Tag}} {{.Size}}' 2>/dev/null | while read id repo size; do
    if ! docker ps -a --format '{{.Image}}' 2>/dev/null | grep -q "$repo"; then
        inuse=$(docker ps -a -q --filter "ancestor=$id" 2>/dev/null | wc -l)
        [ "$inuse" -eq 0 ] 2>/dev/null && echo "  UNUSED  $repo  $size" | tee -a "$LOG"
    fi
done
say ""
say "docker system df says (RECLAIMABLE column is the ceiling here):"
docker system df 2>&1 | tee -a "$LOG"
say ""
if confirm "Run 'docker image prune -a' to remove ALL unused images above?"; then
    docker image prune -a -f 2>&1 | tee -a "$LOG"
else
    say "skipped (recommended default - dangling prune in step 2 covers the safe wins)"
fi
say ""


# ---------------------------------------------------------------
# 4-6. ESPHome caches
# ---------------------------------------------------------------
# Do not run these while a device is actively compiling.
ESPH=/mnt/data/supervisor/apps/data/5c53de3b_esphome

# del_path <description> <path> - shows size, prompts, deletes, reports
del_path() {
    desc=$1
    target=$2
    if [ ! -e "$target" ]; then
        say "  not present, skipping: $target"
        return
    fi
    sz=$(du -sh "$target" 2>/dev/null | awk '{print $1}')
    say "  $target  ($sz)"
    if confirm "  Delete $desc ($sz)?"; then
        rm -rf "$target" && say "  removed."
    else
        say "  skipped"
    fi
}

say "--- 4. ESPHome downloaded tarballs (cache/idf/dist) ---"
say "Already extracted into tools/. Re-fetched only if a toolchain is reinstalled."
if [ -d "$ESPH" ]; then
    del_path "the ESPHome dist tarball cache" "$ESPH/cache/idf/dist"
else
    say "ESPHome add-on data not found at $ESPH - skipping steps 4-6"
fi
say ""

say "--- 5. RISC-V toolchain (unused if all your ESP devices are xtensa ESP32) ---"
say "Everything Presence One is a plain ESP32 (xtensa), so riscv32 should be unused."
say "If you later add an ESP32-C3/C6/H2/P4 device, ESPHome re-downloads this (~278MB)."
if [ -d "$ESPH" ]; then
    del_path "the riscv32-esp-elf toolchain" "$ESPH/cache/idf/tools/riscv32-esp-elf"
    del_path "the riscv32 gdb debugger" "$ESPH/cache/idf/tools/riscv32-esp-elf-gdb"
fi
say ""

say "--- 6. ESPHome per-device build dirs ---"
say "NOTE: the dashboard's 'Clean Build Files' button is the preferred way to do this."
say "Deleting here works, but the next compile of each device is a full rebuild."
if [ -d "$ESPH/build" ]; then
    du -sh "$ESPH"/build/* 2>/dev/null | sort -rh | tee -a "$LOG"
    if confirm "Delete ALL ESPHome build dirs?"; then
        rm -rf "$ESPH"/build/* && say "removed."
    else
        say "skipped (recommended - use the dashboard button instead)"
    fi
fi
say ""
say "After:  $(free_now)"
say "=== cleanup finished: $(date) ==="
say ""
say "Log: $LOG"
