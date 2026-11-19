// Peta alamat SoC PicoRV32 (lihat rtl/soc_demo.v)
#ifndef SOC_H
#define SOC_H

#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))

// ROM  0x0000_0000 (s0), program dan konstanta
// RAM  0x1000_0000 (s1), data dan stack
#define RAM_BASE        0x10000000u

// GPIO 0x0003_0000 (s2): tulis = LED, baca = switch
#define GPIO_BASE       0x00030000u
#define GPIO_LED        REG32(GPIO_BASE + 0x00)
#define GPIO_SW         REG32(GPIO_BASE + 0x00)

// SPI universal 0x0002_0000 (s3), lihat rtl/spi/axi4_lite_spi.v
#define SPI_BASE        0x00020000u
#define SPI_CTRL        REG32(SPI_BASE + 0x00)
#define SPI_DIV         REG32(SPI_BASE + 0x04)
#define SPI_CS          REG32(SPI_BASE + 0x08)
#define SPI_DATA        REG32(SPI_BASE + 0x0C)
#define SPI_STATUS      REG32(SPI_BASE + 0x10)
#define SPI_ID          REG32(SPI_BASE + 0x14)

#define SPI_CTRL_EN         (1u << 0)
#define SPI_CTRL_CPOL       (1u << 1)
#define SPI_CTRL_CPHA       (1u << 2)
#define SPI_CTRL_LSB_FIRST  (1u << 3)
#define SPI_CTRL_THREE_WIRE (1u << 4)
#define SPI_CTRL_RX_EN      (1u << 5)

#define SPI_STATUS_BUSY     (1u << 0)
#define SPI_STATUS_RX_VALID (1u << 1)

#define SPI_ID_VALUE        0x53504931u   // "SPI1"

// UART 0x0002_1000 (s3, bit alamat 12 = 1), lihat rtl/uart/axi4_lite_uart.v
#define UART_BASE       0x00021000u
#define UART_DATA       REG32(UART_BASE + 0x00)
#define UART_STATUS     REG32(UART_BASE + 0x04)
#define UART_DIV        REG32(UART_BASE + 0x08)
#define UART_ID         REG32(UART_BASE + 0x0C)

#define UART_STATUS_TX_BUSY     (1u << 0)
#define UART_STATUS_RX_VALID    (1u << 1)
#define UART_STATUS_RX_OVERRUN  (1u << 2)
#define UART_STATUS_FRAME_ERROR (1u << 3)

#define UART_ID_VALUE   0x55415231u   // "UAR1"

#endif
