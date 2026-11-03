`timescale 1ns / 1ps

// Testbench blok RAM (axi_ram).

module tb_axi_ram;

    `include "tb_utils.vh"

    reg         clk, rst_n;
    reg         axi_awvalid, axi_wvalid, axi_bready, axi_arvalid, axi_rready;
    reg  [31:0] axi_awaddr, axi_wdata, axi_araddr;
    reg  [ 3:0] axi_wstrb;
    wire        axi_awready, axi_wready, axi_bvalid, axi_arready, axi_rvalid;
    wire [31:0] axi_rdata;

    reg  [31:0] data;

    axi_ram uut (
        .clk(clk), .rst_n(rst_n),
        .axi_awvalid(axi_awvalid), .axi_awready(axi_awready), .axi_awaddr(axi_awaddr),
        .axi_wvalid(axi_wvalid), .axi_wready(axi_wready), .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb),
        .axi_bvalid(axi_bvalid), .axi_bready(axi_bready),
        .axi_arvalid(axi_arvalid), .axi_arready(axi_arready), .axi_araddr(axi_araddr),
        .axi_rvalid(axi_rvalid), .axi_rready(axi_rready), .axi_rdata(axi_rdata)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task write_word;
        input [31:0] addr;
        input [31:0] value;
        input [ 3:0] strb;
        begin
            @(negedge clk);
            axi_awvalid = 1'b1; axi_awaddr = addr;
            axi_wvalid  = 1'b1; axi_wdata  = value; axi_wstrb = strb;
            @(negedge clk);
            axi_awvalid = 1'b0; axi_wvalid = 1'b0;
            axi_bready  = 1'b1;
            @(negedge clk);
            axi_bready  = 1'b0;
        end
    endtask

    task read_word;
        input  [31:0] addr;
        output [31:0] value;
        begin
            @(negedge clk);
            axi_arvalid = 1'b1; axi_araddr = addr;
            @(negedge clk);
            axi_arvalid = 1'b0;
            value = axi_rdata;
            axi_rready = 1'b1;
            @(negedge clk);
            axi_rready = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("tb_axi_ram.vcd");
        $dumpvars(0, tb_axi_ram);

        rst_n = 1'b0;
        axi_awvalid = 1'b0; axi_wvalid = 1'b0; axi_bready = 1'b0;
        axi_arvalid = 1'b0; axi_rready = 1'b0;
        axi_awaddr = 32'h0; axi_wdata = 32'h0; axi_wstrb = 4'h0; axi_araddr = 32'h0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        section("Reset");
        @(negedge clk);
        check("AWREADY = 1", axi_awready, 1'b1);
        check("WREADY = 1",  axi_wready,  1'b1);
        check("ARREADY = 1", axi_arready, 1'b1);
        check("BVALID = 0",  axi_bvalid,  1'b0);
        check("RVALID = 0",  axi_rvalid,  1'b0);

        section("Tulis dan baca word");
        write_word(32'h0000_0000, 32'h1122_3344, 4'b1111);
        read_word (32'h0000_0000, data); check("Word di alamat 0x0",     data, 32'h1122_3344);
        write_word(32'h0000_0008, 32'hAABB_CCDD, 4'b1111);
        read_word (32'h0000_0008, data); check("Word di alamat 0x8",     data, 32'hAABB_CCDD);
        read_word (32'h0000_0000, data); check("Alamat 0x0 tidak berubah", data, 32'h1122_3344);
        write_word(32'h0000_3FFC, 32'h5566_7788, 4'b1111);
        read_word (32'h0000_3FFC, data); check("Word terakhir, 0x3FFC",  data, 32'h5566_7788);

        section("Byte strobe");
        write_word(32'h0000_0010, 32'h0000_0000, 4'b1111);
        write_word(32'h0000_0010, 32'hFFFF_FFAA, 4'b0001);
        read_word (32'h0000_0010, data); check("WSTRB 0001", data, 32'h0000_00AA);
        write_word(32'h0000_0010, 32'hFFFF_BBFF, 4'b0010);
        read_word (32'h0000_0010, data); check("WSTRB 0010", data, 32'h0000_BBAA);
        write_word(32'h0000_0010, 32'hFFCC_FFFF, 4'b0100);
        read_word (32'h0000_0010, data); check("WSTRB 0100", data, 32'h00CC_BBAA);
        write_word(32'h0000_0010, 32'hDDFF_FFFF, 4'b1000);
        read_word (32'h0000_0010, data); check("WSTRB 1000", data, 32'hDDCC_BBAA);
        write_word(32'h0000_0010, 32'h1234_5678, 4'b0000);
        read_word (32'h0000_0010, data); check("WSTRB 0000 tidak menulis", data, 32'hDDCC_BBAA);

        section("Handshake tulis");
        @(negedge clk);
        axi_awvalid = 1'b1; axi_wvalid = 1'b1; axi_awaddr = 32'h20; axi_wdata = 32'h1; axi_wstrb = 4'hF;
        @(negedge clk);
        axi_awvalid = 1'b0; axi_wvalid = 1'b0;
        check("BVALID = 1 setelah tulis",     axi_bvalid,  1'b1);
        check("AWREADY = 0 saat respons",     axi_awready, 1'b0);
        repeat (3) @(negedge clk);
        check("BVALID bertahan tanpa BREADY", axi_bvalid,  1'b1);
        axi_bready = 1'b1;
        @(negedge clk);
        axi_bready = 1'b0;
        check("BVALID = 0 setelah BREADY",    axi_bvalid,  1'b0);

        section("Handshake baca");
        @(negedge clk);
        axi_arvalid = 1'b1; axi_araddr = 32'h20;
        @(negedge clk);
        axi_arvalid = 1'b0;
        check("RVALID = 1 setelah baca",      axi_rvalid,  1'b1);
        repeat (3) @(negedge clk);
        check("RVALID bertahan tanpa RREADY", axi_rvalid,  1'b1);
        check("RDATA stabil tanpa RREADY",    axi_rdata,   32'h1);
        axi_rready = 1'b1;
        @(negedge clk);
        axi_rready = 1'b0;
        check("RVALID = 0 setelah RREADY",    axi_rvalid,  1'b0);

        section("Prioritas tulis saat bersamaan dengan baca");
        @(negedge clk);
        axi_awvalid = 1'b1; axi_wvalid = 1'b1; axi_arvalid = 1'b1;
        axi_awaddr = 32'h24; axi_wdata = 32'h2; axi_wstrb = 4'hF; axi_araddr = 32'h20;
        @(negedge clk);
        axi_awvalid = 1'b0; axi_wvalid = 1'b0; axi_arvalid = 1'b0;
        check("Tulis didahulukan", axi_bvalid, 1'b1);
        check("Baca tidak jalan",  axi_rvalid, 1'b0);
        axi_bready = 1'b1;
        @(negedge clk);
        axi_bready = 1'b0;

        section("Batasan: AW tanpa W tidak diproses");
        @(negedge clk);
        axi_awvalid = 1'b1; axi_awaddr = 32'h28;
        @(negedge clk);
        check("BVALID tetap 0", axi_bvalid, 1'b0);
        axi_awvalid = 1'b0;

        section("Isi RAM bertahan setelah reset");
        @(negedge clk);
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        read_word(32'h0000_0000, data);
        check("Alamat 0x0 masih sama", data, 32'h1122_3344);

        finish_tb;
    end

endmodule
