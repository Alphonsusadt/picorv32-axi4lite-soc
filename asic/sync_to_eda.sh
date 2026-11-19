#!/usr/bin/env bash
# Salin sumber yang dibutuhkan LibreLane ke folder designs IIC-OSIC-TOOLS.
# Folder itu di-mount ke container sebagai /foss/designs.
#
#   bash asic/sync_to_eda.sh                     (default D:/eda/designs)
#   bash asic/sync_to_eda.sh /c/lokasi/lain/designs
#
# Hasil: <designs>/tugas-soc-design/{rtl,asic}, struktur sama dengan repo,
# sehingga path "dir::../rtl/..." di asic/config.json tetap berlaku.
# Folder runs/ hasil LibreLane di tujuan tidak dihapus.

set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_BASE="${1:-/d/eda/designs}"
DEST="$DEST_BASE/tugas-soc-design"

mkdir -p "$DEST/rtl" "$DEST/asic"

# RTL (hanya .v, struktur folder dipertahankan)
(cd "$ROOT/rtl" && find . -name '*.v' -print0) | while IFS= read -r -d '' f; do
    mkdir -p "$DEST/rtl/$(dirname "$f")"
    cp "$ROOT/rtl/$f" "$DEST/rtl/$f"
done

# Konfigurasi dan sumber ASIC (tanpa hasil build testbench)
cp "$ROOT/asic/config.json" "$ROOT/asic/pin_order.cfg" "$DEST/asic/"
mkdir -p "$DEST/asic/rtl" "$DEST/asic/tb"
cp "$ROOT/asic/rtl/"*.v "$DEST/asic/rtl/"
cp "$ROOT/asic/tb/"*.v "$DEST/asic/tb/"
cp "$ROOT/tb/tb_utils.vh" "$DEST/asic/tb/"
mkdir -p "$DEST/asic/tb/models"
cp "$ROOT/tb/models/tm1638_model.v" "$DEST/asic/tb/models/"

echo "Disalin ke $DEST"
echo "Di container: cd /foss/designs/tugas-soc-design/asic && librelane config.json"
