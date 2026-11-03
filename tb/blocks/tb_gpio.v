`timescale 1ns / 1ps

// Testbench blok inti GPIO (gpio).

module tb_gpio;

    `include "tb_utils.vh"

    reg         iCLK, iRST;
    reg         w_REQ, r_REQ;
    reg  [31:0] w_DATA, w_ADDR, r_ADDR;
    reg  [15:0] iSW;
    wire [31:0] r_DATA;
    wire [15:0] oLED;

    gpio uut (
        .iCLK(iCLK), .iRST(iRST),
        .w_REQ(w_REQ), .r_REQ(r_REQ),
        .w_DATA(w_DATA), .w_ADDR(w_ADDR), .r_ADDR(r_ADDR),
        .r_DATA(r_DATA),
        .iSW(iSW), .oLED(oLED)
    );

    initial iCLK = 1'b0;
    always #5 iCLK = ~iCLK;

    initial begin
        $dumpfile("tb_gpio.vcd");
        $dumpvars(0, tb_gpio);

        iRST = 1'b0; w_REQ = 1'b0; r_REQ = 1'b0;
        w_DATA = 32'h0; w_ADDR = 32'h0; r_ADDR = 32'h0; iSW = 16'h0;
        repeat (2) @(negedge iCLK);

        section("Reset");
        check("LED = 0",    oLED,   16'h0);
        check("r_DATA = 0", r_DATA, 32'h0);
        iRST = 1'b1;

        section("Tulis LED");
        w_DATA = 32'h0000_A5A5; w_REQ = 1'b1;
        @(negedge iCLK);
        w_REQ = 1'b0;
        check("LED mengikuti w_DATA", oLED, 16'hA5A5);
        w_DATA = 32'h1234_5678; w_REQ = 1'b1;
        @(negedge iCLK);
        w_REQ = 1'b0;
        check("Hanya 16 bit bawah masuk", oLED, 16'h5678);
        w_DATA = 32'hFFFF_FFFF;
        repeat (2) @(negedge iCLK);
        check("LED tetap tanpa w_REQ", oLED, 16'h5678);

        section("Baca switch");
        iSW = 16'hBEEF; r_REQ = 1'b1;
        @(negedge iCLK);
        r_REQ = 1'b0;
        check("r_DATA = switch, 16 bit atas nol", r_DATA, 32'h0000_BEEF);
        iSW = 16'h1111;
        repeat (2) @(negedge iCLK);
        check("r_DATA tetap tanpa r_REQ", r_DATA, 32'h0000_BEEF);

        section("Tulis didahulukan daripada baca");
        iSW = 16'h2222; w_DATA = 32'h0000_3333; w_REQ = 1'b1; r_REQ = 1'b1;
        @(negedge iCLK);
        w_REQ = 1'b0; r_REQ = 1'b0;
        check("LED berubah",       oLED,   16'h3333);
        check("r_DATA tidak berubah", r_DATA, 32'h0000_BEEF);

        section("Batasan: alamat diabaikan");
        w_ADDR = 32'h0000_0040; w_DATA = 32'h0000_0055; w_REQ = 1'b1;
        @(negedge iCLK);
        w_REQ = 1'b0;
        check("LED berubah untuk alamat apa pun", oLED, 16'h0055);

        section("Reset asinkron");
        #1 iRST = 1'b0;
        #1;
        check("LED = 0 tanpa menunggu clock",    oLED,   16'h0);
        check("r_DATA = 0 tanpa menunggu clock", r_DATA, 32'h0);

        finish_tb;
    end

endmodule
