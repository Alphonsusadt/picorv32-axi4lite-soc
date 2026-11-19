// Inti SPI master 8 bit yang bisa diatur (tanpa antarmuka bus).
//
// Fitur:
//   - CPOL/CPHA: keempat mode SPI (0-3).
//   - Urutan bit: MSB dulu atau LSB dulu.
//   - 4-wire (SDO dan SDI terpisah) atau 3-wire (satu pin data dua arah).
//     Pada 3-wire, rx_en = 1 membuat pin data menjadi input selama transfer.
//   - Pembagi clock: f_SCK = f_clk / (2 * (div + 1)).
//
// Chip select tidak diatur di sini, melainkan langsung oleh register CS di
// axi4_lite_spi, agar satu CS bisa tetap aktif selama beberapa byte.
//
// Penamaan tepi untuk setiap bit:
//   tepi depan    = tepi SCK pertama setelah idle (turun jika CPOL = 1)
//   tepi belakang = tepi SCK kedua
//   CPHA = 0: data keluar sebelum tepi depan, dibaca pada tepi depan.
//   CPHA = 1: data keluar pada tepi depan, dibaca pada tepi belakang.

module spi_core (
    input  wire        clk,
    input  wire        rst_n,

    // Pengaturan (stabil selama transfer)
    input  wire        cpol,
    input  wire        cpha,
    input  wire        lsb_first,
    input  wire        three_wire,
    input  wire        rx_en,
    input  wire [15:0] div,

    // Perintah dan hasil
    input  wire        start,      // pulsa 1 siklus, diabaikan saat busy
    input  wire [7:0]  tx_byte,
    output reg         busy,
    output reg         done,       // pulsa 1 siklus saat byte selesai
    output reg  [7:0]  rx_byte,

    // Pin
    output reg         sck,
    output wire        sdo,        // MOSI, atau DIO keluar pada 3-wire
    output wire        sdo_oe,     // 1 = pin data dikendalikan master
    input  wire        sdi         // MISO, atau DIO masuk pada 3-wire
);

    reg [15:0] cnt;       // penghitung setengah periode SCK
    reg [4:0]  edges;     // jumlah tepi SCK yang sudah dibuat (0-16)
    reg [7:0]  tx_sr;
    reg [7:0]  rx_sr;
    reg        out_bit;
    reg        rx_mode;   // salinan rx_en & three_wire saat transfer dimulai

    wire next_out = lsb_first ? tx_sr[0] : tx_sr[7];
    wire tick     = (cnt == div);
    wire leading  = (edges[0] == 1'b0);   // tepi berikutnya adalah tepi depan

    assign sdo    = out_bit;
    assign sdo_oe = !rx_mode;

    task sample_in;
        begin
            if (lsb_first) rx_sr <= {sdi, rx_sr[7:1]};
            else           rx_sr <= {rx_sr[6:0], sdi};
        end
    endtask

    task shift_out;
        begin
            out_bit <= next_out;
            if (lsb_first) tx_sr <= {1'b0, tx_sr[7:1]};
            else           tx_sr <= {tx_sr[6:0], 1'b0};
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy    <= 1'b0;
            done    <= 1'b0;
            rx_byte <= 8'h00;
            sck     <= 1'b0;
            cnt     <= 16'd0;
            edges   <= 5'd0;
            tx_sr   <= 8'h00;
            rx_sr   <= 8'h00;
            out_bit <= 1'b0;
            rx_mode <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                sck     <= cpol;
                rx_mode <= three_wire && rx_en;
                if (start) begin
                    busy    <= 1'b1;
                    cnt     <= 16'd0;
                    edges   <= 5'd0;
                    rx_sr   <= 8'h00;
                    rx_mode <= three_wire && rx_en;
                    // CPHA = 0: bit pertama harus sudah ada sebelum tepi depan
                    if (!cpha) begin
                        out_bit <= lsb_first ? tx_byte[0] : tx_byte[7];
                        tx_sr   <= lsb_first ? {1'b0, tx_byte[7:1]} : {tx_byte[6:0], 1'b0};
                    end else begin
                        tx_sr   <= tx_byte;
                    end
                end
            end else if (tick) begin
                cnt <= 16'd0;
                if (edges == 5'd16) begin
                    // Setengah periode terakhir sebagai waktu tahan, lalu selesai
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    rx_byte <= rx_sr;
                end else begin
                    sck   <= ~sck;
                    edges <= edges + 5'd1;
                    if (leading) begin
                        if (cpha) shift_out;
                        else      sample_in;
                    end else begin
                        if (cpha)            sample_in;
                        else if (edges != 5'd15) shift_out;
                    end
                end
            end else begin
                cnt <= cnt + 16'd1;
            end
        end
    end

endmodule
