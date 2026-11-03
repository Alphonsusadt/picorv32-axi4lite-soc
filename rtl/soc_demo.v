`default_nettype wire

module picorv32_soc (
    input  wire           clk,
    input  wire           rst_n
    // tambahkan pin yang sesuai
);

picorv32_axi u1 (
	.clk(clk),
    .resetn(rst_n),
	.trap(),

	// AXI4-lite master memory interface
	.mem_axi_awvalid(),
	.mem_axi_awready(),
	.mem_axi_awaddr(),
	.mem_axi_awprot(),

	.mem_axi_wvalid(),
	.mem_axi_wready(),
	.mem_axi_wdata(),
	.mem_axi_wstrb(),

	.mem_axi_bvalid(),
	.mem_axi_bready(),

	.mem_axi_arvalid(),
	.mem_axi_arready(),
	.mem_axi_araddr(),
	.mem_axi_arprot(),

	.mem_axi_rvalid(),
	.mem_axi_rready(),
	.mem_axi_rdata(),

	// IRQ interface
	.irq(),
	.eoi(),

	// Trace Interface
	.trace_valid(),
	.trace_data()
);
axi_ram u2(
	.clk(clk),
    .rst_n(rst_n),
    // AXI4-Lite Interface (Read/Write)
    .axi_awvalid(axi_awvalid),
    .axi_awready(axi_awready),
    .axi_awaddr(axi_awaddr),
    .axi_wvalid(axi_wvalid),
    .axi_wready(axi_wready),
    .axi_wdata(axi_wdata),
    .axi_wstrb(axi_wstrb),
    .axi_bvalid(axi_bvalid),
    .axi_bready(axi_bready),
    .axi_arvalid(axi_arvalid),
    .axi_arready(axi_arready),
    .axi_araddr(axi_araddr),
    .axi_rvalid(axi_rvalid),
    .axi_rready(axi_rready),
    .axi_rdata(axi_rdata)
);

// lanjutkan disini

endmodule