// Top level ASIC: SoC PicoRV32 + SPI + UART menjalankan tugas UTS (NIM
// berjalan di TM1638) dari ROM tetap. Untuk LibreLane (sky130A).
//
// Perbedaan dengan top FPGA (fpga/top_*.v):
//   - ROM = logika kombinasional berisi firmware/nim_scroll.c
//     (asic/rtl/axi_rom.v, dibuat oleh tools/hex_to_rom_v.py),
//   - RAM 64 word (256 B) flip-flop, cukup untuk stack nim_scroll,
//   - tanpa loader UART (asic/rtl/rom_loader.v adalah stub),
//   - DIO TM1638 dipecah menjadi out / oe / in; buffer tri-state ada di pad
//     (atau di FPGA/board penguji), bukan di dalam blok digital ini,
//   - reset eksternal disinkronkan ke clock (assert asinkron, lepas sinkron),
//   - tanpa pembagi clock: clk langsung menjadi clock SoC (target 25 MHz).
//
// Firmware menghitung 1 detik dari register DIV UART (= f_clk / 9600), jadi
// UART_DIV harus sama dengan frekuensi clock / 9600.

module soc_nim_asic #(
    parameter CLK_HZ   = 25000000,
    parameter BAUD     = 9600,
    parameter UART_DIV = (CLK_HZ + BAUD / 2) / BAUD
) (
    input  wire       clk,
    input  wire       rst_n,        // reset aktif rendah, asinkron

    // TM1638 (SPI 3-wire mode 3, LSB dulu)
    output wire       tm_stb,
    output wire       tm_clk,
    output wire       tm_dio_out,
    output wire       tm_dio_oe,    // 1 = chip mengemudikan DIO
    input  wire       tm_dio_in,

    // UART 9600 8N1 (periferal; tidak dipakai nim_scroll, tersedia untuk debug)
    input  wire       uart_rx,
    output wire       uart_tx,

    // Posisi scroll (GPIO bit 15..13) dan status CPU
    output wire [2:0] led,
    output wire       trap
);

    // ---------------- Sinkronisasi reset ----------------
    reg [1:0] rst_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rst_sync <= 2'b00;
        else        rst_sync <= {rst_sync[0], 1'b1};
    end
    wire soc_rst_n = rst_sync[1];

    // DIO dari luar chip asinkron: 2 flip-flop sebelum masuk SPI. TM1638
    // mengganti data di tepi turun SCK dan SPI membacanya (DIV + 1) siklus
    // kemudian, jadi perlu DIV >= 2. Firmware memilih DIV = f_clk / 1 MHz,
    // sehingga clock minimum 2 MHz; di 25 MHz DIV = 25 (26 siklus).
    reg [1:0] dio_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) dio_sync <= 2'b11;
        else        dio_sync <= {dio_sync[0], tm_dio_in};
    end

    // ---------------- SoC ----------------
    wire [15:0] oLED;
    wire [1:0]  spi_cs_n;

    picorv32_soc #(
        .ROM_ADDR_BITS(9),          // 512 word = 2 KB (firmware/link_asic.ld)
        .RAM_ADDR_BITS(6),          // 64 word = 256 B
        .ROM_INIT(""),
        .UART_DIV(UART_DIV)
    ) u_soc (
        .clk         (clk),
        .rst_n       (soc_rst_n),
        .trap        (trap),
        .iSW         (16'h0000),
        .oLED        (oLED),
        .spi_sck     (tm_clk),
        .spi_cs_n    (spi_cs_n),
        .spi_sdo     (tm_dio_out),
        .spi_sdo_oe  (tm_dio_oe),
        .spi_sdi     (dio_sync[1]),
        .uart_rx     (uart_rx),
        .uart_tx     (uart_tx),
        .loader_busy (),
        .loader_error()
    );

    assign tm_stb = spi_cs_n[0];
    assign led    = oLED[15:13];

endmodule
