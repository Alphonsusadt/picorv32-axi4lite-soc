`timescale 1ns / 1ps

// Testbench blok ROM (axi_rom).

module tb_axi_rom;

    `include "tb_utils.vh"

    reg         clk, rst_n;
    reg         axi_arvalid, axi_rready;
    reg  [31:0] axi_araddr;
    wire        axi_arready, axi_rvalid;
    wire [31:0] axi_rdata;
    reg         ld_we;
    reg  [31:0] ld_addr, ld_data;

    reg  [31:0] data;

    axi_rom uut (
        .clk(clk), .rst_n(rst_n),
        .axi_arvalid(axi_arvalid), .axi_arready(axi_arready), .axi_araddr(axi_araddr),
        .axi_rvalid(axi_rvalid), .axi_rready(axi_rready), .axi_rdata(axi_rdata),
        .ld_we(ld_we), .ld_addr(ld_addr), .ld_data(ld_data)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task read_word;
        input  [31:0] addr;
        output [31:0] value;
        begin
            @(negedge clk);
            axi_arvalid = 1'b1;
            axi_araddr  = addr;
            @(negedge clk);
            axi_arvalid = 1'b0;
            value = axi_rdata;
            axi_rready = 1'b1;
            @(negedge clk);
            axi_rready = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("tb_axi_rom.vcd");
        $dumpvars(0, tb_axi_rom);

        rst_n = 1'b0; axi_arvalid = 1'b0; axi_rready = 1'b0; axi_araddr = 32'h0;
        ld_we = 1'b0; ld_addr = 32'h0; ld_data = 32'h0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        section("Reset");
        @(negedge clk);
        check("ARREADY = 1", axi_arready, 1'b1);
        check("RVALID = 0",  axi_rvalid,  1'b0);

        section("Baca firmware");
        read_word(32'h0000_0000, data); check("Alamat 0x0 = mem[0]", data, 32'h0000_0093);
        read_word(32'h0000_0004, data); check("Alamat 0x4 = mem[1]", data, 32'h0000_0113);
        read_word(32'h0000_0008, data); check("Alamat 0x8 = mem[2]", data, 32'h0000_0193);
        read_word(32'h0000_0FC0, data); check("Alamat 0xFC0 = mem[1008]", data, uut.mem[1008]);

        section("Handshake baca");
        @(negedge clk);
        axi_arvalid = 1'b1; axi_araddr = 32'h0000_0004;
        @(negedge clk);
        axi_arvalid = 1'b0;
        check("RVALID = 1 setelah AR",          axi_rvalid,  1'b1);
        check("ARREADY = 0 saat data menunggu", axi_arready, 1'b0);
        repeat (3) @(negedge clk);
        check("RVALID bertahan tanpa RREADY",   axi_rvalid,  1'b1);
        check("RDATA stabil tanpa RREADY",      axi_rdata,   32'h0000_0113);
        axi_rready = 1'b1;
        @(negedge clk);
        axi_rready = 1'b0;
        check("RVALID = 0 setelah RREADY",      axi_rvalid,  1'b0);
        check("ARREADY = 1 setelah selesai",    axi_arready, 1'b1);

        section("Port loader");
        @(negedge clk);
        ld_we = 1'b1; ld_addr = 32'd100; ld_data = 32'hDEAD_BEEF;
        @(negedge clk);
        ld_we = 1'b0;
        read_word(32'h0000_0190, data);
        check("Indeks word 100 = alamat byte 0x190", data, 32'hDEAD_BEEF);

        section("Pengulangan alamat");
        read_word(32'h0000_4000, data);
        check("Alamat 0x4000 mengulang mem[0]", data, 32'h0000_0093);

        section("Reset membatalkan data tertunda");
        @(negedge clk);
        axi_arvalid = 1'b1; axi_araddr = 32'h0;
        @(negedge clk);
        axi_arvalid = 1'b0;
        rst_n = 1'b0;
        @(negedge clk);
        check("RVALID = 0 setelah reset", axi_rvalid, 1'b0);

        finish_tb;
    end

endmodule
