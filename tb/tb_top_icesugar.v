`timescale 1ns / 1ps

// Testbench top level iCESugar (top_icesugar) dengan program demo_led_berkedip.
//
// Memastikan:
//   - power-on reset bekerja,
//   - CPU menjalankan program dari ROM 4 KB dan menulis LED berulang,
//   - pembagi clock membuat LED berkedip cukup lambat untuk dilihat.
//
// Simulasi memakai CLK_DIV_LOG2 = 0 agar cepat, lalu laju kedip pada board
// dihitung dari jumlah siklus per penulisan LED.

module tb_top_icesugar;

    `include "tb_utils.vh"

    reg        clk;
    reg  [3:0] SW;
    wire       LED_R, LED_G, LED_B;

    top_icesugar #(.CLK_DIV_LOG2(0)) uut (
        .clk(clk), .SW(SW),
        .LED_R(LED_R), .LED_G(LED_G), .LED_B(LED_B)
    );

    // 12 MHz
    initial clk = 1'b0;
    always #41.667 clk = ~clk;

    integer cycles = 0, gpio_writes = 0, pending = 0, max_pending = 0;
    integer write2_cycle = 0, write12_cycle = 0;

    always @(posedge clk) begin
        if (uut.rst_n) begin
            cycles = cycles + 1;
            if ((uut.u_soc.u1.mem_axi_arvalid && !uut.u_soc.u1.mem_axi_arready) ||
                (uut.u_soc.u1.mem_axi_awvalid && !uut.u_soc.u1.mem_axi_awready))
                pending = pending + 1;
            else
                pending = 0;
            if (pending > max_pending) max_pending = pending;
            if (uut.u_soc.u2.s2_AWVALID && uut.u_soc.u2.s2_AWREADY) begin
                gpio_writes = gpio_writes + 1;
                if (gpio_writes == 2)  write2_cycle  = cycles;
                if (gpio_writes == 12) write12_cycle = cycles;
            end
        end
    end

    // Frekuensi kedip oLED[bit] pada board: nilai LED naik 3 setiap penulisan,
    // sehingga bit tersebut berganti periode penuh setiap 2^(bit+1)/3 penulisan.
    function real blink_hz;
        input integer bit_index;
        input integer div_log2;
        input real    board_mhz;
        real cycles_per_write;
        begin
            cycles_per_write = (write12_cycle - write2_cycle) / 10.0;
            blink_hz = board_mhz * 1.0e6 / (1 << div_log2) / cycles_per_write
                       * 3.0 / (1 << (bit_index + 1));
        end
    endfunction

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_top_icesugar.vcd");
            $dumpvars(0, tb_top_icesugar);
        end

        SW = 4'b0000;

        section("Power-on reset");
        repeat (5) @(negedge clk);
        check("rst_n = 0 di awal",    uut.rst_n, 1'b0);
        check("LED padam saat reset", {LED_R, LED_G, LED_B}, 3'b111);
        repeat (20) @(negedge clk);
        check("rst_n = 1 setelah POR", uut.rst_n, 1'b1);

        section("Program demo_led_berkedip dari ROM 4 KB");
        repeat (5000) @(negedge clk);
        check("trap tetap 0",           uut.trap, 1'b0);
        check("Bus tidak menggantung",  max_pending < 100, 1'b1);
        check("LED ditulis berulang",   gpio_writes > 100, 1'b1);

        section("Laju kedip di board");
        $display("  [INFO] %0.1f siklus per penulisan LED", (write12_cycle - write2_cycle) / 10.0);
        $display("  [INFO] iCESugar, pembagi 2^4: LED hijau berkedip %0.1f Hz", blink_hz(15, 4, 12.0));
        $display("  [INFO] Tang Nano 20K, pembagi 2^7: lampu berpindah %0.1f kali per detik",
                 2.0 * blink_hz(13, 7, 27.0));
        check("LED hijau berkedip 0,5-5 Hz", (blink_hz(15, 4, 12.0) > 0.5) && (blink_hz(15, 4, 12.0) < 5.0), 1'b1);
        check("LED merah dan biru padam", {LED_R, LED_B}, 2'b11);

        finish_tb;
    end

endmodule
