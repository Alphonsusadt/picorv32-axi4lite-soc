// Pengirim UART 8N1. clks_per_bit sama dengan uart_rx.

module uart_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] clks_per_bit,
    input  wire        start,        // pulsa 1 siklus, diabaikan saat busy
    input  wire [7:0]  data,
    output reg         busy,
    output reg         tx
);

    reg [15:0] cnt;
    reg [3:0]  bit_idx;   // 0 = start, 1-8 = data, 9 = stop
    reg [7:0]  sr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy    <= 1'b0;
            tx      <= 1'b1;
            cnt     <= 16'd0;
            bit_idx <= 4'd0;
            sr      <= 8'h00;
        end else if (!busy) begin
            tx <= 1'b1;
            if (start) begin
                busy    <= 1'b1;
                sr      <= data;
                tx      <= 1'b0;      // start bit
                cnt     <= 16'd0;
                bit_idx <= 4'd0;
            end
        end else if (cnt == clks_per_bit - 16'd1) begin
            cnt <= 16'd0;
            if (bit_idx == 4'd9) begin
                busy <= 1'b0;
                tx   <= 1'b1;
            end else begin
                bit_idx <= bit_idx + 4'd1;
                if (bit_idx == 4'd8) begin
                    tx <= 1'b1;       // stop bit
                end else begin
                    tx <= sr[0];
                    sr <= {1'b0, sr[7:1]};
                end
            end
        end else begin
            cnt <= cnt + 16'd1;
        end
    end

endmodule
