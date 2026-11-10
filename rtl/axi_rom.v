module axi_rom #(
    // Jumlah bit alamat word: 12 = 4096 word (16 KB), 10 = 1024 word (4 KB)
    parameter ADDR_BITS = 12
) (
    input         clk,
    input         rst_n,

    // AXI4-Lite Interface (Read-Only) -- Port A (CPU fetch/read)
    input         axi_arvalid,
    output        axi_arready,
    input  [31:0] axi_araddr,
    output        axi_rvalid,
    input         axi_rready,
    output [31:0] axi_rdata,

    // Loader Interface -- Port B (SPI boot-loader writes new firmware here).
    // ld_addr is a WORD index. Used only while the CPU is held in reset.
    input         ld_we,
    input  [31:0] ld_addr,
    input  [31:0] ld_data
);

    // ===============================
    // ROM memory
    // ===============================
    // v2.0.1: diperbesar 2001 -> 4096 word (16 KB).
    // PENTING: kedalaman array ini adalah ukuran ROM SEBENARNYA. Kalau
    // program.bin lebih besar, update_axi_rom.py tetap menulis mem[i] di
    // luar batas -> word itu HILANG DIAM-DIAM -> CPU mengeksekusi sampah.
    // sections.lds sudah disamakan (LENGTH = 16K) supaya linker yang
    // menolak duluan dengan error, bukan gagal misterius di board.
    reg [31:0] mem [0:(1<<ADDR_BITS)-1];

    // ===============================
    // ROM initialization
    // Initialize memory from the .hex file
    // ===============================
    // demo_led_berkedip_xcelium_v2.hex berisi 1 byte per baris, sedangkan
    // mem selebar 32 bit. Karena itu dipakai versi 1 word per baris yang
    // dibuat dari file tersebut oleh tcl/hex_bytes_to_words.tcl.
initial begin
    $readmemh("demo_led_berkedip_xcelium_v2_words.hex", mem);
end

    // ===============================
    // Port B: loader write (active only while CPU is in reset / prog mode)
    // ===============================
    always @(posedge clk) begin
        if (ld_we) mem[ld_addr] <= ld_data;
    end

    // ===============================
    // AXI Read logic
    // ===============================

    reg [31:0] rdata_r;              // registered read data -> infer BRAM
    reg        read_en;

    always @(posedge clk) begin
        if (!rst_n) begin
            read_en <= 1'b0;
        end
        else if (axi_arvalid && axi_arready) begin
            rdata_r <= mem[axi_araddr[ADDR_BITS+1:2]]; // baca SINKRON (word aligned) -> BRAM
            read_en <= 1'b1;
        end
        else if (axi_rvalid && axi_rready) begin
            read_en <= 1'b0;
        end
    end

    assign axi_arready = ~read_en;
    assign axi_rvalid  = read_en;
    assign axi_rdata   = rdata_r;

endmodule
