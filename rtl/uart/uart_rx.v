// Penerima UART 8N1.
//
// clks_per_bit = f_clk / baud (dibulatkan). Contoh 9600 baud:
//   iCESugar 750 kHz -> 78, Tang Nano 20K 210,9 kHz -> 22.
// Bit dibaca di tengah periode bit. Input disinkronkan dua flip-flop
// karena berasal dari luar FPGA.

module uart_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] clks_per_bit,
    input  wire        rx,
    output reg         valid,        // pulsa 1 siklus, data siap
    output reg  [7:0]  data,
    output reg         frame_error   // pulsa 1 siklus, stop bit tidak 1
);

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]  sync;
    wire       rx_s = sync[1];

    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  sr;

    // Start bit terlihat sekitar 3 siklus setelah tepi turun (2 flip-flop
    // sinkronisasi + perpindahan state), jadi penantian setengah bit dikurangi 3
    // agar bit dibaca tepat di tengah.
    wire [15:0] half_bit = (clks_per_bit >= 16'd8) ? (clks_per_bit >> 1) - 16'd3 : 16'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync        <= 2'b11;
            state       <= S_IDLE;
            cnt         <= 16'd0;
            bit_idx     <= 3'd0;
            sr          <= 8'h00;
            valid       <= 1'b0;
            data        <= 8'h00;
            frame_error <= 1'b0;
        end else begin
            sync        <= {sync[0], rx};
            valid       <= 1'b0;
            frame_error <= 1'b0;

            case (state)
                S_IDLE: begin
                    cnt <= 16'd0;
                    if (!rx_s) state <= S_START;
                end
                // Tunggu setengah bit lalu pastikan start bit masih 0
                S_START: begin
                    if (cnt == half_bit) begin
                        cnt     <= 16'd0;
                        bit_idx <= 3'd0;
                        state   <= rx_s ? S_IDLE : S_DATA;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
                S_DATA: begin
                    if (cnt == clks_per_bit - 16'd1) begin
                        cnt     <= 16'd0;
                        sr      <= {rx_s, sr[7:1]};      // LSB dulu
                        bit_idx <= bit_idx + 3'd1;
                        if (bit_idx == 3'd7) state <= S_STOP;
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
                S_STOP: begin
                    if (cnt == clks_per_bit - 16'd1) begin
                        state <= S_IDLE;
                        if (rx_s) begin
                            valid <= 1'b1;
                            data  <= sr;
                        end else begin
                            frame_error <= 1'b1;
                        end
                    end else begin
                        cnt <= cnt + 16'd1;
                    end
                end
            endcase
        end
    end

endmodule
