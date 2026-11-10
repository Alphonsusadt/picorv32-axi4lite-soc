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

module top_icesugar #(
    parameter CLK_DIV_LOG2 = 4
) (
    input  wire       clk,
    input  wire [3:0] SW,
    output wire       LED_R,
    output wire       LED_G,
    output wire       LED_B
);

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

    picorv32_soc #(
        .ROM_ADDR_BITS(10),
        .RAM_ADDR_BITS(11)
    ) u_soc (
        .clk  (soc_clk),
        .rst_n(rst_n),
        .trap (trap),
        .iSW  ({12'b0, SW}),
        .oLED (oLED)
    );

    // LED aktif rendah: 0 = menyala
    assign LED_R = 1'b1;
    assign LED_G = ~oLED[15];
    assign LED_B = 1'b1;

endmodule

`default_nettype wire
