// Driver SPI universal. Tidak bergantung pada perangkat tertentu.
#ifndef SPI_H
#define SPI_H

#include <stdint.h>
#include "soc.h"

// mode   : 0-3 (CPOL = bit1, CPHA = bit0)
// flags  : gabungan SPI_CTRL_LSB_FIRST dan/atau SPI_CTRL_THREE_WIRE
// div    : f_SCK = f_clk / (2 * (div + 1))
void    spi_init(uint32_t mode, uint32_t flags, uint32_t div);

// Pilih chip select: bit0 = CS0, bit1 = CS1, 0 = semua tidak aktif
void    spi_select(uint32_t cs_mask);

// Kirim satu byte, kembalikan byte yang diterima pada saat yang sama
uint8_t spi_transfer(uint8_t tx);

// Mode 3-wire: 1 = pin data menjadi input (baca), 0 = output (tulis)
void    spi_set_rx(int rx);

// 1 jika periferal SPI terpasang di alamat SPI_BASE
int     spi_present(void);

#endif
