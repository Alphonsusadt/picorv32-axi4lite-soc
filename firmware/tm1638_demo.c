// Demo TM1638 lewat SPI universal.
//
// - 8 digit menampilkan penghitung desimal yang naik terus.
// - LED ke-k di modul TM1638 menyala selama tombol S(k+1) ditekan.
// - Tombol S1 mengembalikan penghitung ke 0, S8 menampilkan nilai heksadesimal.
// - LED board tetap ditulis lewat GPIO (bit 13 ke atas), jadi LED iCESugar
//   berkedip dan lampu berjalan Tang Nano 20K tetap bergerak.
// - Jika periferal SPI tidak terpasang, hanya LED board yang berjalan.

#include <stdint.h>
#include "soc.h"
#include "spi.h"
#include "tm1638.h"

// Jeda kira-kira, dalam putaran loop (sekitar 6 siklus clock per putaran)
#ifndef DELAY_LOOPS
#define DELAY_LOOPS 2000
#endif

static void delay(uint32_t loops)
{
    for (volatile uint32_t i = 0; i < loops; i++)
        ;
}

int main(void)
{
    uint32_t count = 0;
    uint8_t  last_buttons = 0;
    int      has_tm = spi_present();

    if (has_tm)
        tm1638_init(0, 2);

    for (;;) {
        GPIO_LED = count << 13;

        if (has_tm) {
            uint8_t buttons = tm1638_read_buttons();

            if (buttons & 0x01)
                count = 0;

            if (buttons & 0x80)
                tm1638_show_hex(count);
            else
                tm1638_show_number(count);

            uint8_t changed = buttons ^ last_buttons;
            for (uint32_t k = 0; k < 8; k++)
                if (changed & (1u << k))
                    tm1638_set_led(k, buttons & (1u << k));
            last_buttons = buttons;
        }

        count++;
        delay(DELAY_LOOPS);
    }
}
