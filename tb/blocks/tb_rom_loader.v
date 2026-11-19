`timescale 1ns / 1ps

// Testbench blok rom_loader (skenario A).
// Diuji: frame benar ditulis ke ROM dan hold dilepas, checksum salah,
// N terlalu besar, N = 0 (hanya reset CPU), frame terputus (timeout),
// magic bootloader (55 AA 52 41) diabaikan, magic di tengah aliran
// tanpa jeda diabaikan.

module tb_rom_loader;

    `include "tb_utils.vh"

    localparam DIV      = 8;
    localparam UART_BIT = DIV * 10;          // ns, clock 10 ns
    localparam [31:0] MAGIC_ROM = 32'h4D52_AA55;
    localparam [31:0] MAGIC_RAM = 32'h4152_AA55;

    reg         clk, rst_n;
    reg         uart_line;
    wire        uart_out = 1'b1;
    wire        hold, error, busy, ld_we;
    wire [31:0] ld_addr, ld_data;

    rom_loader #(.ROM_WORDS(16), .GAP_BITS(20), .TIMEOUT_BITS(200)) uut (
        .clk(clk), .rst_n(rst_n), .clks_per_bit(DIV[15:0]), .rx(uart_line),
        .hold(hold), .error(error), .busy(busy),
        .ld_we(ld_we), .ld_addr(ld_addr), .ld_data(ld_data)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    reg [7:0]  frame_bytes [0:255];
    reg [31:0] rom [0:15];
    integer    writes;
    always @(posedge clk) if (ld_we) begin
        rom[ld_addr[3:0]] = ld_data;
        writes = writes + 1;
    end

    // Lama hold aktif (untuk frame N = 0)
    integer hold_cycles;
    always @(posedge clk) if (hold) hold_cycles = hold_cycles + 1;

    `include "uart_model.vh"

    task idle;
        input integer bits;
        begin
            uart_line = 1'b1;
            #(UART_BIT * bits);
        end
    endtask

    integer i, ok;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_rom_loader.vcd");
            $dumpvars(0, tb_rom_loader);
        end
        for (i = 0; i < 256; i = i + 1) frame_bytes[i] = (i * 37 + 11) & 8'hFF;
        for (i = 0; i < 16; i = i + 1)  rom[i] = 32'h0;
        writes = 0; hold_cycles = 0;
        uart_line = 1'b1;
        rst_n = 1'b0;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        idle(30);

        section("Frame benar, 4 word");
        uart_send(MAGIC_ROM[7:0]); uart_send(MAGIC_ROM[15:8]);
        uart_send(MAGIC_ROM[23:16]); uart_send(MAGIC_ROM[31:24]);
        check("hold = 1 setelah magic", hold, 1'b1);
        check("busy = 1", busy, 1'b1);
        uart_send(8'd4); uart_send(8'd0);
        begin : data_and_sum
            reg [7:0] sum;
            sum = 0;
            for (i = 0; i < 16; i = i + 1) begin
                uart_send(frame_bytes[i]);
                sum = sum + frame_bytes[i];
            end
            uart_send(sum);
        end
        repeat (5) @(negedge clk);
        ok = 1;
        for (i = 0; i < 4; i = i + 1)
            if (rom[i] !== {frame_bytes[4*i+3], frame_bytes[4*i+2], frame_bytes[4*i+1], frame_bytes[4*i]}) ok = 0;
        check("4 word tertulis little-endian", ok, 1);
        check("Jumlah tulis = 4", writes, 4);
        check("hold = 0 (CPU jalan)", hold, 1'b0);
        check("error = 0", error, 1'b0);
        check("busy = 0", busy, 1'b0);

        section("Checksum salah");
        idle(30);
        uart_send_frame(MAGIC_ROM, 2, 32, 8'h01);
        repeat (5) @(negedge clk);
        check("error = 1", error, 1'b1);
        check("CPU tetap ditahan", hold, 1'b1);

        section("Frame benar setelah error");
        idle(30);
        uart_send_frame(MAGIC_ROM, 2, 64, 8'h00);
        repeat (5) @(negedge clk);
        check("error = 0", error, 1'b0);
        check("hold = 0", hold, 1'b0);
        check("rom[1] = word baru", rom[1], {frame_bytes[71], frame_bytes[70], frame_bytes[69], frame_bytes[68]});

        section("N lebih besar dari ROM");
        idle(30);
        writes = 0;
        uart_send(8'h55); uart_send(8'hAA); uart_send(8'h52); uart_send(8'h4D);
        uart_send(8'd17); uart_send(8'd0);
        repeat (5) @(negedge clk);
        check("error = 1", error, 1'b1);
        check("Tidak ada tulisan", writes, 0);
        idle(30);
        uart_send_frame(MAGIC_ROM, 1, 0, 8'h00);
        repeat (5) @(negedge clk);
        check("Pulih dengan frame benar", hold | error, 1'b0);

        section("N = 0: hanya reset CPU");
        idle(30);
        writes = 0; hold_cycles = 0;
        uart_send_frame(MAGIC_ROM, 0, 0, 8'h00);
        repeat (5) @(negedge clk);
        check("Tidak ada tulisan", writes, 0);
        check("hold sempat aktif", hold_cycles > 0, 1'b1);
        check("hold = 0", hold, 1'b0);

        section("Frame terputus (timeout)");
        idle(30);
        uart_send(8'h55); uart_send(8'hAA); uart_send(8'h52); uart_send(8'h4D);
        uart_send(8'd2); uart_send(8'd0); uart_send(8'h12);
        idle(250);
        check("error = 1 setelah timeout", error, 1'b1);
        check("busy = 0", busy, 1'b0);
        idle(30);
        uart_send_frame(MAGIC_ROM, 1, 0, 8'h00);
        repeat (5) @(negedge clk);
        check("Pulih dengan frame benar", hold | error, 1'b0);

        section("Magic bootloader diabaikan");
        idle(30);
        writes = 0; hold_cycles = 0;
        uart_send_frame(MAGIC_RAM, 3, 0, 8'h00);
        idle(30);
        check("hold tidak pernah aktif", hold_cycles, 0);
        check("Tidak ada tulisan", writes, 0);

        section("Magic di tengah aliran tanpa jeda diabaikan");
        idle(30);
        uart_send(8'h00); uart_send(8'h55); uart_send(8'hAA); uart_send(8'h52); uart_send(8'h4D);
        uart_send(8'd1); uart_send(8'd0);
        idle(30);
        check("hold tidak pernah aktif", hold_cycles, 0);
        check("error tetap 0", error, 1'b0);

        finish_tb;
    end

endmodule
