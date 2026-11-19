#include "tm1638.h"
#include "spi.h"

// Perintah TM1638
#define CMD_WRITE_AUTO  0x40
#define CMD_WRITE_FIXED 0x44
#define CMD_READ_KEYS   0x42
#define CMD_ADDR        0xC0
#define CMD_DISPLAY     0x80
#define DISPLAY_ON      0x08

const uint8_t tm1638_font[16] = {
    0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07,
    0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71,
};

static uint32_t cs_mask;

static void command(uint8_t cmd)
{
    spi_select(cs_mask);
    spi_transfer(cmd);
    spi_select(0);
}

void tm1638_init(uint32_t cs, uint32_t brightness)
{
    // DIV = 0 memberi SCK = f_clk / 2, aman selama clock SoC <= 2 MHz
    tm1638_init_div(cs, brightness, 0);
}

void tm1638_init_div(uint32_t cs, uint32_t brightness, uint32_t div)
{
    // TM1638: CLK idle tinggi, data LSB dulu, satu pin DIO dua arah.
    spi_init(3, SPI_CTRL_LSB_FIRST | SPI_CTRL_THREE_WIRE, div);
    cs_mask = 1u << cs;

    // Bersihkan 16 alamat display
    command(CMD_WRITE_AUTO);
    spi_select(cs_mask);
    spi_transfer(CMD_ADDR | 0);
    for (int i = 0; i < 16; i++)
        spi_transfer(0x00);
    spi_select(0);

    command(CMD_DISPLAY | DISPLAY_ON | (brightness & 7u));
}

void tm1638_write(uint32_t addr, uint8_t value)
{
    command(CMD_WRITE_FIXED);
    spi_select(cs_mask);
    spi_transfer(CMD_ADDR | (addr & 0x0F));
    spi_transfer(value);
    spi_select(0);
}

void tm1638_write_block(uint32_t start, const uint8_t *data, uint32_t n)
{
    command(CMD_WRITE_AUTO);
    spi_select(cs_mask);
    spi_transfer(CMD_ADDR | (start & 0x0F));
    for (uint32_t i = 0; i < n; i++)
        spi_transfer(data[i]);
    spi_select(0);
}

// Pada modul LED&KEY, alamat genap = digit, alamat ganjil = LED
void tm1638_set_segments(uint32_t digit, uint8_t seg)
{
    tm1638_write((digit & 7u) * 2, seg);
}

void tm1638_set_led(uint32_t led, int on)
{
    tm1638_write((led & 7u) * 2 + 1, on ? 1 : 0);
}

static void write_digits(const uint8_t seg[8])
{
    command(CMD_WRITE_FIXED);
    for (uint32_t d = 0; d < 8; d++) {
        spi_select(cs_mask);
        spi_transfer(CMD_ADDR | (d * 2));
        spi_transfer(seg[d]);
        spi_select(0);
    }
}

void tm1638_show_number(uint32_t value)
{
    uint8_t seg[8];
    for (int d = 7; d >= 0; d--) {
        // Digit kiri yang tidak terpakai dibiarkan padam
        seg[d] = (value != 0 || d == 7) ? tm1638_font[value % 10] : 0x00;
        value /= 10;
    }
    write_digits(seg);
}

void tm1638_show_hex(uint32_t value)
{
    uint8_t seg[8];
    for (int d = 7; d >= 0; d--) {
        seg[d] = tm1638_font[value & 0xF];
        value >>= 4;
    }
    write_digits(seg);
}

uint8_t tm1638_read_buttons(void)
{
    uint8_t buttons = 0;

    spi_select(cs_mask);
    spi_transfer(CMD_READ_KEYS);
    // Datasheet: jeda >= 1 us sebelum membaca. Penulisan register CTRL di
    // spi_set_rx sudah memakan beberapa siklus bus, lebih dari cukup.
    spi_set_rx(1);
    for (uint32_t i = 0; i < 4; i++) {
        uint8_t b = spi_transfer(0x00);
        // Byte i: bit0 = tombol S(i+1), bit4 = tombol S(i+5)
        buttons |= (uint8_t)((b & 0x11) << i);
    }
    spi_set_rx(0);
    spi_select(0);
    return buttons;
}
