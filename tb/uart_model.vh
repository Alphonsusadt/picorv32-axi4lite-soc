// Model UART untuk testbench: mengirim byte/frame ke pin RX dan menerima
// teks dari pin TX. Di-include di dalam modul testbench yang punya:
//   reg uart_line;        pin RX perangkat (idle 1)
//   wire uart_out;        pin TX perangkat
//   parameter UART_BIT;   lama 1 bit dalam ns

task uart_send;
    input [7:0] b;
    integer k;
    begin
        uart_line = 1'b0;
        #(UART_BIT);
        for (k = 0; k < 8; k = k + 1) begin
            uart_line = b[k];
            #(UART_BIT);
        end
        uart_line = 1'b1;
        #(UART_BIT);
    end
endtask

// Frame loader: magic 4 byte, N word, isi, checksum
task uart_send_frame;
    input [31:0] magic;          // byte pertama = bit [7:0]
    input integer n_words;
    input integer first_byte;    // indeks awal di frame_bytes
    input [7:0]  checksum_xor;   // 0 = checksum benar, selain 0 = sengaja salah
    integer k;
    reg [7:0] sum;
    begin
        uart_send(magic[7:0]);   uart_send(magic[15:8]);
        uart_send(magic[23:16]); uart_send(magic[31:24]);
        uart_send(n_words[7:0]); uart_send(n_words[15:8]);
        sum = 8'h00;
        for (k = 0; k < 4 * n_words; k = k + 1) begin
            uart_send(frame_bytes[first_byte + k]);
            sum = sum + frame_bytes[first_byte + k];
        end
        uart_send(sum ^ checksum_xor);
    end
endtask

// Penerima teks dari pin TX perangkat
reg [8*64-1:0] uart_text;
integer        uart_chars;
initial begin uart_text = 0; uart_chars = 0; end

always @(negedge uart_out) begin : uart_rx_model
    integer k;
    reg [7:0] c;
    #(UART_BIT / 2);
    if (uart_out == 1'b0) begin
        for (k = 0; k < 8; k = k + 1) begin
            #(UART_BIT);
            c[k] = uart_out;
        end
        #(UART_BIT);
        uart_text  = {uart_text[8*63-1:0], c};
        uart_chars = uart_chars + 1;
    end
end

task uart_clear;
    begin uart_text = 0; uart_chars = 0; end
endtask
