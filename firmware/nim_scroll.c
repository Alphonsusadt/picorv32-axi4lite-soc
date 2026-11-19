// Tugas UTS (NIM berjalan di TM1638) sebagai firmware PicoRV32 di ROM.
//
// Perilaku sama dengan Tugas_UTS/tcl/top_tm1638_demo.v, tetapi TM1638
// dikendalikan CPU lewat SPI universal, bukan FSM hardware:
//
//   Tombol  Mode  Animasi       Interval
//   S1      00    bolak-balik   1 detik
//   S2      01    ke kiri       1 detik
//   S3      10    ke kanan      1 detik
//
// - Mode dipilih saat tombol baru ditekan, dipertahankan saat dilepas.
//   Penekanan bersamaan: prioritas S1, S2, lalu S3. Mode awal 00.
// - LED1/LED2/LED3 TM1638 menunjukkan mode 00/01/10.
// - Teks "22-505908-TE-55399" (18 karakter) bergeser 1 posisi per detik,
//   posisi 0..26 sehingga NIM masuk dan keluar sepenuhnya dari 8 digit.
//   Model array 44 elemen UTS: digit d menampilkan karakter (d + pos - 8).
// - 1 detik diukur dengan rdcycle. Clock SoC dihitung dari register DIV UART
//   (DIV = f_clk / 9600), jadi ROM yang sama tepat di iCESugar dan Tang Nano.
// - LED board (GPIO bit 13 ke atas) menampilkan posisi scroll.
// - Versi ASIC (nim_scroll_asic, link_asic.ld) memakai sumber yang sama.

#include <stdint.h>
#include "soc.h"
#include "spi.h"
#include "tm1638.h"

#define BAUD        9600u
#define TEXT_LEN    18
#define MAX_SCROLL  26

enum { MODE_PINGPONG = 0, MODE_LEFT = 1, MODE_RIGHT = 2 };

// Pola segmen: bit0 = a ... bit6 = g (sama dengan localparam SEG_* UTS)
#define SEG_DASH 0x40
#define SEG_T    0x70
#define SEG_E    0x79

static const uint8_t text[TEXT_LEN] = {
    0x5B, 0x5B, SEG_DASH,                       // 2 2 -
    0x6D, 0x3F, 0x6D, 0x6F, 0x3F, 0x7F,         // 5 0 5 9 0 8
    SEG_DASH, SEG_T, SEG_E, SEG_DASH,           // - T E -
    0x6D, 0x6D, 0x4F, 0x6F, 0x6F,               // 5 5 3 9 9
};

static inline uint32_t rdcycle(void)
{
    uint32_t c;
    __asm__ volatile ("rdcycle %0" : "=r"(c));
    return c;
}

static uint32_t cycles_per_second(void)
{
    if (UART_ID == UART_ID_VALUE)
        return (UART_DIV & 0xFFFFu) * BAUD;
    return 750000u;                       // tanpa UART: anggap clock iCESugar
}

static uint8_t char_at(int index)
{
    return (index >= 0 && index < TEXT_LEN) ? text[index] : 0x00;
}

static void show(uint32_t pos, uint32_t mode)
{
    uint8_t ram[16];
    for (uint32_t d = 0; d < 8; d++) {
        ram[d * 2]     = char_at((int)d + (int)pos - 8);
        ram[d * 2 + 1] = (d == mode) ? 1 : 0;     // LED1..LED3 = mode
    }
    tm1638_write_block(0, ram, 16);
}

int main(void)
{
    uint32_t mode = MODE_PINGPONG;
    uint32_t pos  = 0;
    int      left = 1;                    // arah bolak-balik: 1 = ke kiri
    uint8_t  prev_keys = 0;

    const uint32_t second = cycles_per_second();
    uint32_t last = rdcycle();

    if (!spi_present()) {
        for (;;)
            GPIO_LED = 0x5555u << 1;      // tanpa SPI: pola diam sebagai tanda
    }

    // Kecerahan maksimum seperti UTS. Pembagi SPI agar SCK <= 500 kHz:
    // 0 di FPGA (clock SoC < 1 MHz), 25 di ASIC 25 MHz.
    tm1638_init_div(0, 7, second / 1000000u);
    show(pos, mode);
    GPIO_LED = pos << 13;

    for (;;) {
        int changed = 0;

        // Tombol: hanya penekanan baru yang mengganti mode
        uint8_t keys    = tm1638_read_buttons() & 0x07;
        uint8_t pressed = keys & (uint8_t)~prev_keys;
        prev_keys = keys;
        if (pressed) {
            uint32_t m = (pressed & 1) ? MODE_PINGPONG :
                         (pressed & 2) ? MODE_LEFT : MODE_RIGHT;
            if (m != mode) {
                mode = m;
                changed = 1;
            }
        }

        // Animasi tiap 1 detik
        uint32_t now = rdcycle();
        if (now - last >= second) {
            last += second;
            if (mode == MODE_PINGPONG) {
                if (left) {
                    if (pos >= MAX_SCROLL) { pos = MAX_SCROLL - 1; left = 0; }
                    else                    pos++;
                } else {
                    if (pos == 0)           { pos = 1; left = 1; }
                    else                    pos--;
                }
            } else if (mode == MODE_LEFT) {
                left = 1;
                pos  = (pos >= MAX_SCROLL) ? 0 : pos + 1;
            } else {
                left = 0;
                pos  = (pos == 0) ? MAX_SCROLL : pos - 1;
            }
            changed = 1;
        }

        if (changed) {
            show(pos, mode);
            GPIO_LED = pos << 13;
        }
    }
}
