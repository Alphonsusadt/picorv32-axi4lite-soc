# Build PicoRV32 AXI4-Lite SoC dengan OSS CAD Suite.
# Diadaptasi dari arumdapta98/oss-cad-suite-tcl-template.
# Seluruh proses build (sintesis, nextpnr, bitstream) ada di tcl/build.tcl.
#
# Board dipilih dengan BOARD (default icesugar):
#   make all                      iCESugar v1.5   (iCE40UP5K)
#   make all BOARD=tangnano20k    Tang Nano 20K   (GW2AR-18)
#
# Target:
#   make all     isi ROM, sintesis, place and route, lalu bitstream (sama dengan make build)
#   make flash   unggah bitstream ke board
#   make hex     buat ulang file ROM 1 word per baris dari file .hex
#   make test    jalankan semua testbench (butuh bash dari Git)
#   make clean   hapus folder build
#
# Jalankan setenv.bat dulu agar tool OSS CAD Suite ada di PATH.

BOARD ?= icesugar

DIR_BUILD = build/$(BOARD)

ifeq ($(BOARD),icesugar)
BITFILE = $(DIR_BUILD)/top_icesugar.bin
FLASH   = icesprog -w $(BITFILE)
FLASH_PERMANENT = $(FLASH)
else ifeq ($(BOARD),tangnano20k)
BITFILE = $(DIR_BUILD)/top_tangnano20k.fs
# openFPGALoader tidak bisa membuka Tang Nano 20K di Windows selama driver FTDI
# bawaan (FTDIBUS) terpasang, sehingga upload memakai Gowin Programmer.
# Jika driver sudah diganti WinUSB lewat Zadig:
#   make flash BOARD=tangnano20k FLASH_TOOL=openfpgaloader
FLASH_TOOL ?= gowin
GOWIN_PROGRAMMER ?= C:/Gowin/Gowin_V1.9.12.03_x64/Programmer/bin/programmer_cli.exe
ifeq ($(FLASH_TOOL),gowin)
# --run 2: SRAM Program (hilang saat power off)
# --run 8: exFlash Erase,Program (permanen; belum diuji)
# Gowin Programmer selalu menutup dengan "Error found!" untuk bitstream buatan
# OSS CAD Suite walaupun upload berhasil, sehingga kode keluarnya diabaikan dan
# register status dibaca sesudahnya. Status 0x....2... (bit 13, DONE) berarti
# FPGA selesai dikonfigurasi; bit 0 = 1 berarti CRC error.
FLASH_IGNORE_ERROR = -
FLASH   = "$(GOWIN_PROGRAMMER)" --device GW2AR-18C --run 2 --fsFile "$(CURDIR)/$(BITFILE)"
FLASH_PERMANENT = "$(GOWIN_PROGRAMMER)" --device GW2AR-18C --run 8 --fsFile "$(CURDIR)/$(BITFILE)"
FLASH_STATUS = "$(GOWIN_PROGRAMMER)" --device GW2AR-18C --run 0
else
FLASH   = openFPGALoader -b tangnano20k $(BITFILE)
FLASH_PERMANENT = openFPGALoader -b tangnano20k -f $(BITFILE)
endif
else
$(error BOARD tidak dikenal: $(BOARD). Pilih icesugar atau tangnano20k)
endif

SOURCES = $(wildcard fpga/*.v rtl/*.v rtl/*/*.v constraints/*) \
          rtl/demo_led_berkedip_xcelium_v2.hex tcl/build.tcl tcl/hex_bytes_to_words.tcl

.PHONY: all build flash flash-permanent hex test test-board clean

all: build

build: $(BITFILE)

# Perintah di bawah hanya memanggil program OSS CAD Suite, sehingga berjalan
# baik di CMD maupun di Git Bash.
$(BITFILE): $(SOURCES)
	yosys -p "tcl tcl/build.tcl $(BOARD)"

flash: $(BITFILE)
	$(FLASH_IGNORE_ERROR)$(FLASH)
	$(FLASH_STATUS)

flash-permanent: $(BITFILE)
	$(FLASH_IGNORE_ERROR)$(FLASH_PERMANENT)
	$(FLASH_STATUS)

hex:
	yosys -c tcl/hex_bytes_to_words.tcl

test:
	bash tb/run_all.sh

# Simulasi top level iCESugar dengan ukuran memori FPGA
test-board:
	bash tb/run_all.sh board

clean:
	yosys -q -p "tcl tcl/clean.tcl"
