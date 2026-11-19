// Program uji untuk loader: pola LED yang jelas berbeda dari program dosen.
//
// - Tang Nano 20K: lampu berjalan ke arah sebaliknya (posisi oLED[15:13] turun).
// - iCESugar: LED hijau berkedip lebih cepat.
// - Mengirim "LED_PATTERN\r\n" lewat UART saat mulai.
//
// Bisa dibangun untuk ROM (led_pattern, skenario A) maupun RAM
// (led_pattern_ram, skenario B).

#include <stdint.h>
#include "soc.h"
#include "uart.h"

#ifndef DELAY_LOOPS
#define DELAY_LOOPS 1500
#endif

static void delay(uint32_t loops)
{
    for (volatile uint32_t i = 0; i < loops; i++)
        ;
}

int main(void)
{
    uart_puts("LED_PATTERN\r\n");

    uint32_t pos = 5;
    for (;;) {
        GPIO_LED = 0x0A00u | (pos << 13);
        pos = (pos == 0) ? 5 : pos - 1;
        delay(DELAY_LOOPS);
    }
}
