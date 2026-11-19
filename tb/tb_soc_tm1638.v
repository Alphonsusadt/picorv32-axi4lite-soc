`timescale 1ns / 1ps

// Testbench SoC + firmware tm1638_demo + model TM1638.
//
// ROM diisi rtl/tm1638_demo_words.hex (hasil firmware/Makefile). Diperiksa:
//   - firmware mendeteksi SPI (register ID) dan menginisialisasi TM1638,
//   - angka penghitung muncul di digit paling kanan dan naik,
//   - tombol S2 menyalakan LED 2 TM1638, S8 mengubah tampilan ke heksadesimal,
//     S1 mengembalikan penghitung ke 0,
//   - LED board tetap ditulis lewat GPIO,
//   - tidak ada pelanggaran protokol TM1638 dan CPU tidak trap.
//
// Waveform dibuat jika dijalankan dengan +vcd.

module tb_soc_tm1638;

    `include "tb_utils.vh"

    reg         clk, rst_n;
    wire        trap;
    wire [15:0] oLED;
    wire        spi_sck, spi_sdo, spi_sdo_oe;
    wire [1:0]  spi_cs_n;
    wire        dio;
    reg  [31:0] keys;

    picorv32_soc #(
        .ROM_ADDR_BITS(10),
        .RAM_ADDR_BITS(11),
        .ROM_INIT("tm1638_demo_words.hex")
    ) uut (
        .clk(clk), .rst_n(rst_n), .trap(trap),
        .iSW(16'h0), .oLED(oLED),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n),
        .spi_sdo(spi_sdo), .spi_sdo_oe(spi_sdo_oe), .spi_sdi(dio),
        .uart_rx(1'b1), .uart_tx(), .loader_busy(), .loader_error()
    );

    // Buffer tri-state DIO seperti di top level board
    assign dio = spi_sdo_oe ? spi_sdo : 1'bz;
    pullup (dio);

    tm1638_model tm (.stb(spi_cs_n[0]), .clk(spi_sck), .dio(dio), .keys(keys));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Pola segmen angka 0-9 dan A-F
    function [7:0] font;
        input [3:0] d;
        case (d)
            4'h0: font = 8'h3F; 4'h1: font = 8'h06; 4'h2: font = 8'h5B; 4'h3: font = 8'h4F;
            4'h4: font = 8'h66; 4'h5: font = 8'h6D; 4'h6: font = 8'h7D; 4'h7: font = 8'h07;
            4'h8: font = 8'h7F; 4'h9: font = 8'h6F; 4'hA: font = 8'h77; 4'hB: font = 8'h7C;
            4'hC: font = 8'h39; 4'hD: font = 8'h5E; 4'hE: font = 8'h79; default: font = 8'h71;
        endcase
    endfunction

    // Nilai yang sedang tampil dibaca kembali dari memori display model
    function integer shown_decimal;
        input dummy;
        integer d, v, k, found;
        begin
            v = 0;
            for (d = 0; d < 8; d = d + 1) begin
                found = -1;
                for (k = 0; k < 10; k = k + 1)
                    if (tm.disp[d * 2] == font(k)) found = k;
                if (found >= 0) v = v * 10 + found;
                else if (tm.disp[d * 2] != 8'h00) v = -1000000;
            end
            shown_decimal = v;
        end
    endfunction

    // GPIO: catat setiap tulisan
    integer gpio_writes = 0;
    reg [31:0] last_gpio;
    always @(posedge clk) if (rst_n && uut.u2.s2_AWVALID && uut.u2.s2_AWREADY) begin
        gpio_writes = gpio_writes + 1;
        last_gpio   = uut.u2.s2_WDATA;
    end

    task wait_gpio_writes;
        input integer n;
        integer target, t;
        begin
            target = gpio_writes + n;
            t = 0;
            while (gpio_writes < target && t < 3000000) begin @(negedge clk); t = t + 1; end
        end
    endtask

    integer v1, v2, i, ok;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_soc_tm1638.vcd");
            $dumpvars(0, tb_soc_tm1638);
        end

        keys  = 32'h0;
        rst_n = 1'b0;
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        section("Inisialisasi TM1638");
        wait_gpio_writes(2);
        check("trap = 0", trap, 1'b0);
        check("Display on, kecerahan 2 (0x8A)", tm.display_ctrl, 8'h8A);
        ok = 1;
        for (i = 1; i < 16; i = i + 2) if (tm.disp[i] !== 8'h00) ok = 0;
        check("8 LED TM1638 padam", ok, 1);

        section("Penghitung desimal");
        v1 = shown_decimal(0);
        wait_gpio_writes(3);
        v2 = shown_decimal(0);
        $display("  [INFO] tampil %0d lalu %0d", v1, v2);
        check("Angka valid di display", (v1 >= 0) && (v2 >= 0), 1'b1);
        check("Angka naik 3", v2 - v1, 3);
        check("Digit kiri padam", tm.disp[0], 8'h00);
        check("GPIO = penghitung << 13", last_gpio[12:0], 13'h0);

        section("Tombol S2 -> LED 2");
        keys = 32'h0000_0100;              // byte 1 bit 0 = S2
        wait_gpio_writes(2);
        check("LED 2 menyala (alamat 3)", tm.disp[3], 8'h01);
        check("LED 1 tetap padam",        tm.disp[1], 8'h00);
        keys = 32'h0;
        wait_gpio_writes(2);
        check("LED 2 padam setelah dilepas", tm.disp[3], 8'h00);

        section("Tombol S8 -> heksadesimal");
        keys = 32'h1000_0000;              // byte 3 bit 4 = S8
        wait_gpio_writes(2);
        check("Digit kiri = 0 (bukan padam)", tm.disp[0], font(0));
        check("LED 8 menyala (alamat 15)",    tm.disp[15], 8'h01);
        keys = 32'h0;

        section("Tombol S1 -> reset penghitung");
        keys = 32'h0000_0001;              // byte 0 bit 0 = S1
        wait_gpio_writes(2);
        check("Display = 0 selama S1 ditekan", shown_decimal(0), 0);
        keys = 32'h0;
        wait_gpio_writes(2);
        check("Penghitung mulai lagi dari kecil", shown_decimal(0) <= 2, 1'b1);

        section("Protokol");
        check("Tidak ada pelanggaran protokol TM1638", tm.protocol_errors, 0);
        check("trap tetap 0", trap, 1'b0);
        $display("  [INFO] %0d byte diterima TM1638, %0d tulisan GPIO, %0d siklus clock",
                 tm.bytes_received, gpio_writes, $time / 10);

        finish_tb;
    end

    initial begin
        #400000000;
        $display("TIMEOUT"); errors = errors + 1;
        finish_tb;
    end

endmodule
