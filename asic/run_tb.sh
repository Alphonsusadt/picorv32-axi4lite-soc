#!/usr/bin/env bash
# Simulasi RTL top ASIC (soc_nim_asic) dengan model TM1638.
#   bash asic/run_tb.sh          (+vcd untuk waveform: bash asic/run_tb.sh +vcd)
# Butuh iverilog (OSS CAD Suite). Sekitar 10 menit.

set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL="$ROOT/rtl"
A="$ROOT/asic"
BUILD="$A/tb/build"
mkdir -p "$BUILD"

iverilog -g2005 -I "$ROOT/tb" -s tb_soc_nim_asic -o "$BUILD/tb_soc_nim_asic.vvp" \
    "$A/tb/tb_soc_nim_asic.v" "$ROOT/tb/models/tm1638_model.v" \
    "$A/rtl/soc_nim_asic.v" "$A/rtl/axi_rom.v" "$A/rtl/rom_loader.v" \
    "$RTL/soc_demo.v" "$RTL/axi4_lite_interconnect_m1s4.v" "$RTL/axi_ram.v" \
    "$RTL"/gpio/*.v "$RTL"/spi/*.v \
    "$RTL/uart/uart_rx.v" "$RTL/uart/uart_tx.v" "$RTL/uart/axi4_lite_uart.v" "$RTL/uart/axi4_lite_split2.v" \
    "$RTL"/picorv32/*.v

cd "$BUILD"
vvp tb_soc_nim_asic.vvp "$@" | tee tb_soc_nim_asic.log | grep -a "PASS\|FAIL\|INFO\|RESULT\|TIMEOUT"
