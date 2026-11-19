`timescale 1ns / 1ps

// Testbench SoC + firmware nim_scroll (tugas UTS di atas PicoRV32) + model TM1638.
//
// ROM diisi rtl/nim_scroll_words.hex. UART_DIV = 2 sehingga firmware
// menganggap 1 detik = 2 x 9600 = 19200 siklus (simulasi lebih cepat).
// Diperiksa:
//   - inisialisasi: display on kecerahan maksimum (0x8F), mode awal 00 (LED1),
//   - mode 00 bolak-balik: posisi 1..26 lalu turun 25, 24, ...,
//   - isi 8 digit selalu sama dengan jendela NIM "22-505908-TE-55399",
//   - S2 -> mode 01 ke kiri (LED2), posisi 26 kembali ke 0,
//   - S3 -> mode 10 ke kanan (LED3), posisi 0 kembali ke 26,
//   - mode tetap setelah tombol dilepas, prioritas S1 saat S1+S3 bersamaan,
//   - interval animasi 19200 siklus, tanpa pelanggaran protokol dan tanpa trap.

module tb_soc_nim;

    `include "tb_utils.vh"

    localparam SECOND = 2 * 9600;

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
        .ROM_INIT("nim_scroll_words.hex"),
        .UART_DIV(2)
    ) uut (
        .clk(clk), .rst_n(rst_n), .trap(trap),
        .iSW(16'h0), .oLED(oLED),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n),
        .spi_sdo(spi_sdo), .spi_sdo_oe(spi_sdo_oe), .spi_sdi(dio),
        .uart_rx(1'b1), .uart_tx(), .loader_busy(), .loader_error()
    );

    assign dio = spi_sdo_oe ? spi_sdo : 1'bz;
    pullup (dio);

    tm1638_model tm (.stb(spi_cs_n[0]), .clk(spi_sck), .dio(dio), .keys(keys));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // "22-505908-TE-55399", pola segmen sama dengan localparam SEG_* UTS
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

    // ------------------------------------------------------------------
    // Setiap tulisan GPIO terjadi setelah display diperbarui: catat posisi
    // (GPIO >> 13), cocokkan 8 digit dengan jendela NIM dan LED dengan mode.
    // ------------------------------------------------------------------
    integer gpio_writes = 0;
    integer frame_errors = 0;
    integer pos_log  [0:255];
    integer time_log [0:255];
    integer cycle = 0;
    integer d, cur_pos, cur_mode;

    always @(posedge clk) cycle = cycle + 1;

    always @(posedge clk) if (rst_n && uut.u2.s2_AWVALID && uut.u2.s2_AWREADY) begin
        cur_pos = uut.u2.s2_WDATA >> 13;
        if (gpio_writes < 256) begin
            pos_log[gpio_writes]  = cur_pos;
            time_log[gpio_writes] = cycle;
        end
        gpio_writes = gpio_writes + 1;
        cur_mode = (tm.disp[1] == 8'h01) ? 0 : (tm.disp[3] == 8'h01) ? 1 :
                   (tm.disp[5] == 8'h01) ? 2 : 3;
        for (d = 0; d < 8; d = d + 1)
            if (tm.disp[d * 2] !== text_char(d + cur_pos - 8)) begin
                if (frame_errors < 5)
                    $display("  [FRAME] pos %0d digit %0d = %h, harus %h",
                             cur_pos, d, tm.disp[d * 2], text_char(d + cur_pos - 8));
                frame_errors = frame_errors + 1;
            end
    end

    task wait_gpio_writes;
        input integer n;
        integer target, t;
        begin
            target = gpio_writes + n;
            t = 0;
            while (gpio_writes < target && t < 5000000) begin @(negedge clk); t = t + 1; end
        end
    endtask

    // Tekan tombol sampai firmware menampilkan LED mode baru, lalu lepas
    task press;
        input [31:0] k;
        input integer led_addr;
        integer t;
        begin
            keys = k;
            t = 0;
            while (tm.disp[led_addr] !== 8'h01 && t < 200000) begin @(negedge clk); t = t + 1; end
            keys = 32'h0;
        end
    endtask

    function [2:0] leds;
        input dummy;
        leds = {tm.disp[5][0], tm.disp[3][0], tm.disp[1][0]};
    endfunction

    integer i, ok, start, last_pos;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_soc_nim.vcd");
            $dumpvars(0, tb_soc_nim);
        end

        keys  = 32'h0;
        rst_n = 1'b0;
        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        section("Inisialisasi");
        wait_gpio_writes(1);
        check("trap = 0", trap, 1'b0);
        check("Display on, kecerahan maksimum (0x8F)", tm.display_ctrl, 8'h8F);
        check("Mode awal 00: LED1 saja", leds(0), 3'b001);
        check("Posisi awal 0", pos_log[0], 0);
        ok = 1;
        for (i = 0; i < 8; i = i + 1) if (tm.disp[i * 2] !== 8'h00) ok = 0;
        check("8 digit padam (NIM belum masuk)", ok, 1);

        section("Mode 00: bolak-balik");
        start = gpio_writes;
        wait_gpio_writes(30);                 // posisi 1..26 lalu 25..22
        ok = 1;
        for (i = 0; i < 30; i = i + 1)
            if (pos_log[start + i] != ((i < 26) ? i + 1 : 51 - i)) ok = 0;
        check("Posisi 1..26 lalu 25, 24, 23, 22", ok, 1);
        ok = 1;
        for (i = 1; i < 30; i = i + 1)
            if (time_log[start + i] - time_log[start + i - 1] < SECOND - 3000 ||
                time_log[start + i] - time_log[start + i - 1] > SECOND + 3000) ok = 0;
        check("Interval tiap langkah = 1 detik (19200 siklus)", ok, 1);
        $display("  [INFO] rata-rata interval %0d siklus",
                 (time_log[start + 29] - time_log[start]) / 29);

        section("S2 -> mode 01 ke kiri");
        press(32'h0000_0100, 3);              // byte 1 bit 0 = S2
        wait_gpio_writes(1);
        check("LED2 saja", leds(0), 3'b010);
        last_pos = pos_log[gpio_writes - 1];
        start = gpio_writes;
        wait_gpio_writes(30);
        ok = 1;
        for (i = 0; i < 30; i = i + 1) begin
            if (pos_log[start + i] != ((last_pos >= 26) ? 0 : last_pos + 1)) ok = 0;
            last_pos = pos_log[start + i];
        end
        check("Posisi naik, 26 kembali ke 0", ok, 1);
        check("Mode tetap 01 setelah S2 dilepas", leds(0), 3'b010);

        section("S3 -> mode 10 ke kanan");
        press(32'h0001_0000, 5);              // byte 2 bit 0 = S3
        wait_gpio_writes(1);
        check("LED3 saja", leds(0), 3'b100);
        last_pos = pos_log[gpio_writes - 1];
        start = gpio_writes;
        wait_gpio_writes(30);
        ok = 1;
        for (i = 0; i < 30; i = i + 1) begin
            if (pos_log[start + i] != ((last_pos == 0) ? 26 : last_pos - 1)) ok = 0;
            last_pos = pos_log[start + i];
        end
        check("Posisi turun, 0 kembali ke 26", ok, 1);
        check("Mode tetap 10 setelah S3 dilepas", leds(0), 3'b100);

        section("S1 + S3 bersamaan -> prioritas S1");
        press(32'h0001_0001, 1);
        wait_gpio_writes(2);
        check("LED1 saja (mode 00)", leds(0), 3'b001);

        section("S4-S8 tidak memilih mode");
        // S4 = byte 3 bit 0, S5..S8 = byte 0..3 bit 4
        keys = 32'h1110_1010 | 32'h0100_0000;
        wait_gpio_writes(2);
        keys = 32'h0;
        check("Mode tetap 00", leds(0), 3'b001);

        section("Display dan protokol");
        check("Semua frame cocok dengan jendela NIM", frame_errors, 0);
        check("Tidak ada pelanggaran protokol TM1638", tm.protocol_errors, 0);
        check("trap tetap 0", trap, 1'b0);
        $display("  [INFO] %0d frame, %0d byte ke TM1638, %0d siklus",
                 gpio_writes, tm.bytes_received, cycle);

        finish_tb;
    end

    initial begin
        #200000000;
        $display("TIMEOUT"); errors = errors + 1;
        finish_tb;
    end

endmodule
