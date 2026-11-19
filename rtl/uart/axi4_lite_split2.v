// Pemisah AXI4-Lite 1 master -> 2 slave berdasarkan satu bit alamat.
//
// Dipakai di slot s3 karena keempat slot interconnect sudah terpakai:
//   alamat bit SEL_BIT = 0 -> slave a (SPI,  0x0002_0000)
//   alamat bit SEL_BIT = 1 -> slave b (UART, 0x0002_1000)
//
// Tanpa register: PicoRV32 hanya punya satu transaksi berjalan dalam satu
// waktu, sehingga kanal respons cukup digabung dari kedua slave (slave yang
// tidak dipilih selalu diam). AW dan W dipilih dengan AWADDR karena kedua
// slave menerima AW dan W bersamaan.

module axi4_lite_split2 #(
    parameter SEL_BIT = 12
) (
    // dari interconnect
    input         s_AWVALID,
    input  [31:0] s_AWADDR,
    output        s_AWREADY,
    input         s_WVALID,
    input  [31:0] s_WDATA,
    input  [ 3:0] s_WSTRB,
    output        s_WREADY,
    input         s_BREADY,
    output        s_BVALID,
    output [ 1:0] s_BRESP,
    input         s_ARVALID,
    input  [31:0] s_ARADDR,
    output        s_ARREADY,
    input         s_RREADY,
    output        s_RVALID,
    output [ 1:0] s_RRESP,
    output [31:0] s_RDATA,

    // ke slave a
    output        a_AWVALID,
    output [31:0] a_AWADDR,
    input         a_AWREADY,
    output        a_WVALID,
    output [31:0] a_WDATA,
    output [ 3:0] a_WSTRB,
    input         a_WREADY,
    output        a_BREADY,
    input         a_BVALID,
    input  [ 1:0] a_BRESP,
    output        a_ARVALID,
    output [31:0] a_ARADDR,
    input         a_ARREADY,
    output        a_RREADY,
    input         a_RVALID,
    input  [ 1:0] a_RRESP,
    input  [31:0] a_RDATA,

    // ke slave b
    output        b_AWVALID,
    output [31:0] b_AWADDR,
    input         b_AWREADY,
    output        b_WVALID,
    output [31:0] b_WDATA,
    output [ 3:0] b_WSTRB,
    input         b_WREADY,
    output        b_BREADY,
    input         b_BVALID,
    input  [ 1:0] b_BRESP,
    output        b_ARVALID,
    output [31:0] b_ARADDR,
    input         b_ARREADY,
    output        b_RREADY,
    input         b_RVALID,
    input  [ 1:0] b_RRESP,
    input  [31:0] b_RDATA
);

    wire wsel = s_AWADDR[SEL_BIT];
    wire rsel = s_ARADDR[SEL_BIT];

    // Tulis
    assign a_AWVALID = s_AWVALID & ~wsel;
    assign b_AWVALID = s_AWVALID &  wsel;
    assign a_WVALID  = s_WVALID  & ~wsel;
    assign b_WVALID  = s_WVALID  &  wsel;
    assign a_AWADDR  = s_AWADDR;
    assign b_AWADDR  = s_AWADDR;
    assign a_WDATA   = s_WDATA;
    assign b_WDATA   = s_WDATA;
    assign a_WSTRB   = s_WSTRB;
    assign b_WSTRB   = s_WSTRB;
    assign s_AWREADY = wsel ? b_AWREADY : a_AWREADY;
    assign s_WREADY  = wsel ? b_WREADY  : a_WREADY;

    assign a_BREADY  = s_BREADY;
    assign b_BREADY  = s_BREADY;
    assign s_BVALID  = a_BVALID | b_BVALID;
    assign s_BRESP   = b_BVALID ? b_BRESP : a_BRESP;

    // Baca
    assign a_ARVALID = s_ARVALID & ~rsel;
    assign b_ARVALID = s_ARVALID &  rsel;
    assign a_ARADDR  = s_ARADDR;
    assign b_ARADDR  = s_ARADDR;
    assign s_ARREADY = rsel ? b_ARREADY : a_ARREADY;

    assign a_RREADY  = s_RREADY;
    assign b_RREADY  = s_RREADY;
    assign s_RVALID  = a_RVALID | b_RVALID;
    assign s_RRESP   = b_RVALID ? b_RRESP : a_RRESP;
    assign s_RDATA   = b_RVALID ? b_RDATA : a_RDATA;

endmodule
