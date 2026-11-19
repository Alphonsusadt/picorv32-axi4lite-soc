// Driver TM1638 di atas driver SPI universal.
// Ditulis untuk modul "LED&KEY": 8 digit 7-segmen, 8 LED, 8 tombol.
#ifndef TM1638_H
#define TM1638_H

#include <stdint.h>

// Inisialisasi SPI untuk TM1638 dan bersihkan display.
// brightness 0-7, cs = nomor chip select (0 atau 1).
void     tm1638_init(uint32_t cs, uint32_t brightness);

// Sama dengan tm1638_init, dengan pembagi SPI: SCK = f_clk / (2 (div + 1)).
// TM1638 maksimal 1 MHz; pilih div agar SCK <= 500 kHz (mis. f_clk / 1 MHz).
void     tm1638_init_div(uint32_t cs, uint32_t brightness, uint32_t div);

// Tulis langsung 1 byte ke alamat display (0-15)
void     tm1638_write(uint32_t addr, uint8_t value);

// Tulis n byte berurutan mulai alamat start dengan mode auto-increment
// (16 byte = seluruh display: alamat genap digit, ganjil LED)
void     tm1638_write_block(uint32_t start, const uint8_t *data, uint32_t n);

// Digit 0-7 (0 = paling kiri). seg: bit0 = a ... bit6 = g, bit7 = titik
void     tm1638_set_segments(uint32_t digit, uint8_t seg);

// LED 0-7 di atas display
void     tm1638_set_led(uint32_t led, int on);

// Tampilkan angka desimal rata kanan di 8 digit (digit kosong padam)
void     tm1638_show_number(uint32_t value);

// Tampilkan 8 digit heksadesimal
void     tm1638_show_hex(uint32_t value);

// Baca 8 tombol: bit k = tombol S(k+1) ditekan
uint8_t  tm1638_read_buttons(void);

// Pola segmen untuk 0-F
extern const uint8_t tm1638_font[16];

#endif
