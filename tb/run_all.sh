#!/usr/bin/env bash
# Menjalankan testbench SoC, lalu testbench setiap blok.
#
#   bash tb/run_all.sh          semua testbench
#   bash tb/run_all.sh top      hanya SoC
#   bash tb/run_all.sh blocks   hanya blok
#   bash tb/run_all.sh board    hanya top level board iCESugar
#
# Hasil kompilasi, log, dan waveform disimpan di tb/build.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL="$ROOT/rtl"
TB="$ROOT/tb"
BUILD="$TB/build"
MODE="${1:-all}"

mkdir -p "$BUILD"
# $readmemh di iverilog membaca file relatif terhadap folder kerja vvp
cp "$RTL"/*_words.hex "$RTL"/led_pattern.hex "$ROOT"/firmware/bin/*.hex "$BUILD"/

CPU=("$RTL"/picorv32/*.v)
GPIO=("$RTL"/gpio/*.v)
SPI=("$RTL"/spi/*.v "$RTL"/uart/*.v)
TM="$TB/models/tm1638_model.v"
failed=0
total=0

run_tb() {
    local name="$1"; shift
    local path="$1"; shift
    total=$((total + 1))
    printf '%-20s ' "$name"

    if ! iverilog -g2005 -I "$TB" -s "$name" -o "$BUILD/$name.vvp" "$path" "$@" \
            > "$BUILD/$name.log" 2>&1; then
        echo "COMPILE ERROR (lihat tb/build/$name.log)"
        failed=$((failed + 1))
        return
    fi

    (cd "$BUILD" && vvp "$name.vvp") >> "$BUILD/$name.log" 2>&1
    local result
    result="$(grep -a '^RESULT:' "$BUILD/$name.log" || echo 'RESULT: FAIL (simulasi tidak selesai)')"
    echo "${result#RESULT: }"
    case "$result" in
        *PASS*) ;;
        *) failed=$((failed + 1)) ;;
    esac
}

if [ "$MODE" = "all" ] || [ "$MODE" = "top" ]; then
    echo "== SoC =="
    run_tb tb_soc_top "$TB/tb_soc_top.v" \
        "$RTL/soc_demo.v" "$RTL/axi4_lite_interconnect_m1s4.v" "$RTL/axi_rom.v" "$RTL/axi_ram.v" \
        "${GPIO[@]}" "${SPI[@]}" "${CPU[@]}"
    run_tb tb_soc_tm1638 "$TB/tb_soc_tm1638.v" "$TM" \
        "$RTL/soc_demo.v" "$RTL/axi4_lite_interconnect_m1s4.v" "$RTL/axi_rom.v" "$RTL/axi_ram.v" \
        "${GPIO[@]}" "${SPI[@]}" "${CPU[@]}"
    run_tb tb_soc_nim "$TB/tb_soc_nim.v" "$TM" \
        "$RTL/soc_demo.v" "$RTL/axi4_lite_interconnect_m1s4.v" "$RTL/axi_rom.v" "$RTL/axi_ram.v" \
        "${GPIO[@]}" "${SPI[@]}" "${CPU[@]}"
    run_tb tb_soc_loader "$TB/tb_soc_loader.v" \
        "$RTL/soc_demo.v" "$RTL/axi4_lite_interconnect_m1s4.v" "$RTL/axi_rom.v" "$RTL/axi_ram.v" \
        "${GPIO[@]}" "${SPI[@]}" "${CPU[@]}"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "board" ]; then
    echo "== Board =="
    run_tb tb_top_icesugar "$TB/tb_top_icesugar.v" "$ROOT/fpga/top_icesugar.v" \
        "$RTL/soc_demo.v" "$RTL/axi4_lite_interconnect_m1s4.v" "$RTL/axi_rom.v" "$RTL/axi_ram.v" \
        "${GPIO[@]}" "${SPI[@]}" "${CPU[@]}"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "blocks" ]; then
    echo "== Blok =="
    run_tb tb_picorv32_axi "$TB/blocks/tb_picorv32_axi.v" "${CPU[@]}"
    run_tb tb_interconnect "$TB/blocks/tb_interconnect.v" "$RTL/axi4_lite_interconnect_m1s4.v"
    run_tb tb_axi_rom      "$TB/blocks/tb_axi_rom.v"      "$RTL/axi_rom.v"
    run_tb tb_axi_ram      "$TB/blocks/tb_axi_ram.v"      "$RTL/axi_ram.v"
    run_tb tb_gpio         "$TB/blocks/tb_gpio.v"         "$RTL/gpio/gpio.v"
    run_tb tb_gpio_wrapper "$TB/blocks/tb_gpio_wrapper.v" "${GPIO[@]}"
    run_tb tb_spi_core     "$TB/blocks/tb_spi_core.v"     "$RTL/spi/spi_core.v"
    run_tb tb_uart         "$TB/blocks/tb_uart.v"         "$RTL/uart/uart_rx.v" "$RTL/uart/uart_tx.v"
    run_tb tb_rom_loader   "$TB/blocks/tb_rom_loader.v"   "$RTL/uart/uart_rx.v" "$RTL/uart/rom_loader.v"
    run_tb tb_axi4_lite_spi "$TB/blocks/tb_axi4_lite_spi.v" "$TM" "${SPI[@]}" "$RTL/gpio/axi4_lite_slave.v"
fi

echo
echo "$((total - failed)) dari $total testbench lolos. Log ada di tb/build."
[ "$failed" -eq 0 ]
