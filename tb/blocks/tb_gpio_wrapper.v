`timescale 1ns / 1ps

// Testbench blok GPIO lewat AXI4-Lite:
// axi4_lite_gpio_wrapper, axi4_lite_slave, dan gpio.

module tb_gpio_wrapper;

    `include "tb_utils.vh"

    reg         iCLK, iRST;
    reg  [15:0] iSW;
    wire [15:0] oLED;

    reg         s_AWVALID, s_WVALID, s_BREADY, s_ARVALID, s_RREADY;
    reg  [31:0] s_AWADDR, s_WDATA, s_ARADDR;
    reg  [ 3:0] s_WSTRB;
    wire        s_AWREADY, s_WREADY, s_BVALID, s_ARREADY, s_RVALID;
    wire [ 1:0] s_BRESP, s_RRESP;
    wire [31:0] s_RDATA;

    reg  [31:0] data;
    reg  [ 1:0] resp;

    axi4_lite_gpio_wrapper uut (
        .iCLK(iCLK), .iRST(iRST), .iSW(iSW), .oLED(oLED),
        .s_AWVALID(s_AWVALID), .s_AWPROT(3'b000), .s_AWADDR(s_AWADDR), .s_AWREADY(s_AWREADY),
        .s_WVALID(s_WVALID), .s_WDATA(s_WDATA), .s_WSTRB(s_WSTRB), .s_WREADY(s_WREADY),
        .s_BREADY(s_BREADY), .s_BVALID(s_BVALID), .s_BRESP(s_BRESP),
        .s_ARVALID(s_ARVALID), .s_ARPROT(3'b000), .s_ARADDR(s_ARADDR), .s_ARREADY(s_ARREADY),
        .s_RREADY(s_RREADY), .s_RVALID(s_RVALID), .s_RRESP(s_RRESP), .s_RDATA(s_RDATA)
    );

    initial iCLK = 1'b0;
    always #5 iCLK = ~iCLK;

    // Pola yang sama dengan picorv32_axi_adapter: BREADY dan RREADY aktif
    // sejak permintaan dimulai.
    task axi_write;
        input [31:0] addr;
        input [31:0] value;
        integer t;
        begin
            @(negedge iCLK);
            s_AWVALID = 1'b1; s_AWADDR = addr;
            s_WVALID  = 1'b1; s_WDATA  = value; s_WSTRB = 4'hF;
            s_BREADY  = 1'b1;
            t = 0;
            while (!(s_AWREADY && s_WREADY) && t < 20) begin @(negedge iCLK); t = t + 1; end
            @(negedge iCLK);
            s_AWVALID = 1'b0; s_WVALID = 1'b0;
            t = 0;
            while (!s_BVALID && t < 20) begin @(negedge iCLK); t = t + 1; end
            resp = s_BRESP;
            @(negedge iCLK);
            s_BREADY = 1'b0;
            repeat (2) @(negedge iCLK);
        end
    endtask

    task axi_read;
        input  [31:0] addr;
        output [31:0] value;
        integer t;
        begin
            @(negedge iCLK);
            s_ARVALID = 1'b1; s_ARADDR = addr;
            s_RREADY  = 1'b1;
            t = 0;
            while (!s_ARREADY && t < 20) begin @(negedge iCLK); t = t + 1; end
            @(negedge iCLK);
            s_ARVALID = 1'b0;
            t = 0;
            while (!s_RVALID && t < 20) begin @(negedge iCLK); t = t + 1; end
            value = s_RDATA;
            resp  = s_RRESP;
            @(negedge iCLK);
            s_RREADY = 1'b0;
            repeat (2) @(negedge iCLK);
        end
    endtask

    initial begin
        $dumpfile("tb_gpio_wrapper.vcd");
        $dumpvars(0, tb_gpio_wrapper);

        iRST = 1'b0; iSW = 16'h0;
        s_AWVALID = 1'b0; s_WVALID = 1'b0; s_BREADY = 1'b0; s_ARVALID = 1'b0; s_RREADY = 1'b0;
        s_AWADDR = 32'h0; s_WDATA = 32'h0; s_WSTRB = 4'h0; s_ARADDR = 32'h0;
        repeat (3) @(negedge iCLK);

        section("Reset");
        check("LED = 0",    oLED,     16'h0);
        check("BVALID = 0", s_BVALID, 1'b0);
        check("RVALID = 0", s_RVALID, 1'b0);
        iRST = 1'b1;
        repeat (3) @(negedge iCLK);
        check("LED tetap 0 saat idle", oLED, 16'h0);

        section("Tulis LED lewat AXI");
        axi_write(32'h0, 32'h0000_A5A5);
        check("LED = A5A5", oLED, 16'hA5A5);
        check("BRESP = OKAY", resp, 2'b00);
        axi_write(32'h0, 32'h0000_0F0F);
        check("LED = 0F0F", oLED, 16'h0F0F);
        repeat (10) @(negedge iCLK);
        check("LED bertahan saat idle", oLED, 16'h0F0F);

        section("Baca switch lewat AXI");
        iSW = 16'hBEEF;
        axi_read(32'h0, data);
        check("RDATA = BEEF", data, 32'h0000_BEEF);
        check("RRESP = OKAY", resp, 2'b00);
        iSW = 16'h1234;
        axi_read(32'h0, data);
        check("RDATA = 1234", data, 32'h0000_1234);
        check("Baca tidak mengubah LED", oLED, 16'h0F0F);

        section("AW dan W tidak bersamaan");
        @(negedge iCLK);
        s_AWVALID = 1'b1; s_AWADDR = 32'h0; s_BREADY = 1'b1;
        repeat (3) @(negedge iCLK);
        check("AW sendiri belum diterima", s_AWREADY, 1'b0);
        check("BVALID tetap 0",            s_BVALID,  1'b0);
        s_WVALID = 1'b1; s_WDATA = 32'h0000_7777; s_WSTRB = 4'hF;
        #1;
        check("AWREADY aktif setelah W datang", s_AWREADY, 1'b1);
        check("WREADY aktif setelah W datang",  s_WREADY,  1'b1);
        @(negedge iCLK);
        s_AWVALID = 1'b0; s_WVALID = 1'b0;
        check("BVALID = 1", s_BVALID, 1'b1);
        @(negedge iCLK);
        s_BREADY = 1'b0;
        repeat (2) @(negedge iCLK);
        check("LED = 7777", oLED, 16'h7777);

        section("BVALID bertahan sampai BREADY");
        @(negedge iCLK);
        s_AWVALID = 1'b1; s_WVALID = 1'b1; s_WDATA = 32'h0000_8888;
        @(negedge iCLK);
        s_AWVALID = 1'b0; s_WVALID = 1'b0;
        repeat (3) @(negedge iCLK);
        check("BVALID bertahan", s_BVALID, 1'b1);
        s_BREADY = 1'b1;
        @(negedge iCLK);
        s_BREADY = 1'b0;
        check("BVALID = 0 setelah BREADY", s_BVALID, 1'b0);

        section("Catatan: RREADY baru aktif setelah RVALID");
        repeat (2) @(negedge iCLK);
        iSW = 16'hABCD;
        @(negedge iCLK);
        s_ARVALID = 1'b1; s_ARADDR = 32'h0; s_RREADY = 1'b0;
        @(negedge iCLK);
        s_ARVALID = 1'b0;
        repeat (2) @(negedge iCLK);
        if (s_RDATA !== 32'h0000_ABCD)
            $display("  [NOTE] RDATA=%h belum memuat switch ABCD. Wrapper memuat switch hanya saat RREADY aktif, sehingga master AXI lain bisa membaca data lama. CPU di SoC ini tidak terdampak karena RREADY aktif sejak awal.", s_RDATA);
        else
            $display("  [NOTE] RDATA sudah memuat switch.");
        s_RREADY = 1'b1;
        @(negedge iCLK);
        s_RREADY = 1'b0;

        finish_tb;
    end

endmodule
