#!/usr/bin/env python3
"""Unggah program ke SoC PicoRV32 lewat UART (9600 baud, 8N1).

Skenario A, loader hardware: program ditulis langsung ke ROM, CPU ditahan
selama unggah lalu mulai dari 0x0000_0000. Bekerja dengan program ROM apa pun.

    python tools/upload.py --port COM6 --rom rtl/led_pattern.hex

Skenario B, bootloader: ROM harus berisi bootloader
(make all PROGRAM=bootloader). Program dimuat ke RAM 0x1000_0000 lalu dijalankan.
--ram otomatis me-reset CPU dulu lewat loader hardware agar bootloader siap.

    python tools/upload.py --port COM6 --ram firmware/bin/led_pattern_ram.bin

Lainnya:
    python tools/upload.py --list                   daftar port serial
    python tools/upload.py --port COM6 --reset      hanya reset CPU
    ... --monitor 5                                 tampilkan keluaran UART 5 detik

File yang diterima: .bin, .hex 1 byte per baris (format file dosen), atau
_words.hex 1 word per baris.
"""

import argparse
import sys
import time

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    sys.exit("pyserial belum terpasang: python -m pip install pyserial")

BAUD = 9600
MAGIC_ROM = bytes([0x55, 0xAA, 0x52, 0x4D])   # loader hardware (skenario A)
MAGIC_RAM = bytes([0x55, 0xAA, 0x52, 0x41])   # bootloader (skenario B)
ROM_WORDS_MIN = 1024                          # ROM iCESugar 4 KB
RAM_WORDS_MAX = (8192 - 1024) // 4            # 7 KB pertama RAM


def read_program(path):
    """Kembalikan isi program sebagai bytes, panjang kelipatan 4."""
    if path.lower().endswith(".bin"):
        data = open(path, "rb").read()
    else:
        tokens = []
        for line in open(path, encoding="utf-8"):
            line = line.split("//")[0].strip()
            if not line or line.startswith("@"):
                if line.startswith("@"):
                    sys.exit(f"{path}: alamat @ tidak didukung")
                continue
            tokens.extend(line.split())
        if any(len(t) > 2 for t in tokens):
            data = b"".join(int(t, 16).to_bytes(4, "little") for t in tokens)
        else:
            data = bytes(int(t, 16) for t in tokens)
    data += bytes((-len(data)) % 4)
    return data


def frame(magic, data):
    n = len(data) // 4
    return magic + n.to_bytes(2, "little") + data + bytes([sum(data) & 0xFF])


def read_until(port, token, timeout):
    """Baca dari UART sampai token muncul. Kembalikan teks yang terbaca."""
    end = time.time() + timeout
    buf = b""
    while time.time() < end:
        chunk = port.read(64)
        if chunk:
            buf += chunk
            if token in buf:
                break
    return buf


def send_rom_frame(port, data):
    # Loader hardware hanya mengenali magic setelah jalur diam >= 20 bit
    port.reset_input_buffer()
    time.sleep(0.05)
    port.write(frame(MAGIC_ROM, data))
    port.flush()
    # Tunggu sampai semua byte benar-benar terkirim (10 bit per byte)
    time.sleep((len(data) + 8) * 10 / BAUD + 0.05)


def main():
    global BAUD
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", help="port serial, mis. COM6 atau /dev/ttyUSB0")
    ap.add_argument("--baud", type=int, default=BAUD)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--rom", metavar="FILE", help="skenario A: tulis program ke ROM")
    g.add_argument("--ram", metavar="FILE", help="skenario B: kirim program ke bootloader")
    g.add_argument("--reset", action="store_true", help="reset CPU lewat loader hardware")
    g.add_argument("--list", action="store_true", help="daftar port serial")
    ap.add_argument("--no-reset", action="store_true",
                    help="--ram tanpa reset CPU dulu (bootloader sudah menunggu)")
    ap.add_argument("--monitor", type=float, default=0, metavar="DETIK",
                    help="tampilkan keluaran UART setelah unggah")
    args = ap.parse_args()

    if args.list:
        for p in serial.tools.list_ports.comports():
            print(f"{p.device:10} {p.description}")
        return
    if not args.port:
        ap.error("--port wajib diisi (lihat --list)")
    if not (args.rom or args.ram or args.reset):
        ap.error("pilih salah satu: --rom, --ram, atau --reset")

    BAUD = args.baud
    port = serial.Serial(args.port, args.baud, timeout=0.1)

    if args.reset:
        send_rom_frame(port, b"")
        print("CPU di-reset.")

    elif args.rom:
        data = read_program(args.rom)
        n = len(data) // 4
        if n > ROM_WORDS_MIN:
            print(f"Peringatan: {n} word melebihi ROM iCESugar ({ROM_WORDS_MIN} word); "
                  "loader akan menolak di iCESugar.")
        print(f"Skenario A: {n} word ke ROM lewat {args.port} "
              f"(~{(len(data) + 7) * 10 / args.baud:.1f} detik)")
        send_rom_frame(port, data)
        print("Selesai. Jika LED error menyala (iCESugar: merah, Tang Nano: selang-seling), "
              "unggahan gagal dan CPU ditahan; ulangi perintah ini.")

    else:
        data = read_program(args.ram)
        n = len(data) // 4
        if n > RAM_WORDS_MAX:
            sys.exit(f"{n} word melebihi batas program RAM ({RAM_WORDS_MAX} word)")
        if not args.no_reset:
            send_rom_frame(port, b"")
            boot = read_until(port, b"BOOT", 2.0)
            if b"BOOT" not in boot:
                sys.exit("Bootloader tidak menjawab BOOT. Pastikan bitstream dibangun "
                         "dengan PROGRAM=bootloader dan port benar.")
            print("Bootloader siap.")
        print(f"Skenario B: {n} word ke RAM lewat {args.port} "
              f"(~{(len(data) + 7) * 10 / args.baud:.1f} detik)")
        port.reset_input_buffer()
        port.write(frame(MAGIC_RAM, data))
        port.flush()
        reply = read_until(port, b"\n", (len(data) + 8) * 10 / args.baud + 2.0)
        if b"OK" in reply:
            print("Bootloader: OK, program RAM berjalan.")
        elif b"ER" in reply:
            sys.exit("Bootloader: ER (checksum salah). Ulangi unggah.")
        else:
            sys.exit(f"Tidak ada jawaban bootloader ({reply!r}).")

    if args.monitor > 0:
        print(f"--- keluaran UART {args.monitor:g} detik ---")
        end = time.time() + args.monitor
        while time.time() < end:
            chunk = port.read(64)
            if chunk:
                sys.stdout.write(chunk.decode("ascii", "replace"))
                sys.stdout.flush()
        print("\n---")

    port.close()


if __name__ == "__main__":
    main()
