`default_nettype wire

module picorv32_soc (
    input  wire           clk,
    input  wire           rst_n,
	output wire           trap,
	input  wire [15:0]    iSW,
	output wire [15:0]    oLED
    // tambahkan pin yang sesuai
);
// bus_picorv32: CPU <-> interconnect (m0)
wire        bus_picorv32_awvalid, bus_picorv32_awready;
wire [31:0] bus_picorv32_awaddr;
wire        bus_picorv32_wvalid, bus_picorv32_wready;
wire [31:0] bus_picorv32_wdata;
wire [ 3:0] bus_picorv32_wstrb;
wire        bus_picorv32_bvalid, bus_picorv32_bready;
wire [ 1:0] bus_picorv32_bresp;
wire        bus_picorv32_arvalid, bus_picorv32_arready;
wire [31:0] bus_picorv32_araddr;
wire        bus_picorv32_rvalid, bus_picorv32_rready;
wire [ 1:0] bus_picorv32_rresp;
wire [31:0] bus_picorv32_rdata;

// bus_rom: interconnect (s0) <-> ROM
wire        bus_rom_awvalid, bus_rom_awready;
wire [31:0] bus_rom_awaddr;
wire        bus_rom_wvalid, bus_rom_wready;
wire [31:0] bus_rom_wdata;
wire [ 3:0] bus_rom_wstrb;
wire        bus_rom_bvalid, bus_rom_bready;
wire [ 1:0] bus_rom_bresp;
wire        bus_rom_arvalid, bus_rom_arready;
wire [31:0] bus_rom_araddr;
wire        bus_rom_rvalid, bus_rom_rready;
wire [ 1:0] bus_rom_rresp;
wire [31:0] bus_rom_rdata;

// bus_ram1: interconnect (s1) <-> RAM
wire        bus_ram1_awvalid, bus_ram1_awready;
wire [31:0] bus_ram1_awaddr;
wire        bus_ram1_wvalid, bus_ram1_wready;
wire [31:0] bus_ram1_wdata;
wire [ 3:0] bus_ram1_wstrb;
wire        bus_ram1_bvalid, bus_ram1_bready;
wire [ 1:0] bus_ram1_bresp;
wire        bus_ram1_arvalid, bus_ram1_arready;
wire [31:0] bus_ram1_araddr;
wire        bus_ram1_rvalid, bus_ram1_rready;
wire [ 1:0] bus_ram1_rresp;
wire [31:0] bus_ram1_rdata;

// bus_gpio: interconnect (s2) <-> GPIO
wire        bus_gpio_awvalid, bus_gpio_awready;
wire [31:0] bus_gpio_awaddr;
wire        bus_gpio_wvalid, bus_gpio_wready;
wire [31:0] bus_gpio_wdata;
wire [ 3:0] bus_gpio_wstrb;
wire        bus_gpio_bvalid, bus_gpio_bready;
wire [ 1:0] bus_gpio_bresp;
wire        bus_gpio_arvalid, bus_gpio_arready;
wire [31:0] bus_gpio_araddr;
wire        bus_gpio_rvalid, bus_gpio_rready;
wire [ 1:0] bus_gpio_rresp;
wire [31:0] bus_gpio_rdata;

// bus_tm: interconnect (s3) <-> TM1638 Controller
wire        bus_tm_awvalid, bus_tm_awready;
wire [31:0] bus_tm_awaddr;
wire        bus_tm_wvalid, bus_tm_wready;
wire [31:0] bus_tm_wdata;
wire [ 3:0] bus_tm_wstrb;
wire        bus_tm_bvalid, bus_tm_bready;
wire [ 1:0] bus_tm_bresp;
wire        bus_tm_arvalid, bus_tm_arready;
wire [31:0] bus_tm_araddr;
wire        bus_tm_rvalid, bus_tm_rready;
wire [ 1:0] bus_tm_rresp;
wire [31:0] bus_tm_rdata;

// ROM tidak punya kanal tulis dan port respons, sehingga nilainya ditetapkan di sini
assign bus_rom_awready = 1'b0;
assign bus_rom_wready  = 1'b0;
assign bus_rom_bvalid  = 1'b0;
assign bus_rom_bresp   = 2'b00;
assign bus_rom_rresp   = 2'b00;

// RAM tidak punya port respons, sehingga selalu dianggap OKAY
assign bus_ram1_bresp  = 2'b00;
assign bus_ram1_rresp  = 2'b00;

picorv32_axi u1 (
	.clk(clk),
    .resetn(rst_n),
	.trap(trap),

	// AXI4-lite master memory interface
	.mem_axi_awvalid(bus_picorv32_awvalid),
	.mem_axi_awready(bus_picorv32_awready),
	.mem_axi_awaddr(bus_picorv32_awaddr),
	.mem_axi_awprot(),

	.mem_axi_wvalid(bus_picorv32_wvalid),
	.mem_axi_wready(bus_picorv32_wready),
	.mem_axi_wdata(bus_picorv32_wdata),
	.mem_axi_wstrb(bus_picorv32_wstrb),

	.mem_axi_bvalid(bus_picorv32_bvalid),
	.mem_axi_bready(bus_picorv32_bready),

	.mem_axi_arvalid(bus_picorv32_arvalid),
	.mem_axi_arready(bus_picorv32_arready),
	.mem_axi_araddr(bus_picorv32_araddr),
	.mem_axi_arprot(),

	.mem_axi_rvalid(bus_picorv32_rvalid),
	.mem_axi_rready(bus_picorv32_rready),
	.mem_axi_rdata(bus_picorv32_rdata),

	// IRQ interface
	.irq(32'b0),
	.eoi(),

	// Trace Interface
	.trace_valid(),
	.trace_data()
);
axi4_lite_interconnect_m1s4 #(
    // Firmware memakai RAM pada alamat 0x1000_0000
    .LOW_ADDR1(32'h1000_0000),
    .HIGH_ADDR1(32'h1000_FFFF)
) u2(
    .iCLK(clk),
    .iRST(rst_n),

    /* master interface 0 */
        /* write address channel */    
        .m0_AWVALID(bus_picorv32_awvalid),
        .m0_AWADDR(bus_picorv32_awaddr),
        .m0_AWREADY(bus_picorv32_awready),

        /* write data channel */    
        .m0_WVALID(bus_picorv32_wvalid),
        .m0_WSTRB(bus_picorv32_wstrb),
        .m0_WDATA(bus_picorv32_wdata),
        .m0_WREADY(bus_picorv32_wready),

        /* write response channel */    
        .m0_BREADY(bus_picorv32_bready),
        .m0_BVALID(bus_picorv32_bvalid),
        .m0_BRESP(bus_picorv32_bresp),

        /* read address channel */    
        .m0_ARVALID(bus_picorv32_arvalid),
        .m0_ARADDR(bus_picorv32_araddr),
        .m0_ARREADY(bus_picorv32_arready),

        /* read data channel */    
        .m0_RREADY(bus_picorv32_rready),
        .m0_RVALID(bus_picorv32_rvalid),
        .m0_RRESP(bus_picorv32_rresp),
        .m0_RDATA(bus_picorv32_rdata),

    /* slave interface 0 */
        /* write address channel */
        .s0_AWREADY(bus_rom_awready),
        .s0_AWVALID(bus_rom_awvalid),
        .s0_AWADDR(bus_rom_awaddr),

        /* write data channel */
        .s0_WREADY(bus_rom_wready),
        .s0_WVALID(bus_rom_wvalid),
        .s0_WSTRB(bus_rom_wstrb),
        .s0_WDATA(bus_rom_wdata),

        /* write response channel */
        .s0_BVALID(bus_rom_bvalid),
        .s0_BRESP(bus_rom_bresp),
        .s0_BREADY(bus_rom_bready),

        /* read address channel */
		.s0_ARREADY(bus_rom_arready),
        .s0_ARVALID(bus_rom_arvalid),
        .s0_ARADDR(bus_rom_araddr),

        /* read data channel */
        .s0_RVALID(bus_rom_rvalid),
        .s0_RRESP(bus_rom_rresp),
        .s0_RDATA(bus_rom_rdata),
        .s0_RREADY(bus_rom_rready),

    /* slave interface 1 */
        /* write address channel */
        .s1_AWREADY(bus_ram1_awready),
        .s1_AWVALID(bus_ram1_awvalid),
        .s1_AWADDR(bus_ram1_awaddr),

        /* write data channel */
        .s1_WREADY(bus_ram1_wready),
        .s1_WVALID(bus_ram1_wvalid),
        .s1_WSTRB(bus_ram1_wstrb),
        .s1_WDATA(bus_ram1_wdata),

        /* write response channel */
        .s1_BVALID(bus_ram1_bvalid),
        .s1_BRESP(bus_ram1_bresp),
        .s1_BREADY(bus_ram1_bready),

        /* read address channel */
        .s1_ARREADY(bus_ram1_arready),
        .s1_ARVALID(bus_ram1_arvalid),
        .s1_ARADDR(bus_ram1_araddr),

        /* read data channel */
        .s1_RVALID(bus_ram1_rvalid),
        .s1_RRESP(bus_ram1_rresp),
        .s1_RDATA(bus_ram1_rdata),
        .s1_RREADY(bus_ram1_rready),

    /* slave interface 2 */
        /* write address channel */
        .s2_AWREADY(bus_gpio_awready),
        .s2_AWVALID(bus_gpio_awvalid),
        .s2_AWADDR(bus_gpio_awaddr),

        /* write data channel */
        .s2_WREADY(bus_gpio_wready),
        .s2_WVALID(bus_gpio_wvalid),
        .s2_WSTRB(bus_gpio_wstrb),
        .s2_WDATA(bus_gpio_wdata),

        /* write response channel */
        .s2_BVALID(bus_gpio_bvalid),
        .s2_BRESP(bus_gpio_bresp),
        .s2_BREADY(bus_gpio_bready),

        /* read address channel */
        .s2_ARREADY(bus_gpio_arready),
        .s2_ARVALID(bus_gpio_arvalid),
        .s2_ARADDR(bus_gpio_araddr),

        /* read data channel */
        .s2_RVALID(bus_gpio_rvalid),
        .s2_RRESP(bus_gpio_rresp),
        .s2_RDATA(bus_gpio_rdata),
        .s2_RREADY(bus_gpio_rready),

    /* slave interface 3 */
        /* write address channel */
        .s3_AWREADY(bus_tm_awready),
        .s3_AWVALID(bus_tm_awvalid),
        .s3_AWADDR(bus_tm_awaddr),

        /* write data channel */
        .s3_WREADY(bus_tm_wready),
        .s3_WVALID(bus_tm_wvalid),
        .s3_WSTRB(bus_tm_wstrb),
        .s3_WDATA(bus_tm_wdata),

        /* write response channel */
        .s3_BVALID(bus_tm_bvalid),
        .s3_BRESP(bus_tm_bresp),
        .s3_BREADY(bus_tm_bready),

        /* read address channel */
        .s3_ARREADY(bus_tm_arready),
        .s3_ARVALID(bus_tm_arvalid),
        .s3_ARADDR(bus_tm_araddr),

        /* read data channel */
        .s3_RVALID(bus_tm_rvalid),
        .s3_RRESP(bus_tm_rresp),
        .s3_RDATA(bus_tm_rdata),
        .s3_RREADY(bus_tm_rready)
);
axi_rom u3(
    .clk(clk),
    .rst_n(rst_n),

    // AXI4-Lite Interface (Read-Only) -- Port A (CPU fetch/read)
    .axi_arvalid(bus_rom_arvalid),
    .axi_arready(bus_rom_arready),
    .axi_araddr(bus_rom_araddr),
    .axi_rvalid(bus_rom_rvalid),
    .axi_rready(bus_rom_rready),
    .axi_rdata(bus_rom_rdata),

    // Loader Interface -- Port B (SPI boot-loader writes new firmware here).
    // ld_addr is a WORD index. Used only while the CPU is held in reset.
    .ld_we(1'b0),
    .ld_addr(32'b0),
    .ld_data(32'b0)
);
axi_ram u4(
	.clk(clk),
    .rst_n(rst_n),
    // AXI4-Lite Interface (Read/Write)
    .axi_awvalid(bus_ram1_awvalid),
    .axi_awready(bus_ram1_awready),
    .axi_awaddr(bus_ram1_awaddr),
    .axi_wvalid(bus_ram1_wvalid),
    .axi_wready(bus_ram1_wready),
    .axi_wdata(bus_ram1_wdata),
    .axi_wstrb(bus_ram1_wstrb),
    .axi_bvalid(bus_ram1_bvalid),
    .axi_bready(bus_ram1_bready),
    .axi_arvalid(bus_ram1_arvalid),
    .axi_arready(bus_ram1_arready),
    .axi_araddr(bus_ram1_araddr),
    .axi_rvalid(bus_ram1_rvalid),
    .axi_rready(bus_ram1_rready),
    .axi_rdata(bus_ram1_rdata)
);
axi4_lite_gpio_wrapper u5(
    .iCLK(clk),
    .iRST(rst_n),

    .iSW(iSW),
    .oLED(oLED),
    
    /* write address channel */
    .s_AWVALID(bus_gpio_awvalid),
    .s_AWPROT(3'b000),
    .s_AWADDR(bus_gpio_awaddr),
    .s_AWREADY(bus_gpio_awready),
    
    /* write data channel */
    .s_WVALID(bus_gpio_wvalid),
    .s_WDATA(bus_gpio_wdata),
    .s_WSTRB(bus_gpio_wstrb),
    .s_WREADY(bus_gpio_wready),
    
    /* write response channel */
    .s_BREADY(bus_gpio_bready),
    .s_BVALID(bus_gpio_bvalid),
    .s_BRESP(bus_gpio_bresp),
    
    /* read address channel */
    .s_ARVALID(bus_gpio_arvalid),
    .s_ARPROT(3'b000),
    .s_ARADDR(bus_gpio_araddr),
    .s_ARREADY(bus_gpio_arready),
    
    /* read data channel */
    .s_RREADY(bus_gpio_rready),
    .s_RVALID(bus_gpio_rvalid),
    .s_RRESP(bus_gpio_rresp),
    .s_RDATA(bus_gpio_rdata)
);
// lanjutkan disini

endmodule