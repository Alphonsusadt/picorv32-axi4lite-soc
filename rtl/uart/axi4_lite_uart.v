// UART 8N1 sebagai slave AXI4-Lite (dipakai bootloader skenario B).
//
// Peta register (offset dari alamat dasar, akses 32 bit):
//   0x00 DATA   W  kirim 1 byte (diabaikan saat TX_BUSY)
//               R  byte terakhir yang diterima; membaca DATA menghapus RX_VALID
//   0x04 STATUS R  bit0 TX_BUSY, bit1 RX_VALID, bit2 RX_OVERRUN (byte hilang
//                  karena DATA belum dibaca), bit3 FRAME_ERROR
//                  Membaca STATUS menghapus RX_OVERRUN dan FRAME_ERROR.
//   0x08 DIV    RW clks_per_bit = f_clk / baud. Nilai reset = DEFAULT_DIV
//   0x0C ID     R  0x5541_5231 ("UAR1")

module axi4_lite_uart #(
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32,
    parameter DEFAULT_DIV = 16'd78
) (
    input                               iCLK,
    input                               iRST,

    input                               s_AWVALID,
    input       [2:0]                   s_AWPROT,
    input       [ADDR_WIDTH-1:0]        s_AWADDR,
    output                              s_AWREADY,
    input                               s_WVALID,
    input       [DATA_WIDTH-1:0]        s_WDATA,
    input       [(DATA_WIDTH/8)-1:0]    s_WSTRB,
    output                              s_WREADY,
    input                               s_BREADY,
    output                              s_BVALID,
    output      [1:0]                   s_BRESP,
    input                               s_ARVALID,
    input       [2:0]                   s_ARPROT,
    input       [ADDR_WIDTH-1:0]        s_ARADDR,
    output                              s_ARREADY,
    input                               s_RREADY,
    output                              s_RVALID,
    output      [1:0]                   s_RRESP,
    output      [DATA_WIDTH-1:0]        s_RDATA,

    input                               iRX,
    output                              oTX
);

    localparam REG_DATA = 2'd0, REG_STATUS = 2'd1, REG_DIV = 2'd2, REG_ID = 2'd3;
    localparam OKAY = 2'b00;

    wire [ADDR_WIDTH-1:0]     write_addr;
    wire [DATA_WIDTH-1:0]     write_data;
    wire [(DATA_WIDTH/8)-1:0] write_strb;
    wire [ADDR_WIDTH-1:0]     read_addr;
    reg  [DATA_WIDTH-1:0]     read_data;

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

    reg [15:0] div;
    reg        tx_start;
    reg [7:0]  tx_byte;
    reg        rx_valid, rx_overrun, rx_ferr;
    reg [7:0]  rx_data;
    reg        write_pending;

    wire       tx_busy;
    wire       rx_strobe, rx_frame_error;
    wire [7:0] rx_byte;

    // Satu baca selesai (RVALID && RREADY) pada register tertentu
    wire read_done = s_RVALID && s_RREADY;

    always @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            div           <= DEFAULT_DIV;
            tx_start      <= 1'b0;
            tx_byte       <= 8'h00;
            rx_valid      <= 1'b0;
            rx_overrun    <= 1'b0;
            rx_ferr       <= 1'b0;
            rx_data       <= 8'h00;
            write_pending <= 1'b0;
        end else begin
            write_pending <= s_WREADY;
            tx_start      <= 1'b0;

            if (write_pending) begin
                case (write_addr[3:2])
                    REG_DATA: if (!tx_busy && !tx_start) begin
                        tx_byte  <= write_data[7:0];
                        tx_start <= 1'b1;
                    end
                    REG_DIV:  div <= write_data[15:0];
                    default: ;
                endcase
            end

            if (read_done && read_addr[3:2] == REG_DATA)   rx_valid <= 1'b0;
            if (read_done && read_addr[3:2] == REG_STATUS) begin
                rx_overrun <= 1'b0;
                rx_ferr    <= 1'b0;
            end

            // Byte baru menang atas penghapusan pada siklus yang sama
            if (rx_strobe) begin
                if (rx_valid && !(read_done && read_addr[3:2] == REG_DATA))
                    rx_overrun <= 1'b1;
                rx_data  <= rx_byte;
                rx_valid <= 1'b1;
            end
            if (rx_frame_error) rx_ferr <= 1'b1;
        end
    end

    always @(*) begin
        case (read_addr[3:2])
            REG_DATA:   read_data = {24'd0, rx_data};
            REG_STATUS: read_data = {28'd0, rx_ferr, rx_overrun, rx_valid, tx_busy | tx_start};
            REG_DIV:    read_data = {16'd0, div};
            default:    read_data = 32'h5541_5231;
        endcase
    end

    uart_tx u_tx (
        .clk(iCLK), .rst_n(iRST), .clks_per_bit(div),
        .start(tx_start), .data(tx_byte), .busy(tx_busy), .tx(oTX)
    );

    uart_rx u_rx (
        .clk(iCLK), .rst_n(iRST), .clks_per_bit(div), .rx(iRX),
        .valid(rx_strobe), .data(rx_byte), .frame_error(rx_frame_error)
    );

endmodule
