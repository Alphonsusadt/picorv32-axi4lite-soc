#!/usr/bin/env python3
"""Buat modul axi_rom versi ASIC (ROM kombinasional) dari file _words.hex.

Sintesis ASIC mengabaikan $readmemh di blok initial, sehingga isi ROM harus
menjadi logika. Modul hasil mempunyai port yang sama dengan rtl/axi_rom.v,
jadi soc_demo.v tidak perlu diubah: cukup ganti file di daftar sumber.
Port tulis loader (ld_*) diabaikan.

    python3 tools/hex_to_rom_v.py IN_words.hex OUT.v [--addr-bits 9]
"""

import argparse
import sys


def read_words(path):
    words = []
    for line in open(path, encoding="utf-8"):
        line = line.split("//")[0].strip()
        if not line:
            continue
        if line.startswith("@"):
            sys.exit(f"{path}: alamat @ tidak didukung")
        words.extend(int(t, 16) for t in line.split())
    return words


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("hex")
    ap.add_argument("out")
    ap.add_argument("--addr-bits", type=int, default=9,
                    help="bit alamat word ROM (9 = 512 word = 2 KB)")
    args = ap.parse_args()

    words = read_words(args.hex)
    depth = 1 << args.addr_bits
    if len(words) > depth:
        sys.exit(f"{len(words)} word tidak muat di ROM {depth} word")

    ab = args.addr_bits
    lines = [f"            {ab}'d{i}: rom_q = 32'h{w:08x};" for i, w in enumerate(words)]

    src = f"""// DIBUAT OTOMATIS oleh tools/hex_to_rom_v.py dari {args.hex.replace(chr(92), '/').split('/')[-1]}.
// Jangan diedit; jalankan ulang skrip setelah firmware berubah.
//
// axi_rom versi ASIC: isi ROM sebagai logika kombinasional ({len(words)} dari
// {depth} word terpakai, sisanya 0). Port sama dengan rtl/axi_rom.v; port
// tulis loader (ld_*) diabaikan karena ROM ASIC tidak bisa ditulis.
// Parameter ADDR_BITS dan INIT_FILE hanya untuk kecocokan port.

module axi_rom #(
    parameter ADDR_BITS = {ab},
    parameter INIT_FILE = ""
) (
    input         clk,
    input         rst_n,

    input         axi_arvalid,
    output        axi_arready,
    input  [31:0] axi_araddr,
    output        axi_rvalid,
    input         axi_rready,
    output [31:0] axi_rdata,

    input         ld_we,
    input  [31:0] ld_addr,
    input  [31:0] ld_data
);

    // Isi ROM sebagai logika kombinasional. Sengaja memakai always @(*)
    // biasa, bukan function yang dipanggil di blok clock: Yosys (LibreLane)
    // tidak membangun function seperti itu dengan benar.
    wire [{ab - 1}:0] rom_addr = axi_araddr[{ab + 1}:2];
    reg  [31:0] rom_q;
    always @(*) begin
        case (rom_addr)
{chr(10).join(lines)}
            default: rom_q = 32'h00000000;
        endcase
    end

    reg [31:0] rdata_r;
    reg        read_en;

    always @(posedge clk) begin
        if (!rst_n) begin
            read_en <= 1'b0;
            rdata_r <= 32'h0;
        end else if (axi_arvalid && !read_en) begin
            rdata_r <= rom_q;
            read_en <= 1'b1;
        end else if (read_en && axi_rready) begin
            read_en <= 1'b0;
        end
    end

    assign axi_arready = ~read_en;
    assign axi_rvalid  = read_en;
    assign axi_rdata   = rdata_r;

    // Port yang tidak dipakai di ASIC
    wire unused_ok = &{{1'b0, ld_we, ld_addr, ld_data, axi_araddr[31:{ab + 2}], axi_araddr[1:0]}};

endmodule
"""
    open(args.out, "w", encoding="utf-8", newline="\n").write(src)
    print(f"ROM ASIC: {len(words)} word ke {args.out} (ADDR_BITS = {ab})")


if __name__ == "__main__":
    main()
