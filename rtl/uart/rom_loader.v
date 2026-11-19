// Skenario A: loader hardware. Menerima program lewat UART lalu menulisnya
// langsung ke ROM lewat port B (ld_we/ld_addr/ld_data), sambil menahan CPU
// dalam reset. Tidak butuh firmware apa pun.
//
// Frame (semua little-endian):
//   4 byte  magic 55 AA 52 4D  ("..RM" = ROM)
//   2 byte  N = jumlah word (0 = hanya reset CPU)
//   4N byte isi program, word ke-i ditulis ke ROM word i
//   1 byte  checksum = jumlah semua byte isi program, mod 256
//
// Magic hanya dikenali jika jalur RX sudah diam minimal GAP_BITS waktu bit.
// Dengan begitu loader tidak terpicu oleh data di tengah aliran lain
// (misalnya program yang sedang dikirim ke bootloader skenario B).
//
// Hasil:
//   - hold  = 1 sejak magic lengkap; CPU ditahan reset.
//   - Checksum benar: hold = 0, error = 0, CPU mulai dari 0x0000_0000.
//   - Checksum salah, N terlalu besar, atau aliran terputus (TIMEOUT_BITS):
//     error = 1 dan CPU tetap ditahan sampai frame yang benar diterima.

module rom_loader #(
    parameter ROM_WORDS    = 4096,
    parameter GAP_BITS     = 20,
    parameter TIMEOUT_BITS = 10000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] clks_per_bit,
    input  wire        rx,

    output reg         hold,
    output reg         error,
    output wire        busy,

    output reg         ld_we,
    output reg  [31:0] ld_addr,
    output reg  [31:0] ld_data
);

    localparam [31:0] MAGIC = 32'h4D52_AA55;   // urutan terima: 55 AA 52 4D

    localparam S_IDLE = 3'd0;
    localparam S_MAG  = 3'd1;
    localparam S_LEN0 = 3'd2;
    localparam S_LEN1 = 3'd3;
    localparam S_DATA = 3'd4;
    localparam S_SUM  = 3'd5;

    wire       rx_valid;
    wire [7:0] rx_byte;

    uart_rx u_rx (
        .clk(clk), .rst_n(rst_n), .clks_per_bit(clks_per_bit), .rx(rx),
        .valid(rx_valid), .data(rx_byte), .frame_error()
    );

    // Salinan RX yang disinkronkan, untuk mengukur waktu diam
    reg [1:0] rx_sync;
    wire      rx_s = rx_sync[1];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rx_sync <= 2'b11;
        else        rx_sync <= {rx_sync[0], rx};
    end

    // Penghitung waktu diam dalam satuan bit (jenuh)
    reg [15:0] bit_cnt;
    reg [15:0] idle_bits;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt   <= 16'd0;
            idle_bits <= 16'd0;
        end else if (rx_valid || !rx_s) begin
            // Jalur aktif: hitung ulang dari nol
            bit_cnt   <= 16'd0;
            idle_bits <= 16'd0;
        end else if (bit_cnt == clks_per_bit - 16'd1) begin
            bit_cnt <= 16'd0;
            if (idle_bits != 16'hFFFF) idle_bits <= idle_bits + 16'd1;
        end else begin
            bit_cnt <= bit_cnt + 16'd1;
        end
    end

    // Diam sebelum byte pertama: diukur saat start bit muncul
    reg gap_ok;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)                 gap_ok <= 1'b1;
        else if (rx_s && idle_bits >= GAP_BITS) gap_ok <= 1'b1;
        else if (rx_valid)          gap_ok <= 1'b0;
    end

    reg [2:0]  state;
    reg [1:0]  idx;          // indeks byte magic atau byte dalam word
    reg [15:0] n_words;
    reg [15:0] word_cnt;
    reg [7:0]  sum;
    reg [23:0] word_lo;

    assign busy = (state != S_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            idx      <= 2'd0;
            n_words  <= 16'd0;
            word_cnt <= 16'd0;
            sum      <= 8'h00;
            word_lo  <= 24'h0;
            hold     <= 1'b0;
            error    <= 1'b0;
            ld_we    <= 1'b0;
            ld_addr  <= 32'd0;
            ld_data  <= 32'd0;
        end else begin
            ld_we <= 1'b0;

            if (state != S_IDLE && idle_bits >= TIMEOUT_BITS) begin
                // Aliran terputus di tengah frame
                if (hold) error <= 1'b1;
                state <= S_IDLE;
            end else if (rx_valid) begin
                case (state)
                    S_IDLE: begin
                        if (gap_ok && rx_byte == MAGIC[7:0]) begin
                            state <= S_MAG;
                            idx   <= 2'd1;
                        end
                    end
                    S_MAG: begin
                        if (rx_byte == MAGIC[8*idx +: 8]) begin
                            idx <= idx + 2'd1;
                            if (idx == 2'd3) begin
                                hold  <= 1'b1;
                                state <= S_LEN0;
                            end
                        end else begin
                            state <= S_IDLE;
                        end
                    end
                    S_LEN0: begin
                        n_words[7:0] <= rx_byte;
                        state        <= S_LEN1;
                    end
                    S_LEN1: begin
                        n_words[15:8] <= rx_byte;
                        word_cnt      <= 16'd0;
                        sum           <= 8'h00;
                        idx           <= 2'd0;
                        if ({rx_byte, n_words[7:0]} > ROM_WORDS) begin
                            error <= 1'b1;
                            state <= S_IDLE;
                        end else if ({rx_byte, n_words[7:0]} == 16'd0) begin
                            state <= S_SUM;
                        end else begin
                            state <= S_DATA;
                        end
                    end
                    S_DATA: begin
                        sum <= sum + rx_byte;
                        idx <= idx + 2'd1;
                        case (idx)
                            2'd0: word_lo[7:0]   <= rx_byte;
                            2'd1: word_lo[15:8]  <= rx_byte;
                            2'd2: word_lo[23:16] <= rx_byte;
                            2'd3: begin
                                ld_we    <= 1'b1;
                                ld_addr  <= {16'd0, word_cnt};
                                ld_data  <= {rx_byte, word_lo};
                                word_cnt <= word_cnt + 16'd1;
                                if (word_cnt == n_words - 16'd1) state <= S_SUM;
                            end
                        endcase
                    end
                    S_SUM: begin
                        if (rx_byte == sum) begin
                            hold  <= 1'b0;
                            error <= 1'b0;
                        end else begin
                            error <= 1'b1;
                        end
                        state <= S_IDLE;
                    end
                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule
