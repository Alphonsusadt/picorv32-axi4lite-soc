`timescale 1ns / 1ps

// Testbench SoC untuk dua skenario mengganti program lewat UART.
//
// Skenario A (uut_a, ROM = program LED dosen):
//   loader hardware menerima rtl/led_pattern.hex, menulis ROM lewat port B
//   sambil menahan CPU, lalu CPU menjalankan program baru dari ROM.
//   Checksum salah: CPU tetap ditahan dan loader_error = 1.
//
// Skenario B (uut_b, ROM = bootloader):
//   bootloader mengirim "BOOT", menerima firmware/bin/led_pattern_ram.hex ke
//   RAM, menjawab "OK", lalu CPU menjalankan program dari RAM.
//   Checksum salah: bootloader menjawab "ER" dan menunggu lagi.
//
// UART_DIV = 22, sama dengan Tang Nano 20K pada 9600 baud (kasus tersempit).

module tb_soc_loader;

    `include "tb_utils.vh"

    localparam DIV      = 22;
    localparam UART_BIT = DIV * 10;
    localparam [31:0] MAGIC_ROM = 32'h4D52_AA55;
    localparam [31:0] MAGIC_RAM = 32'h4152_AA55;
    localparam B_OFS    = 2048;            // posisi program RAM di frame_bytes

    reg         clk, rst_n;
    reg         uart_line;
    reg         sel_b;
    wire        tx_a, tx_b;
    wire        uart_out = sel_b ? tx_b : tx_a;

    wire        trap_a, trap_b, busy_a, err_a, busy_b, err_b;
    wire [15:0] led_a, led_b;

    picorv32_soc #(
        .ROM_ADDR_BITS(10), .RAM_ADDR_BITS(11),
        .ROM_INIT("demo_led_berkedip_xcelium_v2_words.hex"),
        .UART_DIV(DIV)
    ) uut_a (
        .clk(clk), .rst_n(rst_n), .trap(trap_a), .iSW(16'h0), .oLED(led_a),
        .spi_sck(), .spi_cs_n(), .spi_sdo(), .spi_sdo_oe(), .spi_sdi(1'b1),
        .uart_rx(sel_b ? 1'b1 : uart_line), .uart_tx(tx_a),
        .loader_busy(busy_a), .loader_error(err_a)
    );

    picorv32_soc #(
        .ROM_ADDR_BITS(10), .RAM_ADDR_BITS(11),
        .ROM_INIT("bootloader_words.hex"),
        .UART_DIV(DIV)
    ) uut_b (
        .clk(clk), .rst_n(rst_n), .trap(trap_b), .iSW(16'h0), .oLED(led_b),
        .spi_sck(), .spi_cs_n(), .spi_sdo(), .spi_sdo_oe(), .spi_sdi(1'b1),
        .uart_rx(sel_b ? uart_line : 1'b1), .uart_tx(tx_b),
        .loader_busy(busy_b), .loader_error(err_b)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    reg [7:0] frame_bytes [0:4095];

    `include "uart_model.vh"

    // Tulisan GPIO dan status hold
    integer    gpio_a = 0, gpio_b = 0, hold_a = 0, ram_fetch_b = 0;
    reg [31:0] last_gpio_a, last_gpio_b;
    always @(posedge clk) if (rst_n) begin
        if (uut_a.u2.s2_AWVALID && uut_a.u2.s2_AWREADY) begin
            gpio_a = gpio_a + 1; last_gpio_a = uut_a.u2.s2_WDATA;
        end
        if (uut_b.u2.s2_AWVALID && uut_b.u2.s2_AWREADY) begin
            gpio_b = gpio_b + 1; last_gpio_b = uut_b.u2.s2_WDATA;
        end
        if (!uut_a.sys_rst_n) hold_a = hold_a + 1;
        if (uut_b.u2.s1_ARVALID && uut_b.u2.s1_ARREADY && uut_b.u1.mem_axi_arprot == 3'b100)
            ram_fetch_b = ram_fetch_b + 1;
    end

    integer overrun_b = 0;
    always @(posedge uut_b.u9.rx_overrun) overrun_b = overrun_b + 1;

    task wait_cycles;
        input integer n;
        begin repeat (n) @(negedge clk); end
    endtask

    task wait_text;
        input [8*16-1:0] text;
        input integer    nchars;
        integer t;
        reg [8*16-1:0] mask;
        begin
            mask = (128'd1 << (8 * nchars)) - 1;
            t = 0;
            while (((uart_text[127:0] & mask) !== (text & mask)) && t < 400000) begin
                @(negedge clk); t = t + 1;
            end
        end
    endtask

    integer i, ok, n_a, n_b, g;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_soc_loader.vcd");
            $dumpvars(0, tb_soc_loader);
        end

        for (i = 0; i < 4096; i = i + 1) frame_bytes[i] = 8'hxx;
        $readmemh("led_pattern.hex", frame_bytes, 0);
        $readmemh("led_pattern_ram.hex", frame_bytes, B_OFS);
        n_a = 0; while (frame_bytes[4 * n_a] !== 8'hxx) n_a = n_a + 1;
        n_b = 0; while (frame_bytes[B_OFS + 4 * n_b] !== 8'hxx) n_b = n_b + 1;
        $display("  [INFO] led_pattern %0d word, led_pattern_ram %0d word", n_a, n_b);

        uart_line = 1'b1; sel_b = 1'b0;
        rst_n = 1'b0;
        wait_cycles(5);
        rst_n = 1'b1;

        // ---------------------------------------------------------------
        section("A: program dosen berjalan dulu");
        wait_cycles(3000);
        check("LED ditulis program dosen", gpio_a > 50, 1'b1);
        check("Nilai LED kelipatan 3", last_gpio_a % 3, 0);

        section("A: unggah led_pattern ke ROM");
        uart_clear;
        uart_send_frame(MAGIC_ROM, n_a, 0, 8'h00);
        wait_cycles(10);
        ok = 1;
        for (i = 0; i < n_a; i = i + 1)
            if (uut_a.u3.mem[i] !== {frame_bytes[4*i+3], frame_bytes[4*i+2], frame_bytes[4*i+1], frame_bytes[4*i]}) ok = 0;
        check("Isi ROM = led_pattern", ok, 1);
        check("CPU sempat ditahan selama unggah", hold_a > 1000, 1'b1);
        check("loader_error = 0", err_a, 1'b0);
        check("loader_busy = 0", busy_a, 1'b0);
        wait_text({"LED_PATTERN", 16'h0D0A}, 13);
        check("CPU menjalankan program baru (UART)", uart_text[103:0], {"LED_PATTERN", 16'h0D0A});
        g = gpio_a;
        while (gpio_a < g + 2) wait_cycles(100);
        check("LED pola baru (penanda 0x0A00)", last_gpio_a[12:0], 13'h0A00);
        check("trap = 0", trap_a, 1'b0);

        section("A: checksum salah");
        wait_cycles(DIV * 30);
        uart_send_frame(MAGIC_ROM, n_a, 0, 8'h5A);
        wait_cycles(10);
        check("loader_error = 1", err_a, 1'b1);
        g = gpio_a;
        wait_cycles(20000);
        check("CPU tetap ditahan (LED tidak ditulis)", gpio_a, g);

        section("A: unggah ulang memulihkan");
        uart_send_frame(MAGIC_ROM, n_a, 0, 8'h00);
        wait_cycles(10);
        check("loader_error = 0", err_a, 1'b0);
        g = gpio_a;
        while (gpio_a < g + 1) wait_cycles(100);
        check("CPU jalan lagi", gpio_a > g, 1'b1);

        // ---------------------------------------------------------------
        section("B: bootloader");
        sel_b = 1'b1;
        uart_clear;
        rst_n = 1'b0;
        wait_cycles(5);
        rst_n = 1'b1;
        wait_text({"BOOT", 16'h0D0A}, 6);
        check("Bootloader mengirim BOOT", uart_text[47:0], {"BOOT", 16'h0D0A});
        wait_cycles(5000);
        check("LED berkedip saat menunggu", gpio_b > 0, 1'b1);

        section("B: checksum salah");
        uart_send_frame(MAGIC_RAM, n_b, B_OFS, 8'h33);
        wait_text({"ER", 16'h0D0A}, 4);
        check("Bootloader menjawab ER", uart_text[31:0], {"ER", 16'h0D0A});
        check("Loader hardware tidak terpicu", err_b | busy_b | !uut_b.sys_rst_n, 1'b0);

        section("B: unggah led_pattern_ram ke RAM");
        uart_clear;
        uart_send_frame(MAGIC_RAM, n_b, B_OFS, 8'h00);
        wait_text({"OK", 16'h0D0A}, 4);
        check("Bootloader menjawab OK", uart_text[31:0], {"OK", 16'h0D0A});
        ok = 1;
        for (i = 0; i < n_b; i = i + 1)
            if (uut_b.u4.mem[i] !== {frame_bytes[B_OFS+4*i+3], frame_bytes[B_OFS+4*i+2], frame_bytes[B_OFS+4*i+1], frame_bytes[B_OFS+4*i]}) ok = 0;
        check("Isi RAM = led_pattern_ram", ok, 1);
        wait_text({"LED_PATTERN", 16'h0D0A}, 13);
        check("Program RAM berjalan (UART)", uart_text[103:0], {"LED_PATTERN", 16'h0D0A});
        g = gpio_b;
        while (gpio_b < g + 2) wait_cycles(100);
        check("LED pola baru (penanda 0x0A00)", last_gpio_b[12:0], 13'h0A00);
        check("Instruksi diambil dari RAM", ram_fetch_b > 100, 1'b1);
        check("UART tidak pernah overrun", overrun_b, 0);
        check("trap = 0", trap_b, 1'b0);

        finish_tb;
    end

    initial begin
        #200000000;
        $display("TIMEOUT"); errors = errors + 1;
        finish_tb;
    end

endmodule
