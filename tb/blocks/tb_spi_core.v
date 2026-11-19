`timescale 1ns / 1ps

// Testbench blok spi_core.
//
// Slave SPI di testbench membaca SDO pada tepi sampling dan mengeluarkan SDI
// pada tepi sebaliknya, sesuai mode yang sedang diuji. Diuji:
//   - keempat mode CPOL/CPHA, MSB dulu dan LSB dulu (kirim dan terima),
//   - level idle SCK, lebar setengah periode sesuai DIV,
//   - mode 3-wire: SDO_OE = 0 saat RX_EN, byte diterima dari pin yang sama,
//   - start diabaikan saat busy.

module tb_spi_core;

    `include "tb_utils.vh"

    reg         clk, rst_n;
    reg         cpol, cpha, lsb_first, three_wire, rx_en;
    reg  [15:0] div;
    reg         start;
    reg  [7:0]  tx_byte;
    wire        busy, done, sck, sdo, sdo_oe;
    wire [7:0]  rx_byte;
    reg         sdi;

    spi_core uut (
        .clk(clk), .rst_n(rst_n),
        .cpol(cpol), .cpha(cpha), .lsb_first(lsb_first),
        .three_wire(three_wire), .rx_en(rx_en), .div(div),
        .start(start), .tx_byte(tx_byte),
        .busy(busy), .done(done), .rx_byte(rx_byte),
        .sck(sck), .sdo(sdo), .sdo_oe(sdo_oe), .sdi(sdi)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Model slave
    // ------------------------------------------------------------------
    reg  [7:0] slave_tx;     // byte yang dikirim slave
    reg  [7:0] slave_rx;     // byte yang diterima slave
    integer    slave_bits;
    integer    out_idx;
    wire       sample_rising = (cpol == cpha);

    function slave_bit;
        input integer idx;
        begin
            slave_bit = lsb_first ? slave_tx[idx] : slave_tx[7 - idx];
        end
    endfunction

    task slave_sample;
        begin
            if (lsb_first) slave_rx = {sdo, slave_rx[7:1]};
            else           slave_rx = {slave_rx[6:0], sdo};
            slave_bits = slave_bits + 1;
        end
    endtask

    task slave_shift;
        begin
            // CPHA = 1: bit pertama keluar pada tepi depan; CPHA = 0: bit
            // berikutnya keluar pada tepi belakang
            if (out_idx < 8) sdi = slave_bit(out_idx);
            out_idx = out_idx + 1;
        end
    endtask

    always @(posedge sck) if (busy) begin
        if (sample_rising) slave_sample; else slave_shift;
    end
    always @(negedge sck) if (busy) begin
        if (!sample_rising) slave_sample; else slave_shift;
    end

    // Lebar setengah periode SCK
    integer last_edge, min_half, max_half;
    always @(sck) if (busy) begin
        if (last_edge >= 0) begin
            if ($time - last_edge < min_half) min_half = $time - last_edge;
            if ($time - last_edge > max_half) max_half = $time - last_edge;
        end
        last_edge = $time;
    end

    task transfer;
        input [7:0] tx;
        input [7:0] from_slave;
        begin
            slave_tx   = from_slave;
            slave_rx   = 8'h00;
            slave_bits = 0;
            last_edge  = -1;
            min_half   = 1 << 30;
            max_half   = 0;
            // CPHA = 0: slave sudah mengeluarkan bit pertama sebelum tepi depan
            if (!cpha) begin
                sdi     = slave_bit(0);
                out_idx = 1;
            end else begin
                out_idx = 0;
            end
            @(negedge clk);
            tx_byte = tx;
            start   = 1'b1;
            @(negedge clk);
            start   = 1'b0;
            @(posedge done);
            @(negedge clk);
        end
    endtask

    task run_mode;
        input [1:0] mode;
        input       lsb;
        input [7:0] tx;
        input [7:0] rx;
        begin
            cpol = mode[1]; cpha = mode[0]; lsb_first = lsb;
            @(negedge clk);
            check("SCK idle = CPOL", sck, cpol);
            transfer(tx, rx);
            check("byte terkirim ke slave", slave_rx, tx);
            check("byte diterima dari slave", rx_byte, rx);
            check("8 bit dibaca slave", slave_bits, 8);
            check("SCK kembali idle", sck, cpol);
        end
    endtask

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("tb_spi_core.vcd");
            $dumpvars(0, tb_spi_core);
        end

        rst_n = 1'b0; start = 1'b0; tx_byte = 8'h00; sdi = 1'b0;
        cpol = 1'b0; cpha = 1'b0; lsb_first = 1'b0; three_wire = 1'b0; rx_en = 1'b0;
        div = 16'd2;
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        section("Mode 0, MSB dulu");
        run_mode(2'd0, 1'b0, 8'hA5, 8'h3C);
        section("Mode 1, MSB dulu");
        run_mode(2'd1, 1'b0, 8'h81, 8'h7E);
        section("Mode 2, MSB dulu");
        run_mode(2'd2, 1'b0, 8'hC3, 8'h96);
        section("Mode 3, MSB dulu");
        run_mode(2'd3, 1'b0, 8'h12, 8'hED);
        section("Mode 0, LSB dulu");
        run_mode(2'd0, 1'b1, 8'h01, 8'h80);
        section("Mode 3, LSB dulu (TM1638)");
        run_mode(2'd3, 1'b1, 8'h8F, 8'h42);

        section("Pembagi clock");
        div = 16'd0;
        run_mode(2'd3, 1'b1, 8'h55, 8'hAA);
        check("DIV=0: setengah periode 1 siklus (min)", min_half, 10);
        check("DIV=0: setengah periode 1 siklus (max)", max_half, 10);
        div = 16'd4;
        run_mode(2'd0, 1'b0, 8'h5A, 8'hA5);
        check("DIV=4: setengah periode 5 siklus (min)", min_half, 50);
        check("DIV=4: setengah periode 5 siklus (max)", max_half, 50);

        section("3-wire");
        div = 16'd1;
        three_wire = 1'b1; rx_en = 1'b0;
        @(negedge clk);
        check("3-wire kirim: SDO_OE = 1", sdo_oe, 1'b1);
        run_mode(2'd3, 1'b1, 8'h42, 8'h00);
        rx_en = 1'b1;
        @(negedge clk);
        check("3-wire terima: SDO_OE = 0", sdo_oe, 1'b0);
        run_mode(2'd3, 1'b1, 8'h00, 8'hB7);
        three_wire = 1'b0;
        @(negedge clk);
        check("4-wire: SDO_OE = 1 walau RX_EN", sdo_oe, 1'b1);
        rx_en = 1'b0;

        section("Start saat busy diabaikan");
        cpol = 1'b0; cpha = 1'b0; lsb_first = 1'b0;
        slave_rx = 8'h00; slave_bits = 0; slave_tx = 8'h00; out_idx = 1; sdi = 1'b0;
        @(negedge clk);
        tx_byte = 8'hF0; start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        repeat (5) @(negedge clk);
        tx_byte = 8'h0F; start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        @(posedge done);
        @(negedge clk);
        check("byte pertama tidak terganggu", slave_rx, 8'hF0);
        check("busy turun setelah satu byte", busy, 1'b0);

        finish_tb;
    end

    initial begin
        #200000;
        $display("TIMEOUT"); errors = errors + 1;
        finish_tb;
    end

endmodule
