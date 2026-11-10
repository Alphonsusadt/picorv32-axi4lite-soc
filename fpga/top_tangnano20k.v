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

module top_tangnano20k #(
    parameter CLK_DIV_LOG2 = 7
) (
    input  wire       clk,
    input  wire [1:0] BTN,
    output wire [5:0] LED
);

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

    picorv32_soc u_soc (
        .clk  (soc_clk),
        .rst_n(rst_n),
        .trap (trap),
        .iSW  ({14'b0, BTN}),
        .oLED (oLED)
    );

    // Lampu berjalan: satu LED menyala sesuai posisi oLED[15:13].
    // LED aktif rendah: 0 = menyala.
    wire [2:0] pos       = oLED[15:13];
    wire [7:0] one_hot   = 8'b1 << pos;
    assign LED = ~one_hot[5:0];

endmodule

`default_nettype wire
