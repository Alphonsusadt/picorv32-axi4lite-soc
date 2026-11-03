`timescale 1ns / 1ps

// Testbench blok CPU (picorv32_axi) dengan model memori AXI4-Lite.

module tb_picorv32_axi;

    `include "tb_utils.vh"

    reg         clk, resetn;
    wire        trap;
    wire        awvalid, wvalid, bready, arvalid, rready;
    wire [31:0] awaddr, wdata, araddr;
    wire [ 3:0] wstrb;
    wire [ 2:0] awprot, arprot;
    reg         bvalid, rvalid;
    reg  [31:0] rdata;
    wire        awready, wready, arready;

    picorv32_axi uut (
        .clk(clk), .resetn(resetn), .trap(trap),
        .mem_axi_awvalid(awvalid), .mem_axi_awready(awready), .mem_axi_awaddr(awaddr), .mem_axi_awprot(awprot),
        .mem_axi_wvalid(wvalid), .mem_axi_wready(wready), .mem_axi_wdata(wdata), .mem_axi_wstrb(wstrb),
        .mem_axi_bvalid(bvalid), .mem_axi_bready(bready),
        .mem_axi_arvalid(arvalid), .mem_axi_arready(arready), .mem_axi_araddr(araddr), .mem_axi_arprot(arprot),
        .mem_axi_rvalid(rvalid), .mem_axi_rready(rready), .mem_axi_rdata(rdata),
        .irq(32'b0), .eoi(),
        .trace_valid(), .trace_data()
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Model memori
    reg [31:0] mem [0:1023];
    integer    i;

    assign awready = awvalid && wvalid && !bvalid;
    assign wready  = awready;
    assign arready = arvalid && !rvalid;

    integer    reads, writes;
    reg        first_seen;
    reg [31:0] first_addr;
    reg [ 2:0] first_prot;
    reg [ 2:0] data_read_prot;
    reg [ 3:0] last_wstrb;
    reg [31:0] last_wdata, last_waddr;

    always @(posedge clk) begin
        if (!resetn) begin
            bvalid <= 1'b0;
            rvalid <= 1'b0;
        end else begin
            if (awready) begin
                writes     <= writes + 1;
                last_wstrb <= wstrb;
                last_wdata <= wdata;
                last_waddr <= awaddr;
                if (wstrb[0]) mem[awaddr[11:2]][ 7: 0] <= wdata[ 7: 0];
                if (wstrb[1]) mem[awaddr[11:2]][15: 8] <= wdata[15: 8];
                if (wstrb[2]) mem[awaddr[11:2]][23:16] <= wdata[23:16];
                if (wstrb[3]) mem[awaddr[11:2]][31:24] <= wdata[31:24];
                bvalid <= 1'b1;
            end else if (bready) bvalid <= 1'b0;

            if (arready) begin
                reads <= reads + 1;
                if (!first_seen) begin
                    first_seen <= 1'b1;
                    first_addr <= araddr;
                    first_prot <= arprot;
                end
                if (araddr == 32'h0000_0100) data_read_prot <= arprot;
                rdata  <= mem[araddr[11:2]];
                rvalid <= 1'b1;
            end else if (rready) rvalid <= 1'b0;
        end
    end

    task start_program;
        begin
            @(negedge clk);
            resetn = 1'b0;
            for (i = 0; i < 1024; i = i + 1) mem[i] = 32'h0;
            reads = 0; writes = 0; first_seen = 1'b0;
        end
    endtask

    task run_program;
        input integer max_cycles;
        integer t;
        begin
            repeat (5) @(negedge clk);
            resetn = 1'b1;
            t = 0;
            while (!trap && t < max_cycles) begin @(negedge clk); t = t + 1; end
        end
    endtask

    integer reads_at_trap, writes_at_trap;

    initial begin
        $dumpfile("tb_picorv32_axi.vcd");
        $dumpvars(0, tb_picorv32_axi);

        resetn = 1'b0; bvalid = 1'b0; rvalid = 1'b0; rdata = 32'h0;
        reads = 0; writes = 0; first_seen = 1'b0;

        section("Program dasar: aritmetika, load, store");
        start_program;
        mem[0] = 32'h00500093; // addi x1, x0, 5
        mem[1] = 32'h00700113; // addi x2, x0, 7
        mem[2] = 32'h002081b3; // add  x3, x1, x2
        mem[3] = 32'h10302023; // sw   x3, 0x100(x0)
        mem[4] = 32'h10002203; // lw   x4, 0x100(x0)
        mem[5] = 32'h10402223; // sw   x4, 0x104(x0)
        mem[6] = 32'h101004a3; // sb   x1, 0x109(x0)
        mem[7] = 32'h00100073; // ebreak
        run_program(2000);
        check("Fetch pertama dari 0x00000000", first_addr, 32'h0);
        check("ARPROT fetch = instruksi",      first_prot, 3'b100);
        check("ARPROT baca data = data",       data_read_prot, 3'b000);
        check("add dan sw: mem[0x100] = 12",   mem[64], 32'd12);
        check("lw dan sw: mem[0x104] = 12",    mem[65], 32'd12);
        check("sb hanya mengubah byte 1",      mem[66], 32'h0000_0500);
        check("Alamat tulis sb sejajar word",  last_waddr, 32'h0000_0108);
        check("WSTRB sb = 0010",               last_wstrb, 4'b0010);
        check("Tiga kali tulis",               writes, 3);

        section("Trap: ebreak");
        check("trap = 1", trap, 1'b1);
        reads_at_trap = reads; writes_at_trap = writes;
        repeat (50) @(negedge clk);
        check("Tidak ada baca setelah trap",  reads,  reads_at_trap);
        check("Tidak ada tulis setelah trap", writes, writes_at_trap);

        section("Reset melepas trap");
        start_program;
        mem[0] = 32'h00500093; // addi x1, x0, 5
        mem[1] = 32'h0000006f; // j .
        repeat (5) @(negedge clk);
        check("trap = 0 saat reset", trap, 1'b0);
        run_program(200);
        check("trap tetap 0 saat program berputar", trap, 1'b0);

        section("Trap: instruksi tidak dikenal");
        start_program;
        mem[0] = 32'hffffffff;
        run_program(200);
        check("trap = 1", trap, 1'b1);

        section("Trap: akses tidak sejajar");
        start_program;
        mem[0] = 32'h00102083; // lw x1, 1(x0)
        run_program(200);
        check("trap = 1", trap, 1'b1);

        finish_tb;
    end

endmodule
