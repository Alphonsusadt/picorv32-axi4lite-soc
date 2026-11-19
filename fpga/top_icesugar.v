`default_nettype none

// Top level board iCESugar v1.5 (iCE40UP5K-SG48).
//
// - Clock board 12 MHz dari pin 35, dibagi CLK_DIV_LOG2 untuk clock SoC.
// - Reset dibuat otomatis saat power-on, karena board tidak punya tombol reset FPGA.
// - 4 DIP switch masuk ke iSW[3:0]; iSW[15:4] diikat ke nol.
// - Hanya LED hijau on-board yang dipakai: menyala dan padam mengikuti oLED[15].
//   LED ini aktif rendah; LED merah dan biru dibiarkan padam.
// - Memori diperkecil agar muat di 30 blok BRAM UP5K:
//   ROM 1024 word (4 KB), RAM 2048 word (8 KB).
//
// Program demo_led_berkedip menambah nilai LED setiap 19 siklus. Pada 12 MHz,
// bit tertinggi oLED berganti sekitar 29 kali per detik, terlalu cepat untuk
// mata. Dengan pembagi 2^4, clock SoC menjadi 750 kHz sehingga
// oLED[15] berkedip sekitar 1,8 Hz.
// Isi CLK_DIV_LOG2 = 0 untuk menjalankan SoC pada 12 MHz.
//
// TM1638 di PMOD 2 (posisi pin sama dengan PMOD 1 saat UTS, pindahkan
// kabelnya ke PMOD 2): STB 45, CLK 43, DIO 38. Pin 4 di PMOD 1 dipakai UART
// RX iCELink. DIO dua arah memakai SB_IO dengan output enable dari SPI.
// Isi ROM dipilih lewat ROM_INIT (make all PROGRAM=...).
//
// UART iCELink (RX pin 4, TX pin 6), 9600 baud: loader ROM (skenario A) dan
// bootloader (skenario B). LED biru = loader sedang menerima, LED merah =
// unggahan gagal (CPU ditahan sampai unggahan berikutnya benar).

module top_icesugar #(
    parameter CLK_DIV_LOG2 = 4,
    parameter ROM_INIT     = "demo_led_berkedip_xcelium_v2_words.hex",
    parameter BAUD         = 9600
) (
    input  wire       clk,
    input  wire [3:0] SW,
    output wire       LED_R,
    output wire       LED_G,
    output wire       LED_B,
    output wire       tm_stb,
    output wire       tm_clk,
    inout  wire       tm_dio,
    input  wire       uart_rx,
    output wire       uart_tx
);

    // Pembagi baud dari clock SoC (12 MHz / 2^CLK_DIV_LOG2)
    localparam UART_DIV = (12000000 / (1 << CLK_DIV_LOG2) + BAUD / 2) / BAUD;

    // Pembagi clock
    wire soc_clk;
    generate
        if (CLK_DIV_LOG2 == 0) begin : g_no_div
            assign soc_clk = clk;
        end else begin : g_div
            reg [CLK_DIV_LOG2-1:0] div = 0;
            always @(posedge clk) div <= div + 1'b1;
            assign soc_clk = div[CLK_DIV_LOG2-1];
        end
    endgenerate

    // Power-on reset: rst_n tetap 0 selama 16 siklus clock SoC pertama.
    reg [4:0] por_count = 5'd0;
    wire      rst_n     = por_count[4];

    always @(posedge soc_clk) begin
        if (!rst_n)
            por_count <= por_count + 5'd1;
    end

    wire        trap;
    wire [15:0] oLED;
    wire        spi_sck, spi_sdo, spi_sdo_oe, spi_sdi;
    wire [1:0]  spi_cs_n;
    wire        loader_busy, loader_error;

    picorv32_soc #(
        .ROM_ADDR_BITS(10),
        .RAM_ADDR_BITS(11),
        .ROM_INIT(ROM_INIT),
        .UART_DIV(UART_DIV)
    ) u_soc (
        .clk  (soc_clk),
        .rst_n(rst_n),
        .trap (trap),
        .iSW  ({12'b0, SW}),
        .oLED (oLED),
        .spi_sck   (spi_sck),
        .spi_cs_n  (spi_cs_n),
        .spi_sdo   (spi_sdo),
        .spi_sdo_oe(spi_sdo_oe),
        .spi_sdi   (spi_sdi),
        .uart_rx     (uart_rx),
        .uart_tx     (uart_tx),
        .loader_busy (loader_busy),
        .loader_error(loader_error)
    );

    // TM1638: STB = CS0, DIO dua arah (pull-up internal saat dilepas)
    assign tm_stb = spi_cs_n[0];
    assign tm_clk = spi_sck;
`ifdef SYNTHESIS
    SB_IO #(
        .PIN_TYPE(6'b1010_01),      // output tri-state, input langsung
        .PULLUP(1'b1)
    ) u_tm_dio (
        .PACKAGE_PIN  (tm_dio),
        .OUTPUT_ENABLE(spi_sdo_oe),
        .D_OUT_0      (spi_sdo),
        .D_IN_0       (spi_sdi)
    );
`else
    assign tm_dio  = spi_sdo_oe ? spi_sdo : 1'bz;
    assign spi_sdi = tm_dio;
`endif

    // LED aktif rendah: 0 = menyala
    assign LED_R = ~loader_error;
    assign LED_G = ~oLED[15];
    assign LED_B = ~loader_busy;

endmodule

`default_nettype wire
