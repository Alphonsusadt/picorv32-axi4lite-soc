`default_nettype none

// Top level board Tang Nano 20K (GW2AR-LV18QN88C8/I7).
//
// - Clock board 27 MHz dari pin 4, dibagi 2^CLK_DIV_LOG2 oleh rPLL untuk clock SoC.
// - Reset dibuat otomatis saat power-on.
// - Tombol S1 dan S2 masuk ke iSW[1:0]; iSW[15:2] diikat ke nol.
// - 6 LED on-board menyala bergantian (lampu berjalan) mengikuti oLED[15:13];
//   LED ini aktif rendah.
// - ROM dan RAM memakai ukuran template (16 KB), karena BSRAM GW2AR-18 cukup.
//
// Program demo_led_berkedip menulis nilai yang terus naik ke oLED. Nilai
// oLED[15:13] (0 sampai 7) dipakai sebagai posisi lampu: posisi 0-5 menyalakan
// LED[0]-LED[5], posisi 6-7 semua padam sebagai jeda sebelum mengulang.
// Dengan pembagi 2^7, clock SoC sekitar 211 kHz sehingga posisi berpindah
// sekitar 4 kali per detik. Isi CLK_DIV_LOG2 = 0 untuk menjalankan SoC pada 27 MHz.
//
// TM1638 di header: STB 26, CLK 25, DIO 27 (lihat constraints/tangnano20k.cst).
// DIO dua arah memakai IOBUF. Isi ROM dipilih lewat ROM_INIT (make all PROGRAM=...).
//
// UART lewat chip USB BL616 on-board (RX pin 70, TX pin 69), 9600 baud:
// loader ROM (skenario A) dan bootloader (skenario B). Saat loader menerima
// semua LED menyala; jika unggahan gagal LED menyala selang-seling dan CPU
// ditahan sampai unggahan berikutnya benar.

module top_tangnano20k #(
    parameter CLK_DIV_LOG2 = 7,
    parameter ROM_INIT     = "demo_led_berkedip_xcelium_v2_words.hex",
    parameter BAUD         = 9600
) (
    input  wire       clk,
    input  wire [1:0] BTN,
    output wire [5:0] LED,
    output wire       tm_stb,
    output wire       tm_clk,
    inout  wire       tm_dio,
    input  wire       uart_rx,
    output wire       uart_tx
);

    // Pembagi baud dari clock SoC (27 MHz / 2^CLK_DIV_LOG2)
    localparam UART_DIV = (27000000 / (1 << CLK_DIV_LOG2) + BAUD / 2) / BAUD;

    // Pembagi clock memakai rPLL GW2A: CLKOUT 27 MHz (VCO 864 MHz), lalu
    // pembagi CLKOUTD sebesar 2^CLK_DIV_LOG2. Pembagian dengan flip-flop biasa
    // gagal timing di Gowin karena clock-nya tidak masuk jaringan global.
    // CLK_DIV_LOG2 harus 1 sampai 7 (pembagi 2 sampai 128), atau 0 tanpa pembagi.
    wire soc_clk;
    wire pll_lock;
    generate
        if (CLK_DIV_LOG2 == 0) begin : g_no_div
            assign soc_clk  = clk;
            assign pll_lock = 1'b1;
        end else begin : g_pll
            rPLL #(
                .FCLKIN("27.0"),
                .IDIV_SEL(0),
                .FBDIV_SEL(0),
                .ODIV_SEL(32),
                .CLKOUTD_SRC("CLKOUT"),
                .DYN_SDIV_SEL(1 << CLK_DIV_LOG2)
            ) u_pll (
                .CLKIN(clk), .CLKFB(1'b0), .RESET(1'b0), .RESET_P(1'b0),
                .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0),
                .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0),
                .CLKOUT(), .CLKOUTP(), .CLKOUTD(soc_clk), .CLKOUTD3(),
                .LOCK(pll_lock)
            );
        end
    endgenerate

    // Power-on reset: rst_n tetap 0 sampai PLL terkunci, lalu 16 siklus lagi.
    reg [4:0] por_count = 5'd0;
    wire      rst_n     = por_count[4];

    always @(posedge soc_clk) begin
        if (!rst_n && pll_lock)
            por_count <= por_count + 5'd1;
    end

    wire        trap;
    wire [15:0] oLED;
    wire        spi_sck, spi_sdo, spi_sdo_oe, spi_sdi;
    wire [1:0]  spi_cs_n;
    wire        loader_busy, loader_error;

    picorv32_soc #(
        .ROM_INIT(ROM_INIT),
        .UART_DIV(UART_DIV)
    ) u_soc (
        .clk  (soc_clk),
        .rst_n(rst_n),
        .trap (trap),
        .iSW  ({14'b0, BTN}),
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

    // TM1638: STB = CS0, DIO dua arah
    assign tm_stb = spi_cs_n[0];
    assign tm_clk = spi_sck;
`ifdef SYNTHESIS
    IOBUF u_tm_dio (
        .IO (tm_dio),
        .I  (spi_sdo),
        .OEN(~spi_sdo_oe),          // aktif rendah
        .O  (spi_sdi)
    );
`else
    assign tm_dio  = spi_sdo_oe ? spi_sdo : 1'bz;
    assign spi_sdi = tm_dio;
`endif

    // Lampu berjalan: satu LED menyala sesuai posisi oLED[15:13].
    // LED aktif rendah: 0 = menyala.
    wire [2:0] pos       = oLED[15:13];
    wire [7:0] one_hot   = 8'b1 << pos;
    assign LED = loader_busy  ? 6'b000000 :      // semua menyala
                 loader_error ? 6'b101010 :      // selang-seling
                 ~one_hot[5:0];

endmodule

`default_nettype wire
