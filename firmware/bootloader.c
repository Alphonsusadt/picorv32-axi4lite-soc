// Skenario B: bootloader di ROM.
//
// Setelah reset:
//   1. Kirim "BOOT\r\n" lewat UART, lalu tunggu frame sambil mengedipkan LED.
//   2. Frame (little-endian):
//        4 byte  magic 55 AA 52 41  ("..RA" = RAM)
//        2 byte  N = jumlah word
//        4N byte program, ditulis ke RAM mulai 0x1000_0000
//        1 byte  checksum = jumlah semua byte program, mod 256
//   3. Checksum benar: kirim "OK\r\n" lalu lompat ke 0x1000_0000.
//      Salah: kirim "ER\r\n" dan kembali menunggu.
//
// Magic berbeda dengan loader hardware (55 AA 52 4D), jadi keduanya bisa
// memakai pin RX yang sama. Bootloader hanya memakai register dan stack di
// 1 KB teratas RAM (link_boot.ld), sehingga program boleh memakai 7 KB
// pertama RAM.

#include <stdint.h>
#include "soc.h"
#include "uart.h"

#define APP_BASE       0x10000000u
#define APP_MAX_WORDS  ((8192u - 1024u) / 4u)

static const uint8_t magic[4] = { 0x55, 0xAA, 0x52, 0x41 };

// Tunggu satu byte; LED board berkedip selama menunggu
static uint8_t getc_blink(uint32_t *tick)
{
    while (!uart_rx_ready()) {
        (*tick)++;
        GPIO_LED = (*tick & 0x400u) ? 0xFFFFu : 0x0000u;
    }
    return uart_read();
}

static int receive_frame(void)
{
    uint32_t tick = 0;
    uint32_t matched = 0;

    // Cari magic (geser jika tidak cocok)
    while (matched < 4) {
        uint8_t b = getc_blink(&tick);
        if (b == magic[matched])
            matched++;
        else
            matched = (b == magic[0]) ? 1 : 0;
    }

    uint32_t n = uart_getc();
    n |= (uint32_t)uart_getc() << 8;
    if (n == 0 || n > APP_MAX_WORDS)
        return 0;

    volatile uint32_t *dst = (volatile uint32_t *)APP_BASE;
    uint8_t sum = 0;
    for (uint32_t i = 0; i < n; i++) {
        uint32_t w = 0;
        for (uint32_t k = 0; k < 32; k += 8) {
            uint8_t b = uart_getc();
            sum += b;
            w |= (uint32_t)b << k;
        }
        dst[i] = w;
    }
    return uart_getc() == sum;
}

int main(void)
{
    uart_puts("BOOT\r\n");
    for (;;) {
        if (receive_frame()) {
            uart_puts("OK\r\n");
            GPIO_LED = 0;
            ((void (*)(void))APP_BASE)();
        }
        uart_puts("ER\r\n");
    }
}
