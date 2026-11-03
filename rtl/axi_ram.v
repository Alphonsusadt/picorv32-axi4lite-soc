module axi_ram (
    input         clk,
    input         rst_n,
    // AXI4-Lite Interface (Read/Write)
    input         axi_awvalid,
    output        axi_awready,
    input  [31:0] axi_awaddr,
    input         axi_wvalid,
    output        axi_wready,
    input  [31:0] axi_wdata,
    input  [3:0]  axi_wstrb,
    output        axi_bvalid,
    input         axi_bready,
    input         axi_arvalid,
    output        axi_arready,
    input  [31:0] axi_araddr,
    output        axi_rvalid,
    input         axi_rready,
    output [31:0] axi_rdata
);

    // 16 KB RAM (4096 word x 32-bit).
    // PENTING: baca dibuat SINKRON (ter-register) -> Vivado infer Block RAM,
    // bukan flip-flop. Ini yang memperbaiki over-utilization di XC7A35T.
    // Isi RAM tidak di-reset (BRAM tak bisa di-clear via reset; lagipula
    // boot.S/ram_init.c sudah menol-kan .bss dan menyalin .data).
    reg [31:0] mem [0:4095];

    reg [1:0]  state;
    reg [31:0] rdata_r;      // registered read data -> kunci inferensi BRAM

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= 2'd0;
        end else begin
            case (state)
                0: begin  // Idle
                    if (axi_awvalid && axi_wvalid) begin            // Write request
                        if (axi_wstrb[0]) mem[axi_awaddr[13:2]][7:0]   <= axi_wdata[7:0];
                        if (axi_wstrb[1]) mem[axi_awaddr[13:2]][15:8]  <= axi_wdata[15:8];
                        if (axi_wstrb[2]) mem[axi_awaddr[13:2]][23:16] <= axi_wdata[23:16];
                        if (axi_wstrb[3]) mem[axi_awaddr[13:2]][31:24] <= axi_wdata[31:24];
                        state <= 2'd1;
                    end else if (axi_arvalid) begin                 // Read request
                        rdata_r <= mem[axi_araddr[13:2]];           // baca sinkron (BRAM)
                        state   <= 2'd2;
                    end
                end
                1: begin  // Write response
                    if (axi_bready) state <= 2'd0;
                end
                2: begin  // Read response
                    if (axi_rready) state <= 2'd0;
                end
                default: state <= 2'd0;
            endcase
        end
    end

    assign axi_awready = (state == 2'd0);
    assign axi_wready  = (state == 2'd0);
    assign axi_bvalid  = (state == 2'd1);
    assign axi_arready = (state == 2'd0);
    assign axi_rvalid  = (state == 2'd2);
    assign axi_rdata   = rdata_r;

endmodule
