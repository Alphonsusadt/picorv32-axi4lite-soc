// SPI master universal sebagai slave AXI4-Lite.
//
// Dirancang agar bisa dipakai untuk TM1638 (LSB dulu, satu pin DIO dua arah,
// mode 3) maupun perangkat SPI biasa (flash, sensor, ADC, layar).
//
// Peta register (offset dari alamat dasar slot, akses 32 bit):
//   0x00 CTRL   R/W  bit0 EN, bit1 CPOL, bit2 CPHA, bit3 LSB_FIRST,
//                    bit4 THREE_WIRE, bit5 RX_EN (3-wire: DIO jadi input)
//   0x04 DIV    R/W  bit[15:0], f_SCK = f_clk / (2 * (DIV + 1))
//   0x08 CS     R/W  bit[1:0], 1 = chip select aktif (pin CS_N rendah)
//   0x0C DATA   W    tulis = kirim 1 byte (diabaikan saat BUSY atau EN = 0)
//               R    byte terakhir yang diterima
//   0x10 STATUS R    bit0 BUSY, bit1 RX_VALID (byte baru sejak transfer selesai)
//   0x14 ID     R    0x5350_4931 ("SPI1"), untuk memeriksa periferal terpasang
//
// Antarmuka AXI memakai axi4_lite_slave.v yang sama dengan GPIO.

module axi4_lite_spi #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input                               iCLK,
    input                               iRST,

    /* write address channel */
    input                               s_AWVALID,
    input       [2:0]                   s_AWPROT,
    input       [ADDR_WIDTH-1:0]        s_AWADDR,
    output                              s_AWREADY,

    /* write data channel */
    input                               s_WVALID,
    input       [DATA_WIDTH-1:0]        s_WDATA,
    input       [(DATA_WIDTH/8)-1:0]    s_WSTRB,
    output                              s_WREADY,

    /* write response channel */
    input                               s_BREADY,
    output                              s_BVALID,
    output      [1:0]                   s_BRESP,

    /* read address channel */
    input                               s_ARVALID,
    input       [2:0]                   s_ARPROT,
    input       [ADDR_WIDTH-1:0]        s_ARADDR,
    output                              s_ARREADY,

    /* read data channel */
    input                               s_RREADY,
    output                              s_RVALID,
    output      [1:0]                   s_RRESP,
    output      [DATA_WIDTH-1:0]        s_RDATA,

    /* pin SPI */
    output                              oSCK,
    output      [1:0]                   oCS_N,
    output                              oSDO,
    output                              oSDO_OE,
    input                               iSDI
);

    localparam REG_CTRL   = 3'd0;
    localparam REG_DIV    = 3'd1;
    localparam REG_CS     = 3'd2;
    localparam REG_DATA   = 3'd3;
    localparam REG_STATUS = 3'd4;
    localparam REG_ID     = 3'd5;

    localparam OKAY = 2'b00;

    /* antarmuka dari axi4_lite_slave */
    wire [ADDR_WIDTH-1:0]       write_addr;
    wire [DATA_WIDTH-1:0]       write_data;
    wire [(DATA_WIDTH/8)-1:0]   write_strb;
    wire [ADDR_WIDTH-1:0]       read_addr;
    reg  [DATA_WIDTH-1:0]       read_data;

    axi4_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
    ) axi_slave (
        .iCLK(iCLK), .iRST(iRST),

        .s_AWREADY(s_AWREADY), .s_AWVALID(s_AWVALID), .s_AWPROT(s_AWPROT), .s_AWADDR(s_AWADDR),
        .s_WREADY(s_WREADY), .s_WVALID(s_WVALID), .s_WDATA(s_WDATA), .s_WSTRB(s_WSTRB),
        .s_BVALID(s_BVALID), .s_BRESP(s_BRESP), .s_BREADY(s_BREADY),

        .s_ARREADY(s_ARREADY), .s_ARVALID(s_ARVALID), .s_ARPROT(s_ARPROT), .s_ARADDR(s_ARADDR),
        .s_RVALID(s_RVALID), .s_RRESP(s_RRESP), .s_RDATA(s_RDATA), .s_RREADY(s_RREADY),

        .write_addr(write_addr), .write_data(write_data), .write_strb(write_strb), .write_resp(OKAY),
        .read_addr(read_addr), .read_data(read_data), .read_resp(OKAY)
    );

    /* register */
    reg        ctrl_en, ctrl_cpol, ctrl_cpha, ctrl_lsb, ctrl_3w, ctrl_rx;
    reg [15:0] div;
    reg [1:0]  cs;
    reg        rx_valid;
    reg        start;
    reg [7:0]  tx_byte;

    wire       busy, done;
    wire [7:0] rx_byte;
    wire       core_sdo_oe;

    // axi4_lite_slave menyimpan alamat dan data pada siklus WREADY, sehingga
    // register ditulis satu siklus sesudahnya.
    reg write_pending;

    always @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            write_pending <= 1'b0;
            ctrl_en   <= 1'b0;
            ctrl_cpol <= 1'b0;
            ctrl_cpha <= 1'b0;
            ctrl_lsb  <= 1'b0;
            ctrl_3w   <= 1'b0;
            ctrl_rx   <= 1'b0;
            div       <= 16'd0;
            cs        <= 2'b00;
            rx_valid  <= 1'b0;
            start     <= 1'b0;
            tx_byte   <= 8'h00;
        end else begin
            write_pending <= s_WREADY;
            start         <= 1'b0;

            if (done) rx_valid <= 1'b1;

            if (write_pending) begin
                case (write_addr[4:2])
                    REG_CTRL: begin
                        ctrl_en   <= write_data[0];
                        ctrl_cpol <= write_data[1];
                        ctrl_cpha <= write_data[2];
                        ctrl_lsb  <= write_data[3];
                        ctrl_3w   <= write_data[4];
                        ctrl_rx   <= write_data[5];
                    end
                    REG_DIV:  div <= write_data[15:0];
                    REG_CS:   cs  <= write_data[1:0];
                    REG_DATA: begin
                        if (ctrl_en && !busy) begin
                            tx_byte  <= write_data[7:0];
                            start    <= 1'b1;
                            rx_valid <= 1'b0;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        case (read_addr[4:2])
            REG_CTRL:   read_data = {26'd0, ctrl_rx, ctrl_3w, ctrl_lsb, ctrl_cpha, ctrl_cpol, ctrl_en};
            REG_DIV:    read_data = {16'd0, div};
            REG_CS:     read_data = {30'd0, cs};
            REG_DATA:   read_data = {24'd0, rx_byte};
            // start ikut dihitung agar BUSY sudah 1 tepat setelah DATA ditulis
            REG_STATUS: read_data = {30'd0, rx_valid, busy | start};
            REG_ID:     read_data = 32'h5350_4931;
            default:    read_data = 32'd0;
        endcase
    end

    spi_core core (
        .clk(iCLK), .rst_n(iRST),
        .cpol(ctrl_cpol), .cpha(ctrl_cpha), .lsb_first(ctrl_lsb),
        .three_wire(ctrl_3w), .rx_en(ctrl_rx), .div(div),
        .start(start), .tx_byte(tx_byte),
        .busy(busy), .done(done), .rx_byte(rx_byte),
        .sck(oSCK), .sdo(oSDO), .sdo_oe(core_sdo_oe), .sdi(iSDI)
    );

    assign oCS_N   = ~cs;
    assign oSDO_OE = ctrl_en & core_sdo_oe;

endmodule
