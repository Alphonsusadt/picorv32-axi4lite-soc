/* Linker script program yang diunggah ke RAM lewat bootloader (skenario B).
 * Kode, data, dan stack semuanya di RAM. 7 KB pertama untuk program; 1 KB
 * teratas dipakai stack (bootloader sudah tidak berjalan saat program mulai). */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x10000000, LENGTH = 7K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.start))
        *(.text .text.*)
        *(.rodata .rodata.* .srodata .srodata.*)
        . = ALIGN(4);
    } > RAM

    /* Data sudah ada di tempatnya; crt0 menyalin ke alamat yang sama */
    .data : {
        __data_start = .;
        *(.data .data.* .sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM
    __data_load = LOADADDR(.data);

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    __stack_top = 0x10000000 + 8K;

    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.note*) *(.eh_frame*) }
}
