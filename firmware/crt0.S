// Kode awal setelah reset: siapkan stack, salin .data ke RAM, nolkan .bss,
// lalu panggil main(). PicoRV32 mulai mengeksekusi dari alamat 0x0000_0000.

    .section .text.start
    .global _start
_start:
    la    sp, __stack_top

    // Salin .data dari ROM ke RAM
    la    t0, __data_load
    la    t1, __data_start
    la    t2, __data_end
1:  bgeu  t1, t2, 2f
    lw    t3, 0(t0)
    sw    t3, 0(t1)
    addi  t0, t0, 4
    addi  t1, t1, 4
    j     1b

    // Nolkan .bss
2:  la    t1, __bss_start
    la    t2, __bss_end
3:  bgeu  t1, t2, 4f
    sw    zero, 0(t1)
    addi  t1, t1, 4
    j     3b

4:  call  main

    // main() tidak seharusnya kembali; jika kembali, berhenti di sini
5:  j     5b
