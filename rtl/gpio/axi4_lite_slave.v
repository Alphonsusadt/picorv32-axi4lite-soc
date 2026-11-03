// Antarmuka slave AXI4-Lite untuk axi4_lite_gpio_wrapper.
// Melayani satu transaksi tulis dan satu transaksi baca dalam satu waktu.
module axi4_lite_slave #(
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
    output reg                          s_BVALID,
    output reg  [1:0]                   s_BRESP,

    /* read address channel */
    input                               s_ARVALID,
    input       [2:0]                   s_ARPROT,
    input       [ADDR_WIDTH-1:0]        s_ARADDR,
    output                              s_ARREADY,

    /* read data channel */
    input                               s_RREADY,
    output reg                          s_RVALID,
    output reg  [1:0]                   s_RRESP,
    output      [DATA_WIDTH-1:0]        s_RDATA,

    /* interface */
    output reg  [ADDR_WIDTH-1:0]        write_addr,
    output reg  [DATA_WIDTH-1:0]        write_data,
    output reg  [(DATA_WIDTH/8)-1:0]    write_strb,
    input       [1:0]                   write_resp,
    output reg  [ADDR_WIDTH-1:0]        read_addr,
    input       [DATA_WIDTH-1:0]        read_data,
    input       [1:0]                   read_resp
);

    // AW dan W diterima bersamaan. WREADY hanya aktif satu siklus karena
    // wrapper memakainya sebagai tanda permintaan tulis ke GPIO.
    wire write_accept = s_AWVALID && s_WVALID && !s_BVALID;
    wire read_accept  = s_ARVALID && !s_RVALID;

    assign s_AWREADY = write_accept;
    assign s_WREADY  = write_accept;
    assign s_ARREADY = read_accept;
    assign s_RDATA   = read_data;

    always @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            s_BVALID    <= 1'b0;
            s_BRESP     <= 2'b00;
            s_RVALID    <= 1'b0;
            s_RRESP     <= 2'b00;
            write_addr  <= {ADDR_WIDTH{1'b0}};
            write_data  <= {DATA_WIDTH{1'b0}};
            write_strb  <= {(DATA_WIDTH/8){1'b0}};
            read_addr   <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (write_accept) begin
                write_addr  <= s_AWADDR;
                write_data  <= s_WDATA;
                write_strb  <= s_WSTRB;
                s_BVALID    <= 1'b1;
                s_BRESP     <= write_resp;
            end else if (s_BREADY) begin
                s_BVALID    <= 1'b0;
            end

            if (read_accept) begin
                read_addr   <= s_ARADDR;
                s_RVALID    <= 1'b1;
                s_RRESP     <= read_resp;
            end else if (s_RREADY) begin
                s_RVALID    <= 1'b0;
            end
        end
    end

endmodule
