#include "spi.h"

static uint32_t ctrl_value;

void spi_init(uint32_t mode, uint32_t flags, uint32_t div)
{
    ctrl_value = SPI_CTRL_EN | ((mode & 3u) << 1) |
                 (flags & (SPI_CTRL_LSB_FIRST | SPI_CTRL_THREE_WIRE));
    SPI_CS   = 0;
    SPI_DIV  = div;
    SPI_CTRL = ctrl_value;
}

void spi_select(uint32_t cs_mask)
{
    SPI_CS = cs_mask;
}

uint8_t spi_transfer(uint8_t tx)
{
    SPI_DATA = tx;
    while (SPI_STATUS & SPI_STATUS_BUSY)
        ;
    return (uint8_t)SPI_DATA;
}

void spi_set_rx(int rx)
{
    if (rx)
        ctrl_value |= SPI_CTRL_RX_EN;
    else
        ctrl_value &= ~SPI_CTRL_RX_EN;
    SPI_CTRL = ctrl_value;
}

int spi_present(void)
{
    return SPI_ID == SPI_ID_VALUE;
}
