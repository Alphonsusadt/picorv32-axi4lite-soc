# Build firmware RISC-V untuk SoC PicoRV32 (dijalankan di WSL/Linux).
#
#   make                     build semua program ROM dan RAM
#   make PROGRAMS=tm1638_demo RAM_PROGRAMS=
#   make clean
#
# Dari Windows (root proyek): make firmware   (memanggil "wsl make -C firmware")
#
# Program ROM (PROGRAMS), berjalan dari 0x0000_0000:
#   build/<prog>.elf, .bin, .lst     file antara dan listing assembly
#   ../rtl/<prog>.hex                1 byte per baris (format file dosen)
#   ../rtl/<prog>_words.hex          1 word per baris, dibaca axi_rom lewat $readmemh
#   bootloader memakai link_boot.ld, yang lain link_rom.ld.
#
# Program RAM (RAM_PROGRAMS, nama <prog>_ram dari <prog>.c), berjalan dari
# 0x1000_0000 setelah diunggah lewat bootloader (skenario B):
#   bin/<prog>_ram.bin, .hex         diunggah dengan tools/upload.py --ram
#
# Program ASIC (ASIC_PROGRAM, dari <prog>.c dengan link_asic.ld: ROM 2 KB,
# RAM 256 B), menjadi ROM kombinasional untuk varian ASIC di ../asic:
#   build/<prog>_asic_words.hex      1 word per baris
#   ../asic/rtl/axi_rom.v            modul axi_rom ASIC (tools/hex_to_rom_v.py)

CROSS   ?= riscv64-unknown-elf-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy
OBJDUMP  = $(CROSS)objdump
SIZE     = $(CROSS)size

PROGRAMS     ?= tm1638_demo bootloader led_pattern nim_scroll
RAM_PROGRAMS ?= led_pattern_ram tm1638_demo_ram nim_scroll_ram
ASIC_PROGRAM ?= nim_scroll
ASIC_ROM      = ../asic/rtl/axi_rom.v

# PicoRV32 di SoC ini tanpa perkalian/pembagian hardware (RV32I).
# Perkalian dan pembagian di C memakai fungsi dari libgcc.
ARCH     = -march=rv32i -mabi=ilp32
CFLAGS   = $(ARCH) -Os -Wall -Wextra -ffreestanding -fno-builtin -mno-relax \
           -ffunction-sections -fdata-sections
LDFLAGS  = $(ARCH) -nostdlib -nostartfiles -Wl,--gc-sections

COMMON   = crt0.S spi.c tm1638.c
HEADERS  = soc.h spi.h tm1638.h uart.h

BUILD    = build
RTL      = ../rtl
BIN      = bin

.PHONY: all clean
.SECONDARY:

all: $(foreach p,$(PROGRAMS),$(RTL)/$(p)_words.hex $(RTL)/$(p).hex) \
     $(foreach p,$(RAM_PROGRAMS),$(BIN)/$(p).bin $(BIN)/$(p).hex)      $(ASIC_ROM)


$(ASIC_ROM): $(BUILD)/$(ASIC_PROGRAM)_asic_words.hex ../tools/hex_to_rom_v.py
	@mkdir -p $(dir $@)
	python3 ../tools/hex_to_rom_v.py $< $@ --addr-bits 9

$(BUILD)/%_asic_words.hex: $(BUILD)/%_asic.bin
	od -An -v -tx4 -w4 $< | tr -d ' ' > $@

$(BUILD)/%_asic.elf: %.c $(COMMON) $(HEADERS) link_asic.ld
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) -Wl,-Tlink_asic.ld -o $@ $(COMMON) $< -lgcc
	$(OBJDUMP) -d $@ > $(BUILD)/$*_asic.lst
	$(SIZE) $@

LDSCRIPT = $(if $(filter bootloader,$*),link_boot.ld,link_rom.ld)

$(BUILD)/%_ram.elf: %.c $(COMMON) $(HEADERS) link_ram.ld
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) -Wl,-Tlink_ram.ld -o $@ $(COMMON) $< -lgcc
	$(OBJDUMP) -d $@ > $(BUILD)/$*_ram.lst
	$(SIZE) $@

$(BUILD)/%.elf: %.c $(COMMON) $(HEADERS) link_rom.ld link_boot.ld
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) -Wl,-T$(LDSCRIPT) -o $@ $(COMMON) $< -lgcc
	$(OBJDUMP) -d $@ > $(BUILD)/$*.lst
	$(SIZE) $@

# Program RAM: disimpan di bin/ (ikut repo) agar bisa diunggah tanpa WSL
$(BIN)/%.bin: $(BUILD)/%.bin
	@mkdir -p $(BIN)
	cp $< $@

$(BIN)/%.hex: $(BUILD)/%.bin
	@mkdir -p $(BIN)
	od -An -v -tx1 -w1 $< | tr -d ' ' > $@

$(BUILD)/%.bin: $(BUILD)/%.elf
	$(OBJCOPY) -O binary $< $@

# 1 byte per baris, sama dengan demo_led_berkedip_xcelium_v2.hex
$(RTL)/%.hex: $(BUILD)/%.bin
	od -An -v -tx1 -w1 $< | tr -d ' ' > $@

# 1 word per baris (little-endian, byte alamat terendah = bit [7:0])
$(RTL)/%_words.hex: $(BUILD)/%.bin
	echo "// Dibuat otomatis dari firmware/$*.c oleh firmware/Makefile. Jangan diedit." > $@
	od -An -v -tx4 -w4 $< | tr -d ' ' >> $@
	@echo "ROM: $$(($$(stat -c %s $<) / 4)) word ditulis ke $@"

clean:
	rm -rf $(BUILD)
