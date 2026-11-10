`timescale 1ns / 1ps

// Testbench blok interconnect (axi4_lite_interconnect_m1s4).
// Peta alamat mengikuti konfigurasi di soc_demo.v.

// Model slave sederhana yang mencatat transaksi terakhir.
module axi_slave_model #(
    parameter [31:0] READ_TAG = 32'hA000_0000,
    parameter [ 1:0] RESP     = 2'b00
) (
    input             clk, rst_n,
    input             awvalid, input [31:0] awaddr, output awready,
    input             wvalid,  input [31:0] wdata,  input [3:0] wstrb, output wready,
    output reg        bvalid,  output [1:0] bresp,  input bready,
    input             arvalid, input [31:0] araddr, output arready,
    output reg        rvalid,  output [1:0] rresp,  output reg [31:0] rdata, input rready
);
    integer writes = 0, reads = 0;
    reg [31:0] last_awaddr, last_wdata, last_araddr;
    reg [ 3:0] last_wstrb;

    assign awready = awvalid && wvalid && !bvalid;
    assign wready  = awready;
    assign arready = arvalid && !rvalid;
    assign bresp   = RESP;
    assign rresp   = RESP;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bvalid <= 1'b0;
            rvalid <= 1'b0;
        end else begin
            if (awready) begin
                writes      <= writes + 1;
                last_awaddr <= awaddr;
                last_wdata  <= wdata;
                last_wstrb  <= wstrb;
                bvalid      <= 1'b1;
            end else if (bready) bvalid <= 1'b0;

            if (arready) begin
                reads       <= reads + 1;
                last_araddr <= araddr;
                rdata       <= READ_TAG | araddr;
                rvalid      <= 1'b1;
            end else if (rready) rvalid <= 1'b0;
        end
    end
endmodule

module tb_interconnect;

    `include "tb_utils.vh"

    localparam [31:0] ROM_LOW  = 32'h0000_0000, ROM_HIGH  = 32'h0000_FFFF;
    localparam [31:0] RAM_LOW  = 32'h1000_0000, RAM_HIGH  = 32'h1000_FFFF;
    localparam [31:0] GPIO_LOW = 32'h0003_0000, GPIO_HIGH = 32'h0003_FFFF;
    localparam [31:0] TM_LOW   = 32'h0002_0000, TM_HIGH   = 32'h0002_FFFF;

    reg         clk, rst_n;
    reg         m_awvalid, m_wvalid, m_bready, m_arvalid, m_rready;
    reg  [31:0] m_awaddr, m_wdata, m_araddr;
    reg  [ 3:0] m_wstrb;
    wire        m_awready, m_wready, m_bvalid, m_arready, m_rvalid;
    wire [ 1:0] m_bresp, m_rresp;
    wire [31:0] m_rdata;

    wire [3:0] s_awvalid, s_awready, s_wvalid, s_wready, s_bvalid, s_bready;
    wire [3:0] s_arvalid, s_arready, s_rvalid, s_rready;
    wire [31:0] s0_awaddr, s1_awaddr, s2_awaddr, s3_awaddr;
    wire [31:0] s0_wdata, s1_wdata, s2_wdata, s3_wdata;
    wire [ 3:0] s0_wstrb, s1_wstrb, s2_wstrb, s3_wstrb;
    wire [31:0] s0_araddr, s1_araddr, s2_araddr, s3_araddr;
    wire [31:0] s0_rdata, s1_rdata, s2_rdata, s3_rdata;
    wire [ 1:0] s0_bresp, s1_bresp, s2_bresp, s3_bresp;
    wire [ 1:0] s0_rresp, s1_rresp, s2_rresp, s3_rresp;

    axi4_lite_interconnect_m1s4 #(
        .LOW_ADDR0(ROM_LOW),  .HIGH_ADDR0(ROM_HIGH),
        .LOW_ADDR1(RAM_LOW),  .HIGH_ADDR1(RAM_HIGH),
        .LOW_ADDR2(GPIO_LOW), .HIGH_ADDR2(GPIO_HIGH),
        .LOW_ADDR3(TM_LOW),   .HIGH_ADDR3(TM_HIGH)
    ) uut (
        .iCLK(clk), .iRST(rst_n),
        .m0_AWVALID(m_awvalid), .m0_AWADDR(m_awaddr), .m0_AWREADY(m_awready),
        .m0_WVALID(m_wvalid), .m0_WSTRB(m_wstrb), .m0_WDATA(m_wdata), .m0_WREADY(m_wready),
        .m0_BREADY(m_bready), .m0_BVALID(m_bvalid), .m0_BRESP(m_bresp),
        .m0_ARVALID(m_arvalid), .m0_ARADDR(m_araddr), .m0_ARREADY(m_arready),
        .m0_RREADY(m_rready), .m0_RVALID(m_rvalid), .m0_RRESP(m_rresp), .m0_RDATA(m_rdata),

        .s0_AWREADY(s_awready[0]), .s0_AWVALID(s_awvalid[0]), .s0_AWADDR(s0_awaddr),
        .s0_WREADY(s_wready[0]), .s0_WVALID(s_wvalid[0]), .s0_WSTRB(s0_wstrb), .s0_WDATA(s0_wdata),
        .s0_BVALID(s_bvalid[0]), .s0_BRESP(s0_bresp), .s0_BREADY(s_bready[0]),
        .s0_ARREADY(s_arready[0]), .s0_ARVALID(s_arvalid[0]), .s0_ARADDR(s0_araddr),
        .s0_RVALID(s_rvalid[0]), .s0_RRESP(s0_rresp), .s0_RDATA(s0_rdata), .s0_RREADY(s_rready[0]),

        .s1_AWREADY(s_awready[1]), .s1_AWVALID(s_awvalid[1]), .s1_AWADDR(s1_awaddr),
        .s1_WREADY(s_wready[1]), .s1_WVALID(s_wvalid[1]), .s1_WSTRB(s1_wstrb), .s1_WDATA(s1_wdata),
        .s1_BVALID(s_bvalid[1]), .s1_BRESP(s1_bresp), .s1_BREADY(s_bready[1]),
        .s1_ARREADY(s_arready[1]), .s1_ARVALID(s_arvalid[1]), .s1_ARADDR(s1_araddr),
        .s1_RVALID(s_rvalid[1]), .s1_RRESP(s1_rresp), .s1_RDATA(s1_rdata), .s1_RREADY(s_rready[1]),

        .s2_AWREADY(s_awready[2]), .s2_AWVALID(s_awvalid[2]), .s2_AWADDR(s2_awaddr),
        .s2_WREADY(s_wready[2]), .s2_WVALID(s_wvalid[2]), .s2_WSTRB(s2_wstrb), .s2_WDATA(s2_wdata),
        .s2_BVALID(s_bvalid[2]), .s2_BRESP(s2_bresp), .s2_BREADY(s_bready[2]),
        .s2_ARREADY(s_arready[2]), .s2_ARVALID(s_arvalid[2]), .s2_ARADDR(s2_araddr),
        .s2_RVALID(s_rvalid[2]), .s2_RRESP(s2_rresp), .s2_RDATA(s2_rdata), .s2_RREADY(s_rready[2]),

        .s3_AWREADY(s_awready[3]), .s3_AWVALID(s_awvalid[3]), .s3_AWADDR(s3_awaddr),
        .s3_WREADY(s_wready[3]), .s3_WVALID(s_wvalid[3]), .s3_WSTRB(s3_wstrb), .s3_WDATA(s3_wdata),
        .s3_BVALID(s_bvalid[3]), .s3_BRESP(s3_bresp), .s3_BREADY(s_bready[3]),
        .s3_ARREADY(s_arready[3]), .s3_ARVALID(s_arvalid[3]), .s3_ARADDR(s3_araddr),
        .s3_RVALID(s_rvalid[3]), .s3_RRESP(s3_rresp), .s3_RDATA(s3_rdata), .s3_RREADY(s_rready[3])
    );

    axi_slave_model #(.READ_TAG(32'hA000_0000)) m0 (
        .clk(clk), .rst_n(rst_n),
        .awvalid(s_awvalid[0]), .awaddr(s0_awaddr), .awready(s_awready[0]),
        .wvalid(s_wvalid[0]), .wdata(s0_wdata), .wstrb(s0_wstrb), .wready(s_wready[0]),
        .bvalid(s_bvalid[0]), .bresp(s0_bresp), .bready(s_bready[0]),
        .arvalid(s_arvalid[0]), .araddr(s0_araddr), .arready(s_arready[0]),
        .rvalid(s_rvalid[0]), .rresp(s0_rresp), .rdata(s0_rdata), .rready(s_rready[0]));
    axi_slave_model #(.READ_TAG(32'hB000_0000)) m1 (
        .clk(clk), .rst_n(rst_n),
        .awvalid(s_awvalid[1]), .awaddr(s1_awaddr), .awready(s_awready[1]),
        .wvalid(s_wvalid[1]), .wdata(s1_wdata), .wstrb(s1_wstrb), .wready(s_wready[1]),
        .bvalid(s_bvalid[1]), .bresp(s1_bresp), .bready(s_bready[1]),
        .arvalid(s_arvalid[1]), .araddr(s1_araddr), .arready(s_arready[1]),
        .rvalid(s_rvalid[1]), .rresp(s1_rresp), .rdata(s1_rdata), .rready(s_rready[1]));
    axi_slave_model #(.READ_TAG(32'hC000_0000)) m2 (
        .clk(clk), .rst_n(rst_n),
        .awvalid(s_awvalid[2]), .awaddr(s2_awaddr), .awready(s_awready[2]),
        .wvalid(s_wvalid[2]), .wdata(s2_wdata), .wstrb(s2_wstrb), .wready(s_wready[2]),
        .bvalid(s_bvalid[2]), .bresp(s2_bresp), .bready(s_bready[2]),
        .arvalid(s_arvalid[2]), .araddr(s2_araddr), .arready(s_arready[2]),
        .rvalid(s_rvalid[2]), .rresp(s2_rresp), .rdata(s2_rdata), .rready(s_rready[2]));
    axi_slave_model #(.READ_TAG(32'hD000_0000), .RESP(2'b10)) m3 (
        .clk(clk), .rst_n(rst_n),
        .awvalid(s_awvalid[3]), .awaddr(s3_awaddr), .awready(s_awready[3]),
        .wvalid(s_wvalid[3]), .wdata(s3_wdata), .wstrb(s3_wstrb), .wready(s_wready[3]),
        .bvalid(s_bvalid[3]), .bresp(s3_bresp), .bready(s_bready[3]),
        .arvalid(s_arvalid[3]), .araddr(s3_araddr), .arready(s_arready[3]),
        .rvalid(s_rvalid[3]), .rresp(s3_rresp), .rdata(s3_rdata), .rready(s_rready[3]));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    reg  [31:0] data;
    reg  [ 1:0] resp;
    reg         timed_out;

    task axi_write;
        input [31:0] addr;
        input [31:0] value;
        input [ 3:0] strb;
        integer t;
        begin
            timed_out = 1'b0;
            @(negedge clk);
            m_awvalid = 1'b1; m_awaddr = addr;
            m_wvalid  = 1'b1; m_wdata  = value; m_wstrb = strb;
            m_bready  = 1'b1;
            t = 0;
            while (!(m_awready && m_wready) && t < 30) begin @(negedge clk); t = t + 1; end
            if (t >= 30) timed_out = 1'b1;
            @(negedge clk);
            m_awvalid = 1'b0; m_wvalid = 1'b0;
            t = 0;
            while (!m_bvalid && t < 30) begin @(negedge clk); t = t + 1; end
            if (t >= 30) timed_out = 1'b1;
            resp = m_bresp;
            @(negedge clk);
            m_bready = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task axi_read;
        input  [31:0] addr;
        output [31:0] value;
        integer t;
        begin
            timed_out = 1'b0;
            @(negedge clk);
            m_arvalid = 1'b1; m_araddr = addr;
            m_rready  = 1'b1;
            t = 0;
            while (!m_arready && t < 30) begin @(negedge clk); t = t + 1; end
            if (t >= 30) timed_out = 1'b1;
            @(negedge clk);
            m_arvalid = 1'b0;
            t = 0;
            while (!m_rvalid && t < 30) begin @(negedge clk); t = t + 1; end
            if (t >= 30) timed_out = 1'b1;
            value = m_rdata;
            resp  = m_rresp;
            @(negedge clk);
            m_rready = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    task do_reset;
        begin
            @(negedge clk);
            m_awvalid = 1'b0; m_wvalid = 1'b0; m_bready = 1'b0;
            m_arvalid = 1'b0; m_rready = 1'b0;
            rst_n = 1'b0;
            repeat (3) @(negedge clk);
            rst_n = 1'b1;
            repeat (2) @(negedge clk);
        end
    endtask

    integer w0, w1, w2, w3, r0, r1, r2, r3;

    task snapshot;
        begin
            w0 = m0.writes; w1 = m1.writes; w2 = m2.writes; w3 = m3.writes;
            r0 = m0.reads;  r1 = m1.reads;  r2 = m2.reads;  r3 = m3.reads;
        end
    endtask

    // Memastikan hanya satu slave yang menerima transaksi
    task check_only;
        input integer dw0, dw1, dw2, dw3, dr0, dr1, dr2, dr3;
        begin
            check("  jumlah tulis s0", m0.writes - w0, dw0);
            check("  jumlah tulis s1", m1.writes - w1, dw1);
            check("  jumlah tulis s2", m2.writes - w2, dw2);
            check("  jumlah tulis s3", m3.writes - w3, dw3);
            check("  jumlah baca s0",  m0.reads  - r0, dr0);
            check("  jumlah baca s1",  m1.reads  - r1, dr1);
            check("  jumlah baca s2",  m2.reads  - r2, dr2);
            check("  jumlah baca s3",  m3.reads  - r3, dr3);
        end
    endtask

    initial begin
        $dumpfile("tb_interconnect.vcd");
        $dumpvars(0, tb_interconnect);

        rst_n = 1'b0;
        m_awvalid = 1'b0; m_wvalid = 1'b0; m_bready = 1'b0; m_arvalid = 1'b0; m_rready = 1'b0;
        m_awaddr = 32'h0; m_wdata = 32'h0; m_wstrb = 4'h0; m_araddr = 32'h0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        section("Reset dan idle");
        check("m0_AWREADY = 0", m_awready, 1'b0);
        check("m0_ARREADY = 0", m_arready, 1'b0);
        check("Tidak ada AWVALID ke slave", s_awvalid, 4'b0000);
        check("Tidak ada ARVALID ke slave", s_arvalid, 4'b0000);

        section("Baca s0 (ROM)");
        snapshot; axi_read(32'h0000_0010, data);
        check("Data dari s0, alamat lokal 0x10", data, 32'hA000_0010);
        check_only(0,0,0,0, 1,0,0,0);

        section("Baca s1 (RAM)");
        snapshot; axi_read(32'h1000_0020, data);
        check("Data dari s1, alamat lokal 0x20", data, 32'hB000_0020);
        check_only(0,0,0,0, 0,1,0,0);

        section("Baca s2 (GPIO)");
        snapshot; axi_read(32'h0003_3004, data);
        check("Data dari s2, alamat lokal 0x3004", data, 32'hC000_3004);
        check_only(0,0,0,0, 0,0,1,0);

        section("Baca s3 (TM1638)");
        snapshot; axi_read(32'h0002_0008, data);
        check("Data dari s3, alamat lokal 0x8", data, 32'hD000_0008);
        check("RRESP s3 diteruskan", resp, 2'b10);
        check_only(0,0,0,0, 0,0,0,1);

        section("Tulis s0 sampai s3");
        snapshot; axi_write(32'h0000_0040, 32'h1111_1111, 4'b1111);
        check("s0 alamat lokal", m0.last_awaddr, 32'h40);
        check("s0 data",         m0.last_wdata,  32'h1111_1111);
        check("s0 strobe",       m0.last_wstrb,  4'b1111);
        check_only(1,0,0,0, 0,0,0,0);

        snapshot; axi_write(32'h1000_3FFC, 32'h2222_2222, 4'b0011);
        check("s1 alamat lokal", m1.last_awaddr, 32'h3FFC);
        check("s1 data",         m1.last_wdata,  32'h2222_2222);
        check("s1 strobe",       m1.last_wstrb,  4'b0011);
        check_only(0,1,0,0, 0,0,0,0);

        snapshot; axi_write(32'h0003_0000, 32'h3333_3333, 4'b1000);
        check("s2 alamat lokal", m2.last_awaddr, 32'h0);
        check("s2 data",         m2.last_wdata,  32'h3333_3333);
        check("s2 strobe",       m2.last_wstrb,  4'b1000);
        check_only(0,0,1,0, 0,0,0,0);

        snapshot; axi_write(32'h0002_FFFC, 32'h4444_4444, 4'b0100);
        check("s3 alamat lokal", m3.last_awaddr, 32'hFFFC);
        check("s3 data",         m3.last_wdata,  32'h4444_4444);
        check("s3 strobe",       m3.last_wstrb,  4'b0100);
        check("BRESP s3 diteruskan", resp, 2'b10);
        check_only(0,0,0,1, 0,0,0,0);

        section("Batas rentang alamat");
        snapshot; axi_read(ROM_HIGH, data);
        check("Alamat tertinggi s0", data, 32'hA000_FFFF);
        check_only(0,0,0,0, 1,0,0,0);
        snapshot; axi_read(RAM_LOW, data);
        check("Alamat terendah s1",  data, 32'hB000_0000);
        check_only(0,0,0,0, 0,1,0,0);
        snapshot; axi_read(RAM_HIGH, data);
        check("Alamat tertinggi s1", data, 32'hB000_FFFF);
        check_only(0,0,0,0, 0,1,0,0);
        snapshot; axi_read(GPIO_HIGH, data);
        check("Alamat tertinggi s2", data, 32'hC000_FFFF);
        check_only(0,0,0,0, 0,0,1,0);
        snapshot; axi_read(TM_LOW, data);
        check("Alamat terendah s3",  data, 32'hD000_0000);
        check_only(0,0,0,0, 0,0,0,1);

        // Baca ke s0 dan tulis ke s1 dimulai pada siklus yang sama.
        // picorv32_axi_adapter tidak pernah melakukan ini, sehingga SoC tidak terdampak.
        section("Batasan: AR dan AW bersamaan");
        snapshot;
        @(negedge clk);
        m_arvalid = 1'b1; m_araddr = 32'h0000_0004; m_rready = 1'b1;
        m_awvalid = 1'b1; m_awaddr = 32'h1000_0004;
        m_wvalid  = 1'b1; m_wdata  = 32'h5; m_wstrb = 4'hF; m_bready = 1'b1;
        @(negedge clk);
        check("Baca didahulukan: state = READ", uut.state, 3'b010);
        check("Baca diteruskan ke s0", s_arvalid[0], 1'b1);
        if (s_awvalid[0] === 1'b1)
            $display("  [NOTE] AW untuk alamat s1 ikut diteruskan ke s0 selama state READ. Tulis bisa masuk ke slave yang salah pada master yang memakai AR dan AW bersamaan.");
        else
            $display("  [NOTE] AW tidak diteruskan selama state READ.");
        m_awvalid = 1'b0; m_wvalid = 1'b0; m_arvalid = 1'b0;
        repeat (3) @(negedge clk);
        m_rready = 1'b0; m_bready = 1'b0;
        do_reset;

        section("Batasan: alamat tak terpetakan tidak mendapat respons");
        snapshot; axi_read(32'h0001_0000, data);
        check("Baca 0x00010000 tidak dijawab", timed_out, 1'b1);
        check_only(0,0,0,0, 0,0,0,0);
        do_reset;
        snapshot; axi_write(32'hFFFF_FFFC, 32'h6, 4'hF);
        check("Tulis 0xFFFFFFFC tidak dijawab", timed_out, 1'b1);
        check_only(0,0,0,0, 0,0,0,0);
        do_reset;

        section("Pulih setelah reset");
        snapshot; axi_read(32'h1000_0000, data);
        check("Transaksi berikutnya berhasil", data, 32'hB000_0000);
        check_only(0,0,0,0, 0,1,0,0);

        finish_tb;
    end

endmodule
