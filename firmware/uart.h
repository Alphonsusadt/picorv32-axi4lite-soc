// Driver UART (periferal di 0x0002_1000). Baud diatur hardware lewat
// parameter UART_DIV di SoC; DIV bisa diubah dengan uart_set_div().
#ifndef UART_H
#define UART_H

#include <stdint.h>
#include "soc.h"

static inline int uart_rx_ready(void)
{
    return (UART_STATUS & UART_STATUS_RX_VALID) != 0;
}

static inline uint8_t uart_read(void)
{
    return (uint8_t)UART_DATA;
}

static inline void uart_putc(char c)
{
    while (UART_STATUS & UART_STATUS_TX_BUSY)
        ;
    UART_DATA = (uint8_t)c;
}

static inline uint8_t uart_getc(void)
{
    while (!uart_rx_ready())
        ;
    return uart_read();
}

static inline void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

static inline void uart_set_div(uint32_t div)
{
    UART_DIV = div;
}

#endif
