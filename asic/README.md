# Varian ASIC: tugas UTS di atas PicoRV32 (LibreLane, sky130A)

Folder ini membawa SoC yang sama dengan versi FPGA ke GDSII dengan LibreLane.
Chip menjalankan `firmware/nim_scroll.c` dari ROM tetap. Program ini adalah
tugas UTS: NIM `22-505908-TE-55399` berjalan di TM1638, dengan mode S1/S2/S3
dan LED1-3.

## Perbedaan dengan versi FPGA

| Bagian | FPGA (`fpga/`) | ASIC (`asic/`) |
|---|---|---|
| ROM | BRAM, `$readmemh`, bisa ditulis loader UART | Logika kombinasional `asic/rtl/axi_rom.v` (dibuat otomatis), 512 word |
| RAM | 2048 word BRAM | 64 word (256 B) flip-flop |
| Loader | `rtl/uart/rom_loader.v` | Stub `asic/rtl/rom_loader.v` (tanpa loader) |
| DIO TM1638 | `SB_IO` / `IOBUF` | Port terpisah `tm_dio_out`, `tm_dio_oe`, `tm_dio_in` (buffer tri-state di pad) |
| Clock | 12/27 MHz dibagi | `clk` langsung, target 25 MHz (`CLOCK_PERIOD` 40 ns) |
| Reset | Langsung | Disinkronkan (assert asinkron, lepas sinkron) |

`rtl/soc_demo.v` dan seluruh periferal dipakai **tanpa perubahan**. Modul
`axi_rom` dan `rom_loader` diganti hanya lewat daftar file di `config.json`.

Firmware menghitung 1 detik dari register DIV UART (= f_clk / 9600) dan memilih
pembagi SPI `DIV = f_clk / 1 MHz` (SCK <= 500 kHz). Karena itu `CLK_HZ` di
`soc_nim_asic.v` harus sama dengan clock sebenarnya, dan clock minimal 2 MHz
(DIO disinkronkan 2 flip-flop, sehingga perlu DIV >= 2).

## Port

| Port | Arah | Fungsi |
|---|---|---|
| `clk`, `rst_n` | in | Clock 25 MHz, reset aktif rendah |
| `tm_stb`, `tm_clk` | out | STB dan CLK TM1638 |
| `tm_dio_out`, `tm_dio_oe`, `tm_dio_in` | out/out/in | DIO TM1638 (pad dua arah dengan pull-up di luar) |
| `uart_rx`, `uart_tx` | in/out | UART 9600 8N1 (periferal, untuk debug) |
| `led[2:0]` | out | Posisi scroll (GPIO bit 15..13) |
| `trap` | out | CPU trap |

## Alur kerja

1. Firmware ASIC dan ROM (WSL):

   ```bash
   make -C firmware      # juga membuat asic/rtl/axi_rom.v dari nim_scroll (link_asic.ld)
   ```

2. Simulasi RTL top ASIC (Git Bash, OSS CAD Suite):

   ```bash
   bash asic/run_tb.sh
   ```

3. Salin ke folder designs IIC-OSIC-TOOLS (`D:\eda\designs`
   = `/foss/designs` di container):

   ```bash
   bash asic/sync_to_eda.sh
   ```

4. Di dalam container IIC-OSIC-TOOLS (terminal VNC/X atau `docker exec`):

   ```bash
   cd /foss/designs/tugas-soc-design/asic
   librelane --manual-pdk --pdk-root /foss/pdks --pdk sky130A \
             --scl sky130_fd_sc_hd config.json
   ```

   Image `chipathon26` memakai gf180 sebagai default, jadi PDK harus
   disebutkan. Hasil ada di `runs/RUN_<tanggal>/final/` (`gds/`, `def/`,
   `nl/`, `metrics.json`).

5. Lihat layout:

   ```bash
   librelane --manual-pdk --pdk-root /foss/pdks --pdk sky130A \
             --scl sky130_fd_sc_hd config.json --last-run --flow OpenInKLayout
   ```
