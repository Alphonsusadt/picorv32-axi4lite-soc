`timescale 1ns / 1ps

// Testbench blok uart_tx dan uart_rx (loopback).
// Diuji dengan pembagi 22 (Tang Nano 9600 baud) dan 78 (iCESugar 9600 baud),
// lebar bit pada pin TX, dan deteksi stop bit salah.

module tb_uart;

    `include "tb_utils.vh"

    reg         clk, rst_n;
    reg  [15:0] div;
    reg         start;
    reg  [7:0]  tx_data;
    wire        busy, tx;
    reg         force_line, line_value;
    wire        line = force_line ? line_value : tx;
    wire        valid, ferr;
    wire [7:0]  rx_data;

    uart_tx utx (.clk(clk), .rst_n(rst_n), .clks_per_bit(div),
                 .start(start), .data(tx_data), .busy(busy), .tx(tx));
    uart_rx urx (.clk(clk), .rst_n(rst_n), .clks_per_bit(div), .rx(line),
                 .valid(valid), .data(rx_data), .frame_error(ferr));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    integer    rx_count, ferr_count;
    reg [7:0]  last_rx;
    always @(posedge clk) begin
        if (valid) begin rx_count = rx_count + 1; last_rx = rx_data; end
        if (ferr)  ferr_count = ferr_count + 1;
    end

    // Lebar start bit diukur dari pin TX
    integer t_fall, start_width;
    always @(negedge tx) t_fall = $time;
    always @(posedge tx) start_width = ($time - t_fall) / 10;

    task send;
        input [7:0] b;
        begin
            @(negedge clk);
            tx_data = b; start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            @(negedge busy);
            repeat (4) @(negedge clk);
        end
    endtask

    integer i, ok;
    reg [7:0] pattern [0:5];

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_uart.vcd");
            $dumpvars(0, tb_uart);
        end
        pattern[0] = 8'h55; pattern[1] = 8'hAA; pattern[2] = 8'h00;
        pattern[3] = 8'hFF; pattern[4] = 8'h52; pattern[5] = 8'h4D;
        rst_n = 1'b0; start = 1'b0; tx_data = 8'h00; div = 16'd22;
        force_line = 1'b0; line_value = 1'b1;
        rx_count = 0; ferr_count = 0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        section("Reset");
        check("TX idle = 1", tx, 1'b1);
        check("busy = 0", busy, 1'b0);

        section("Loopback pembagi 22 (Tang Nano)");
        ok = 1;
        for (i = 0; i < 6; i = i + 1) begin
            send(pattern[i]);
            if (last_rx !== pattern[i]) ok = 0;
        end
        check("6 byte diterima sama", ok, 1);
        check("Jumlah byte = 6", rx_count, 6);
        check("Lebar start bit = 22 siklus", start_width, 22);

        section("Loopback pembagi 78 (iCESugar)");
        div = 16'd78;
        rx_count = 0; ok = 1;
        for (i = 0; i < 6; i = i + 1) begin
            send(~pattern[i]);
            if (last_rx !== ~pattern[i]) ok = 0;
        end
        check("6 byte diterima sama", ok, 1);
        check("Lebar start bit = 78 siklus", start_width, 78);
        check("Tidak ada frame error", ferr_count, 0);

        section("Stop bit salah");
        force_line = 1'b1; line_value = 1'b0;     // jalur ditahan 0 (break)
        repeat (78 * 12) @(negedge clk);
        line_value = 1'b1;
        repeat (78 * 2) @(negedge clk);
        force_line = 1'b0;
        check("Frame error terdeteksi", ferr_count >= 1, 1'b1);
        check("Byte tidak dianggap valid", rx_count, 6);

        finish_tb;
    end

endmodule
