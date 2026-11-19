// rom_loader versi ASIC: tanpa loader.
//
// ROM ASIC berupa logika tetap (asic/rtl/axi_rom.v), jadi tidak bisa ditulis
// lewat UART. Modul ini menggantikan rtl/uart/rom_loader.v di daftar sumber
// ASIC dengan port yang sama, sehingga soc_demo.v tidak perlu diubah.
// Semua keluaran konstan; sintesis membuang logika yang tidak terpakai.

module rom_loader #(
    parameter ROM_WORDS    = 4096,
    parameter GAP_BITS     = 20,
    parameter TIMEOUT_BITS = 10000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] clks_per_bit,
    input  wire        rx,

    output wire        hold,
    output wire        error,
    output wire        busy,

    output wire        ld_we,
    output wire [31:0] ld_addr,
    output wire [31:0] ld_data
);

    assign hold    = 1'b0;
    assign error   = 1'b0;
    assign busy    = 1'b0;
    assign ld_we   = 1'b0;
    assign ld_addr = 32'h0;
    assign ld_data = 32'h0;

    wire unused_ok = &{1'b0, clk, rst_n, clks_per_bit, rx};

endmodule
