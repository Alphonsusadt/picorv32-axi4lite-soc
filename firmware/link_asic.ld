/* Linker script program ROM untuk varian ASIC (asic/).
 * ROM 2 KB (512 word, logika kombinasional) dan RAM 256 B (64 word
 * flip-flop), sesuai parameter di asic/rtl/soc_nim_asic.v. Linker menolak
 * program yang tidak muat. */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 2K
    RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 256
}

SECTIONS
{
    .text : {
        KEEP(*(.text.start))
        *(.text .text.*)
        *(.rodata .rodata.* .srodata .srodata.*)
        . = ALIGN(4);
    } > ROM

    .data : {
        __data_start = .;
        *(.data .data.* .sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM AT > ROM
    __data_load = LOADADDR(.data);

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /* Sisakan minimal 128 B untuk stack */
    ASSERT(__bss_end + 128 <= __stack_top, "RAM ASIC terlalu kecil untuk .data/.bss + stack")

    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.note*) *(.eh_frame*) }
}
