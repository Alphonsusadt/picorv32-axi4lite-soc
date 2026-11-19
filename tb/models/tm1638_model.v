`timescale 1ns / 1ps

// Model perilaku TM1638 untuk simulasi (bukan untuk sintesis).
//
// Mengikuti datasheet TM1638:
//   - STB rendah memulai perintah, byte pertama adalah perintah.
//   - Data LSB dulu, dibaca TM1638 pada tepi naik CLK (CLK idle tinggi).
//   - 0x40 tulis auto-increment, 0x44 tulis alamat tetap, 0x42 baca tombol.
//   - 0xC0 | addr memilih alamat display, byte berikutnya adalah data.
//   - 0x80 | x mengatur display (bit3 = on, bit[2:0] = kecerahan).
//   - Saat membaca tombol, TM1638 mengeluarkan 4 byte pada tepi turun CLK.
//
// Pelanggaran protokol (STB naik di tengah byte, DIO bentrok) dihitung di
// protocol_errors agar bisa diperiksa testbench.

module tm1638_model (
    input  wire        stb,
    input  wire        clk,
    inout  wire        dio,
    input  wire [31:0] keys       // 4 byte data tombol, byte 0 = bit[7:0]
);

    reg [7:0] disp [0:15];
    reg [7:0] display_ctrl;
    reg [7:0] last_cmd;
    integer   protocol_errors;
    integer   bytes_received;

    reg [7:0] sr;
    integer   bit_cnt;
    integer   byte_idx;
    reg [3:0] addr;
    reg       auto_inc;
    reg       read_mode;
    reg       addr_mode;          // byte setelah 0xC0 adalah data display
    reg       drive;
    reg       drive_bit;
    integer   read_bit;

    assign dio = drive ? drive_bit : 1'bz;

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) disp[i] = 8'h00;
        display_ctrl    = 8'h00;
        last_cmd        = 8'h00;
        protocol_errors = 0;
        bytes_received  = 0;
        auto_inc        = 1'b1;
        read_mode       = 1'b0;
        addr_mode       = 1'b0;
        drive           = 1'b0;
        drive_bit       = 1'b1;
        bit_cnt         = 0;
        byte_idx        = 0;
        addr            = 4'd0;
    end

    always @(negedge stb) begin
        bit_cnt   = 0;
        byte_idx  = 0;
        read_mode = 1'b0;
        addr_mode = 1'b0;
        read_bit  = 0;
    end

    always @(posedge stb) begin
        if (bit_cnt != 0 && !read_mode) begin
            protocol_errors = protocol_errors + 1;
            $display("  [TM1638] STB naik di tengah byte (%0d bit)", bit_cnt);
        end
        drive     = 1'b0;
        read_mode = 1'b0;
    end

    // Mode baca: bit tombol keluar pada tepi turun CLK
    always @(negedge clk) begin
        if (!stb && read_mode) begin
            if (read_bit < 32) begin
                drive     = 1'b1;
                drive_bit = keys[read_bit];
                read_bit  = read_bit + 1;
            end else begin
                drive = 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!stb && !read_mode) begin
            if (dio !== 1'b0 && dio !== 1'b1) begin
                protocol_errors = protocol_errors + 1;
                $display("  [TM1638] DIO tidak valid (%b) saat dibaca", dio);
            end
            sr      = {dio, sr[7:1]};
            bit_cnt = bit_cnt + 1;
            if (bit_cnt == 8) begin
                bit_cnt        = 0;
                bytes_received = bytes_received + 1;
                handle_byte(sr);
                byte_idx = byte_idx + 1;
            end
        end
    end

    // Bentrok: TM1638 dan master sama-sama mengendalikan DIO
    always @(dio) begin
        if (drive && dio !== drive_bit) begin
            protocol_errors = protocol_errors + 1;
            $display("  [TM1638] DIO bentrok saat membaca tombol");
        end
    end

    task handle_byte;
        input [7:0] b;
        begin
            if (byte_idx == 0) begin
                last_cmd = b;
                case (b[7:6])
                    2'b01: begin                     // perintah data
                        auto_inc = !b[2];
                        if (b[1:0] == 2'b10) begin
                            read_mode = 1'b1;
                            read_bit  = 0;
                        end
                    end
                    2'b10: display_ctrl = b;         // pengaturan display
                    2'b11: begin                     // alamat
                        addr      = b[3:0];
                        addr_mode = 1'b1;
                    end
                    default: ;
                endcase
            end else if (addr_mode) begin
                disp[addr] = b;
                if (auto_inc) addr = addr + 4'd1;
            end else begin
                protocol_errors = protocol_errors + 1;
                $display("  [TM1638] byte data %h tanpa perintah alamat", b);
            end
        end
    endtask

endmodule
