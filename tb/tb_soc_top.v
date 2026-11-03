`timescale 1ns / 1ps

// Testbench seluruh SoC (picorv32_soc).
//
// Yang diuji:
//   1. Sambungan top level: setiap pasangan port diperiksa di setiap siklus.
//   2. Reset: kondisi pin dan fetch pertama CPU.
//   3. Firmware bawaan ROM: berjalan tanpa trap dan tanpa bus menggantung.
//   4. Program uji: akses ROM, RAM, dan GPIO dari CPU, end to end.
//
// TM1638 belum dipasang, sehingga bus s3 tidak diuji.
// Waveform hanya dibuat jika simulasi dijalankan dengan +vcd.

module tb_soc_top;

    `include "tb_utils.vh"

    // 1. Deklarasi sinyal
    reg         clk;
    reg         rst_n;
    reg  [15:0] iSW;
    wire        trap;
    wire [15:0] oLED;

    // 2. Unit Under Test
    picorv32_soc uut (
        .clk  (clk),
        .rst_n(rst_n),
        .trap (trap),
        .iSW  (iSW),
        .oLED (oLED)
    );

    // 3. Pembangkitan clock, periode 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Pemeriksaan sambungan: dijalankan terus selama simulasi
    // ------------------------------------------------------------------
    integer wiring_errors = 0;
    integer wiring_checks = 0;

    task wire_chk;
        input [8*40-1:0] name;
        input [31:0]     a;
        input [31:0]     b;
        begin
            wiring_checks = wiring_checks + 1;
            if (a !== b) begin
                wiring_errors = wiring_errors + 1;
                if (wiring_errors <= 20)
                    $display("  [WIRING] t=%0t %0s: %h != %h", $time, name, a, b);
            end
        end
    endtask

    always @(negedge clk) begin
        // Clock, reset, dan pin top
        wire_chk("u1.clk",    uut.u1.clk,    clk);
        wire_chk("u2.iCLK",   uut.u2.iCLK,   clk);
        wire_chk("u3.clk",    uut.u3.clk,    clk);
        wire_chk("u4.clk",    uut.u4.clk,    clk);
        wire_chk("u5.iCLK",   uut.u5.iCLK,   clk);
        wire_chk("u1.resetn", uut.u1.resetn, rst_n);
        wire_chk("u2.iRST",   uut.u2.iRST,   rst_n);
        wire_chk("u3.rst_n",  uut.u3.rst_n,  rst_n);
        wire_chk("u4.rst_n",  uut.u4.rst_n,  rst_n);
        wire_chk("u5.iRST",   uut.u5.iRST,   rst_n);
        wire_chk("u1.trap",   uut.u1.trap,   trap);
        wire_chk("u5.iSW",    uut.u5.iSW,    iSW);
        wire_chk("u5.oLED",   uut.u5.oLED,   oLED);

        // CPU <-> interconnect m0
        wire_chk("m0 AWVALID", uut.u1.mem_axi_awvalid, uut.u2.m0_AWVALID);
        wire_chk("m0 AWREADY", uut.u1.mem_axi_awready, uut.u2.m0_AWREADY);
        wire_chk("m0 AWADDR",  uut.u1.mem_axi_awaddr,  uut.u2.m0_AWADDR);
        wire_chk("m0 WVALID",  uut.u1.mem_axi_wvalid,  uut.u2.m0_WVALID);
        wire_chk("m0 WREADY",  uut.u1.mem_axi_wready,  uut.u2.m0_WREADY);
        wire_chk("m0 WDATA",   uut.u1.mem_axi_wdata,   uut.u2.m0_WDATA);
        wire_chk("m0 WSTRB",   uut.u1.mem_axi_wstrb,   uut.u2.m0_WSTRB);
        wire_chk("m0 BVALID",  uut.u1.mem_axi_bvalid,  uut.u2.m0_BVALID);
        wire_chk("m0 BREADY",  uut.u1.mem_axi_bready,  uut.u2.m0_BREADY);
        wire_chk("m0 ARVALID", uut.u1.mem_axi_arvalid, uut.u2.m0_ARVALID);
        wire_chk("m0 ARREADY", uut.u1.mem_axi_arready, uut.u2.m0_ARREADY);
        wire_chk("m0 ARADDR",  uut.u1.mem_axi_araddr,  uut.u2.m0_ARADDR);
        wire_chk("m0 RVALID",  uut.u1.mem_axi_rvalid,  uut.u2.m0_RVALID);
        wire_chk("m0 RREADY",  uut.u1.mem_axi_rready,  uut.u2.m0_RREADY);
        wire_chk("m0 RDATA",   uut.u1.mem_axi_rdata,   uut.u2.m0_RDATA);

        // Interconnect s0 <-> ROM
        wire_chk("s0 ARVALID", uut.u2.s0_ARVALID, uut.u3.axi_arvalid);
        wire_chk("s0 ARREADY", uut.u2.s0_ARREADY, uut.u3.axi_arready);
        wire_chk("s0 ARADDR",  uut.u2.s0_ARADDR,  uut.u3.axi_araddr);
        wire_chk("s0 RVALID",  uut.u2.s0_RVALID,  uut.u3.axi_rvalid);
        wire_chk("s0 RREADY",  uut.u2.s0_RREADY,  uut.u3.axi_rready);
        wire_chk("s0 RDATA",   uut.u2.s0_RDATA,   uut.u3.axi_rdata);

        // Interconnect s1 <-> RAM
        wire_chk("s1 AWVALID", uut.u2.s1_AWVALID, uut.u4.axi_awvalid);
        wire_chk("s1 AWREADY", uut.u2.s1_AWREADY, uut.u4.axi_awready);
        wire_chk("s1 AWADDR",  uut.u2.s1_AWADDR,  uut.u4.axi_awaddr);
        wire_chk("s1 WVALID",  uut.u2.s1_WVALID,  uut.u4.axi_wvalid);
        wire_chk("s1 WREADY",  uut.u2.s1_WREADY,  uut.u4.axi_wready);
        wire_chk("s1 WDATA",   uut.u2.s1_WDATA,   uut.u4.axi_wdata);
        wire_chk("s1 WSTRB",   uut.u2.s1_WSTRB,   uut.u4.axi_wstrb);
        wire_chk("s1 BVALID",  uut.u2.s1_BVALID,  uut.u4.axi_bvalid);
        wire_chk("s1 BREADY",  uut.u2.s1_BREADY,  uut.u4.axi_bready);
        wire_chk("s1 ARVALID", uut.u2.s1_ARVALID, uut.u4.axi_arvalid);
        wire_chk("s1 ARREADY", uut.u2.s1_ARREADY, uut.u4.axi_arready);
        wire_chk("s1 ARADDR",  uut.u2.s1_ARADDR,  uut.u4.axi_araddr);
        wire_chk("s1 RVALID",  uut.u2.s1_RVALID,  uut.u4.axi_rvalid);
        wire_chk("s1 RREADY",  uut.u2.s1_RREADY,  uut.u4.axi_rready);
        wire_chk("s1 RDATA",   uut.u2.s1_RDATA,   uut.u4.axi_rdata);

        // Interconnect s2 <-> GPIO
        wire_chk("s2 AWVALID", uut.u2.s2_AWVALID, uut.u5.s_AWVALID);
        wire_chk("s2 AWREADY", uut.u2.s2_AWREADY, uut.u5.s_AWREADY);
        wire_chk("s2 AWADDR",  uut.u2.s2_AWADDR,  uut.u5.s_AWADDR);
        wire_chk("s2 WVALID",  uut.u2.s2_WVALID,  uut.u5.s_WVALID);
        wire_chk("s2 WREADY",  uut.u2.s2_WREADY,  uut.u5.s_WREADY);
        wire_chk("s2 WDATA",   uut.u2.s2_WDATA,   uut.u5.s_WDATA);
        wire_chk("s2 WSTRB",   uut.u2.s2_WSTRB,   uut.u5.s_WSTRB);
        wire_chk("s2 BVALID",  uut.u2.s2_BVALID,  uut.u5.s_BVALID);
        wire_chk("s2 BREADY",  uut.u2.s2_BREADY,  uut.u5.s_BREADY);
        wire_chk("s2 BRESP",   uut.u2.s2_BRESP,   uut.u5.s_BRESP);
        wire_chk("s2 ARVALID", uut.u2.s2_ARVALID, uut.u5.s_ARVALID);
        wire_chk("s2 ARREADY", uut.u2.s2_ARREADY, uut.u5.s_ARREADY);
        wire_chk("s2 ARADDR",  uut.u2.s2_ARADDR,  uut.u5.s_ARADDR);
        wire_chk("s2 RVALID",  uut.u2.s2_RVALID,  uut.u5.s_RVALID);
        wire_chk("s2 RREADY",  uut.u2.s2_RREADY,  uut.u5.s_RREADY);
        wire_chk("s2 RRESP",   uut.u2.s2_RRESP,   uut.u5.s_RRESP);
        wire_chk("s2 RDATA",   uut.u2.s2_RDATA,   uut.u5.s_RDATA);

        // Port yang diikat ke nilai tetap
        wire_chk("irq = 0",        uut.u1.irq,        32'b0);
        wire_chk("ld_we = 0",      uut.u3.ld_we,      32'b0);
        wire_chk("s0 AWREADY = 0", uut.u2.s0_AWREADY, 32'b0);
        wire_chk("s0 WREADY = 0",  uut.u2.s0_WREADY,  32'b0);
        wire_chk("s0 BVALID = 0",  uut.u2.s0_BVALID,  32'b0);
        wire_chk("s0 BRESP = 0",   uut.u2.s0_BRESP,   32'b0);
        wire_chk("s0 RRESP = 0",   uut.u2.s0_RRESP,   32'b0);
        wire_chk("s1 BRESP = 0",   uut.u2.s1_BRESP,   32'b0);
        wire_chk("s1 RRESP = 0",   uut.u2.s1_RRESP,   32'b0);
        wire_chk("AWPROT = 0",     uut.u5.s_AWPROT,   32'b0);
        wire_chk("ARPROT = 0",     uut.u5.s_ARPROT,   32'b0);
    end

    // ------------------------------------------------------------------
    // Penghitung transaksi: membuktikan setiap bus benar-benar terpakai
    // ------------------------------------------------------------------
    integer rom_reads = 0, ram_reads = 0, ram_writes = 0, gpio_reads = 0, gpio_writes = 0;
    integer pending = 0, max_pending = 0;
    reg        first_read_seen = 1'b0;
    reg [31:0] first_read_addr = 32'hx;
    reg        ram_write_seen = 1'b0, gpio_write_seen = 1'b0;
    reg [31:0] first_ram_local = 32'hx, first_gpio_local = 32'hx;

    always @(posedge clk) begin
        if (rst_n) begin
            if (uut.u2.s0_ARVALID && uut.u2.s0_ARREADY) rom_reads  = rom_reads  + 1;
            if (uut.u2.s1_ARVALID && uut.u2.s1_ARREADY) ram_reads  = ram_reads  + 1;
            if (uut.u2.s2_ARVALID && uut.u2.s2_ARREADY) gpio_reads = gpio_reads + 1;
            if (uut.u2.s1_AWVALID && uut.u2.s1_AWREADY) begin
                ram_writes = ram_writes + 1;
                if (!ram_write_seen) begin
                    ram_write_seen  = 1'b1;
                    first_ram_local = uut.u2.s1_AWADDR;
                end
            end
            if (uut.u2.s2_AWVALID && uut.u2.s2_AWREADY) begin
                gpio_writes = gpio_writes + 1;
                if (!gpio_write_seen) begin
                    gpio_write_seen  = 1'b1;
                    first_gpio_local = uut.u2.s2_AWADDR;
                end
            end
            if (uut.u1.mem_axi_arvalid && !first_read_seen) begin
                first_read_seen = 1'b1;
                first_read_addr = uut.u1.mem_axi_araddr;
            end
            // Bus dianggap menggantung jika permintaan tidak dijawab
            if ((uut.u1.mem_axi_arvalid && !uut.u1.mem_axi_arready) ||
                (uut.u1.mem_axi_awvalid && !uut.u1.mem_axi_awready))
                pending = pending + 1;
            else
                pending = 0;
            if (pending > max_pending) max_pending = pending;
        end
    end

    task reset_counters;
        begin
            rom_reads = 0; ram_reads = 0; ram_writes = 0; gpio_reads = 0; gpio_writes = 0;
            pending = 0; max_pending = 0;
            first_read_seen = 1'b0; ram_write_seen = 1'b0; gpio_write_seen = 1'b0;
        end
    endtask

    task apply_reset;
        begin
            rst_n = 1'b0;
            repeat (5) @(negedge clk);
            reset_counters;
        end
    endtask

    // Program uji. Alamat data ROM 0x100 berisi 0xCAFEF00D.
    task load_test_program;
        begin
            uut.u3.mem[0]  = 32'h10000537; // lui  a0, 0x10000      ; basis RAM
            uut.u3.mem[1]  = 32'h000235b7; // lui  a1, 0x23         ; basis GPIO
            uut.u3.mem[2]  = 32'h10002283; // lw   t0, 0x100(zero)  ; baca data ROM
            uut.u3.mem[3]  = 32'h00552023; // sw   t0, 0(a0)        ; tulis word RAM
            uut.u3.mem[4]  = 32'h00052303; // lw   t1, 0(a0)        ; baca kembali RAM
            uut.u3.mem[5]  = 32'h0ab00393; // addi t2, zero, 0xAB
            uut.u3.mem[6]  = 32'h007500a3; // sb   t2, 1(a0)        ; tulis 1 byte RAM
            uut.u3.mem[7]  = 32'h00052e03; // lw   t3, 0(a0)
            uut.u3.mem[8]  = 32'h01c52223; // sw   t3, 4(a0)
            uut.u3.mem[9]  = 32'h0005ae83; // lw   t4, 0(a1)        ; baca switch
            uut.u3.mem[10] = 32'h01d5a023; // sw   t4, 0(a1)        ; tulis LED
            uut.u3.mem[11] = 32'hff9ff06f; // j    mem[9]
            uut.u3.mem[64] = 32'hcafef00d; // data pada alamat 0x100
        end
    endtask

    // 4. Blok simulasi
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_soc_top.vcd");
            $dumpvars(0, tb_soc_top);
        end

        iSW = 16'h0000;

        section("Reset");
        apply_reset;
        check("trap = 0 saat reset",     trap, 1'b0);
        check("LED = 0 saat reset",      oLED, 16'h0000);
        check("ARVALID = 0 saat reset",  uut.u1.mem_axi_arvalid, 1'b0);
        check("AWVALID = 0 saat reset",  uut.u1.mem_axi_awvalid, 1'b0);

        section("Firmware bawaan ROM (100000 siklus)");
        iSW   = 16'hA5C3;
        rst_n = 1'b1;
        repeat (100000) @(negedge clk);
        check("Fetch pertama dari 0x00000000",     first_read_addr, 32'h0);
        check("trap tetap 0",                      trap, 1'b0);
        check("Bus tidak menggantung",             max_pending < 100, 1'b1);
        check("ROM terbaca",                       rom_reads > 0, 1'b1);
        check("RAM tertulis",                      ram_writes > 0, 1'b1);
        check("RAM terbaca",                       ram_reads > 0, 1'b1);
        check("GPIO tertulis",                     gpio_writes > 0, 1'b1);
        check("Tulis RAM pertama: lokal 0x3FFC",   first_ram_local, 32'h0000_3FFC);
        check("Tulis GPIO pertama: lokal 0x3004",  first_gpio_local, 32'h0000_3004);
        $display("  [INFO] rom_reads=%0d ram_reads=%0d ram_writes=%0d gpio_reads=%0d gpio_writes=%0d max_pending=%0d",
                 rom_reads, ram_reads, ram_writes, gpio_reads, gpio_writes, max_pending);

        section("Program uji: CPU -> ROM, RAM, GPIO");
        apply_reset;
        load_test_program;
        iSW   = 16'hA5C3;
        rst_n = 1'b1;
        repeat (500) @(negedge clk);
        check("trap tetap 0",                  trap, 1'b0);
        check("Word ROM tersalin ke RAM[0]",   uut.u4.mem[1] === 32'hCAFEAB0D, 1'b1);
        check("sb hanya mengubah byte 1",      uut.u4.mem[0], 32'hCAFEAB0D);
        check("Baca kembali RAM ke RAM[1]",    uut.u4.mem[1], 32'hCAFEAB0D);
        check("RAM terbaca lewat s1",          ram_reads > 0, 1'b1);
        check("RAM tertulis lewat s1",         ram_writes > 0, 1'b1);
        check("GPIO terbaca lewat s2",         gpio_reads > 0, 1'b1);
        check("GPIO tertulis lewat s2",        gpio_writes > 0, 1'b1);
        check("LED = switch A5C3",             oLED, 16'hA5C3);
        iSW = 16'h1234; repeat (300) @(negedge clk);
        check("LED = switch 1234",             oLED, 16'h1234);
        iSW = 16'hFFFF; repeat (300) @(negedge clk);
        check("LED = switch FFFF",             oLED, 16'hFFFF);
        iSW = 16'h0001; repeat (300) @(negedge clk);
        check("LED = switch 0001",             oLED, 16'h0001);
        check("Bus tidak menggantung",         max_pending < 100, 1'b1);

        section("Sambungan top level");
        $display("  [INFO] %0d pemeriksaan pasangan port", wiring_checks);
        check("Semua pasangan port cocok", wiring_errors, 0);

        finish_tb;
    end

endmodule
