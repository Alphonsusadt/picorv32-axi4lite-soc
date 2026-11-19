`timescale 1ns / 1ps

// Testbench top ASIC soc_nim_asic (ROM kombinasional, RAM 64 word, tanpa
// loader) + model TM1638. Bisa dipakai untuk RTL maupun netlist hasil
// LibreLane (lihat asic/README.md).
//
// CLK_HZ diperkecil ke 2,4 MHz agar 1 detik firmware = 2,4 juta siklus.
// Pada clock ini firmware memilih DIV SPI = 2 (SCK = f_clk / 6), nilai
// terkecil yang masih aman untuk sinkronisasi DIO 2 siklus (lihat
// soc_nim_asic.v). Jadi jalur pembagi SCK dan pembacaan DIO diuji pada
// kondisi batasnya; di 25 MHz DIV = 25.

module tb_soc_nim_asic;

    `include "tb_utils.vh"

    localparam CLK_HZ = 2400000;
    localparam SECOND = ((CLK_HZ + 4800) / 9600) * 9600;

    reg         clk, rst_n;
    wire        trap;
    wire [2:0]  led;
    wire        tm_stb, tm_clk, tm_dio_out, tm_dio_oe;
    wire        dio;
    reg  [31:0] keys;

`ifdef GL
    soc_nim_asic uut (
`else
    soc_nim_asic #(.CLK_HZ(CLK_HZ)) uut (
`endif
        .clk(clk), .rst_n(rst_n),
        .tm_stb(tm_stb), .tm_clk(tm_clk),
        .tm_dio_out(tm_dio_out), .tm_dio_oe(tm_dio_oe), .tm_dio_in(dio),
        .uart_rx(1'b1), .uart_tx(),
        .led(led), .trap(trap)
    );

    // Pad dua arah di luar blok digital
    assign dio = tm_dio_oe ? tm_dio_out : 1'bz;
    pullup (dio);

    tm1638_model tm (.stb(tm_stb), .clk(tm_clk), .dio(dio), .keys(keys));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    function [7:0] text_char;
        input integer i;
        case (i)
             0: text_char = 8'h5B;  1: text_char = 8'h5B;  2: text_char = 8'h40;
             3: text_char = 8'h6D;  4: text_char = 8'h3F;  5: text_char = 8'h6D;
             6: text_char = 8'h6F;  7: text_char = 8'h3F;  8: text_char = 8'h7F;
             9: text_char = 8'h40; 10: text_char = 8'h70; 11: text_char = 8'h79;
            12: text_char = 8'h40; 13: text_char = 8'h6D; 14: text_char = 8'h6D;
            15: text_char = 8'h4F; 16: text_char = 8'h6F; 17: text_char = 8'h6F;
            default: text_char = 8'h00;
        endcase
    endfunction

    // Lebar pulsa SCK minimum (dalam siklus clock)
    integer cycle = 0, sck_last_edge = 0, sck_min = 1000000;
    reg     sck_q = 1'b1;
    always @(posedge clk) begin
        cycle = cycle + 1;
        if (tm_clk !== sck_q) begin
            if (sck_last_edge > 0 && !tm_stb && cycle - sck_last_edge < sck_min)
                sck_min = cycle - sck_last_edge;
            sck_last_edge = cycle;
            sck_q = tm_clk;
        end
    end

    // Setiap perubahan LED board = posisi baru; periksa jendela NIM saat itu
    integer frames = 0, frame_errors = 0, d, pos;
    integer tick_time [0:15];
    reg [2:0] led_q = 3'b000;
    always @(posedge clk) if (led !== led_q) begin
        led_q = led;
        if (frames < 16) tick_time[frames] = cycle;
        frames = frames + 1;
    end

    task check_window;
        input integer p;
        integer k, bad;
        begin
            bad = 0;
            for (k = 0; k < 8; k = k + 1)
                if (tm.disp[k * 2] !== text_char(k + p - 8)) bad = bad + 1;
            check("8 digit = jendela NIM", bad, 0);
        end
    endtask

    task wait_frames;
        input integer n;
        integer target, t;
        begin
            target = frames + n;
            t = 0;
            while (frames < target && t < 20000000) begin @(negedge clk); t = t + 1; end
        end
    endtask

    task wait_disp;
        input integer addr;
        input [7:0]   value;
        integer t;
        begin
            t = 0;
            while (tm.disp[addr] !== value && t < 2000000) begin @(negedge clk); t = t + 1; end
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_soc_nim_asic.vcd");
            $dumpvars(0, tb_soc_nim_asic);
        end

        keys  = 32'h0;
        rst_n = 1'b0;
        repeat (10) @(negedge clk);
        rst_n = 1'b1;

        section("Inisialisasi");
        wait_disp(1, 8'h01);
        repeat (20000) @(negedge clk);
        check("trap = 0", trap, 1'b0);
        check("Display on, kecerahan maksimum (0x8F)", tm.display_ctrl, 8'h8F);
        check("Mode awal 00: LED1", {tm.disp[5][0], tm.disp[3][0], tm.disp[1][0]}, 3'b001);
        check("Posisi 0: 8 digit padam", {tm.disp[0], tm.disp[14]}, 16'h0);
        check("SCK = 3 siklus per setengah periode (DIV = 2)", sck_min, 3);

        section("Tombol S2 -> mode 01 (baca DIO lewat sinkronisasi)");
        keys = 32'h0000_0100;              // byte 1 bit 0 = S2
        wait_disp(3, 8'h01);
        keys = 32'h0;
        check("LED2 menyala", tm.disp[3], 8'h01);
        check("LED1 padam",   tm.disp[1], 8'h00);

        section("Mode 01: posisi naik tiap 1 detik");
        wait_frames(1);
        check("LED board = posisi 1", led, 3'd1);
        check_window(1);
        wait_frames(1);
        check("LED board = posisi 2", led, 3'd2);
        check_window(2);
        check("Mode tetap 01 setelah S2 dilepas", tm.disp[3], 8'h01);
        $display("  [INFO] interval %0d siklus (target %0d)",
                 tick_time[frames - 1] - tick_time[frames - 2], SECOND);
        check("Interval = 1 detik (+-2%)",
              (tick_time[frames - 1] - tick_time[frames - 2] > SECOND * 98 / 100) &&
              (tick_time[frames - 1] - tick_time[frames - 2] < SECOND * 102 / 100), 1'b1);

        section("Protokol");
        check("Tidak ada pelanggaran protokol TM1638", tm.protocol_errors, 0);
        check("trap tetap 0", trap, 1'b0);
        $display("  [INFO] SCK minimum %0d siklus, %0d byte ke TM1638, %0d siklus",
                 sck_min, tm.bytes_received, cycle);

        finish_tb;
    end

    initial begin
        #150000000;
        $display("TIMEOUT"); errors = errors + 1;
        finish_tb;
    end

endmodule
