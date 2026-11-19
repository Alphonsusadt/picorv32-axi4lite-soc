`timescale 1ns / 1ps

// Testbench blok axi4_lite_spi dengan model TM1638.
//
// Register diakses lewat AXI4-Lite seperti yang akan dilakukan firmware:
//   - ID, baca ulang CTRL/DIV/CS, pin CS_N,
//   - DATA diabaikan saat EN = 0, STATUS.BUSY dan RX_VALID,
//   - menulis 16 byte display + kecerahan ke TM1638 (mode 3, LSB dulu, 3-wire),
//   - membaca 4 byte tombol TM1638 lewat pin DIO yang sama,
//   - mode 4-wire biasa (MSB dulu) dengan loopback SDO -> SDI.

module tb_axi4_lite_spi;

    `include "tb_utils.vh"

    localparam CTRL = 32'h00, DIV = 32'h04, CS = 32'h08, DATA = 32'h0C, STATUS = 32'h10, ID = 32'h14;

    localparam EN = 1, CPOL = 2, CPHA = 4, LSB_FIRST = 8, THREE_WIRE = 16, RX_EN = 32;
    localparam TM_MODE = EN | CPOL | CPHA | LSB_FIRST | THREE_WIRE;

    reg         iCLK, iRST;

    reg         s_AWVALID, s_WVALID, s_BREADY, s_ARVALID, s_RREADY;
    reg  [31:0] s_AWADDR, s_WDATA, s_ARADDR;
    reg  [ 3:0] s_WSTRB;
    wire        s_AWREADY, s_WREADY, s_BVALID, s_ARREADY, s_RVALID;
    wire [ 1:0] s_BRESP, s_RRESP;
    wire [31:0] s_RDATA;

    wire        sck, sdo, sdo_oe;
    wire [1:0]  cs_n;
    reg         loopback;
    wire        dio;

    reg  [31:0] data;
    reg  [ 1:0] resp;

    axi4_lite_spi uut (
        .iCLK(iCLK), .iRST(iRST),
        .s_AWVALID(s_AWVALID), .s_AWPROT(3'b000), .s_AWADDR(s_AWADDR), .s_AWREADY(s_AWREADY),
        .s_WVALID(s_WVALID), .s_WDATA(s_WDATA), .s_WSTRB(s_WSTRB), .s_WREADY(s_WREADY),
        .s_BREADY(s_BREADY), .s_BVALID(s_BVALID), .s_BRESP(s_BRESP),
        .s_ARVALID(s_ARVALID), .s_ARPROT(3'b000), .s_ARADDR(s_ARADDR), .s_ARREADY(s_ARREADY),
        .s_RREADY(s_RREADY), .s_RVALID(s_RVALID), .s_RRESP(s_RRESP), .s_RDATA(s_RDATA),
        .oSCK(sck), .oCS_N(cs_n), .oSDO(sdo), .oSDO_OE(sdo_oe), .iSDI(loopback ? sdo : dio)
    );

    // Pin DIO dua arah, seperti buffer tri-state di top level board
    assign dio = sdo_oe ? sdo : 1'bz;
    pullup (dio);

    reg [31:0] keys;
    tm1638_model tm (.stb(cs_n[0]), .clk(sck), .dio(dio), .keys(keys));

    initial iCLK = 1'b0;
    always #5 iCLK = ~iCLK;

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
        end
    endtask

    // Seperti firmware: tulis DATA lalu tunggu BUSY = 0
    task spi_xfer;
        input  [7:0]  tx;
        output [7:0]  rx;
        reg    [31:0] st;
        integer       t;
        begin
            axi_write(DATA, {24'd0, tx});
            st = 1; t = 0;
            while (st[0] && t < 200) begin axi_read(STATUS, st); t = t + 1; end
            axi_read(DATA, st);
            rx = st[7:0];
        end
    endtask

    reg [7:0] rx;
    reg [7:0] seg [0:15];
    integer   i, ok;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_axi4_lite_spi.vcd");
            $dumpvars(0, tb_axi4_lite_spi);
        end

        iRST = 1'b0; loopback = 1'b0; keys = 32'h0;
        s_AWVALID = 1'b0; s_WVALID = 1'b0; s_BREADY = 1'b0; s_ARVALID = 1'b0; s_RREADY = 1'b0;
        s_AWADDR = 32'h0; s_WDATA = 32'h0; s_WSTRB = 4'h0; s_ARADDR = 32'h0;
        repeat (3) @(negedge iCLK);

        section("Reset");
        check("CS_N = 11 (tidak aktif)", cs_n, 2'b11);
        check("SDO_OE = 0 (EN = 0)", sdo_oe, 1'b0);
        iRST = 1'b1;
        repeat (2) @(negedge iCLK);

        section("Register");
        axi_read(ID, data);
        check("ID = SPI1", data, 32'h5350_4931);
        check("RRESP = OKAY", resp, 2'b00);
        axi_write(CTRL, TM_MODE);
        check("BRESP = OKAY", resp, 2'b00);
        axi_read(CTRL, data);
        check("CTRL dibaca ulang", data, TM_MODE);
        axi_write(DIV, 32'h0001_0003);
        axi_read(DIV, data);
        check("DIV hanya 16 bit", data, 32'h0000_0003);
        axi_write(CS, 32'h2);
        axi_read(CS, data);
        check("CS dibaca ulang", data, 32'h2);
        check("CS1 aktif: CS_N = 01", cs_n, 2'b01);
        axi_write(CS, 32'h0);
        check("CS_N kembali 11", cs_n, 2'b11);
        axi_read(32'h1C, data);
        check("Alamat tidak terpakai = 0", data, 32'h0);
        check("SCK idle tinggi (CPOL = 1)", sck, 1'b1);

        section("DATA saat EN = 0");
        axi_write(CTRL, TM_MODE & ~EN);
        axi_write(DATA, 32'hFF);
        axi_read(STATUS, data);
        check("Tidak mulai transfer", data, 32'h0);
        axi_write(CTRL, TM_MODE);

        section("STATUS");
        axi_write(DIV, 32'd20);
        axi_write(DATA, 32'h00);
        axi_read(STATUS, data);
        check("BUSY = 1 setelah DATA ditulis", data[0], 1'b1);
        check("RX_VALID = 0 selama transfer", data[1], 1'b0);
        ok = 0;
        while (data[0]) begin axi_read(STATUS, data); ok = ok + 1; end
        check("RX_VALID = 1 setelah selesai", data[1], 1'b1);
        axi_write(DIV, 32'd1);

        section("TM1638: tulis display");
        for (i = 0; i < 16; i = i + 1) seg[i] = 8'h11 * i + 8'h06;
        axi_write(CS, 1); spi_xfer(8'h40, rx); axi_write(CS, 0);
        axi_write(CS, 1); spi_xfer(8'hC0, rx);
        for (i = 0; i < 16; i = i + 1) spi_xfer(seg[i], rx);
        axi_write(CS, 0);
        axi_write(CS, 1); spi_xfer(8'h8F, rx); axi_write(CS, 0);
        ok = 1;
        for (i = 0; i < 16; i = i + 1) if (tm.disp[i] !== seg[i]) ok = 0;
        check("16 byte display diterima TM1638", ok, 1);
        check("Pengaturan display 0x8F", tm.display_ctrl, 8'h8F);

        section("TM1638: alamat tetap");
        axi_write(CS, 1); spi_xfer(8'h44, rx); axi_write(CS, 0);
        axi_write(CS, 1); spi_xfer(8'hC5, rx); spi_xfer(8'h7F, rx); axi_write(CS, 0);
        check("disp[5] = 7F", tm.disp[5], 8'h7F);
        check("disp[6] tidak berubah", tm.disp[6], seg[6]);

        section("TM1638: baca tombol lewat DIO");
        keys = 32'h8421_1248;
        axi_write(CS, 1);
        spi_xfer(8'h42, rx);
        axi_write(CTRL, TM_MODE | RX_EN);
        check("DIO dilepas master (SDO_OE = 0)", sdo_oe, 1'b0);
        data = 0;
        for (i = 0; i < 4; i = i + 1) begin
            spi_xfer(8'h00, rx);
            data[8*i +: 8] = rx;
        end
        axi_write(CS, 0);
        axi_write(CTRL, TM_MODE);
        check("4 byte tombol", data, 32'h8421_1248);
        check("Tidak ada pelanggaran protokol TM1638", tm.protocol_errors, 0);
        check("Jumlah byte diterima TM1638", tm.bytes_received, 23);

        section("SPI 4-wire biasa (mode 0, MSB dulu, loopback)");
        loopback = 1'b1;
        axi_write(CTRL, EN);
        axi_write(CS, 2);
        spi_xfer(8'hA7, rx);
        check("Loopback A7", rx, 8'hA7);
        spi_xfer(8'h3C, rx);
        check("Loopback 3C", rx, 8'h3C);
        check("SDO_OE = 1 pada 4-wire", sdo_oe, 1'b1);
        check("SCK idle rendah (CPOL = 0)", sck, 1'b0);
        axi_write(CS, 0);
        check("TM1638 tidak menerima byte (CS0 tidak aktif)", tm.bytes_received, 23);

        finish_tb;
    end

    initial begin
        #2000000;
        $display("TIMEOUT"); errors = errors + 1;
        finish_tb;
    end

endmodule
