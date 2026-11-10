# Mengubah file .hex 1 byte per baris menjadi 1 word (32 bit) per baris.
# Urutan byte little-endian: byte di alamat terendah menjadi bit [7:0].
#
# Dipanggil oleh tcl/build.tcl, atau langsung:
#   yosys -c tcl/hex_bytes_to_words.tcl

proc hex_bytes_to_words {src dst} {
    set fin [open $src r]
    set bytes {}
    foreach line [split [read $fin] "\n"] {
        set line [string trim [regsub {//.*$} $line ""]]
        if {$line eq ""} { continue }
        if {[string index $line 0] eq "@"} {
            error "$src: alamat @ belum didukung"
        }
        lappend bytes $line
    }
    close $fin

    while {[llength $bytes] % 4 != 0} { lappend bytes 00 }

    set fout [open $dst w]
    fconfigure $fout -translation lf
    puts $fout "// Dibuat otomatis dari [file tail $src] oleh tcl/hex_bytes_to_words.tcl. Jangan diedit."
    for {set i 0} {$i < [llength $bytes]} {incr i 4} {
        puts $fout [format "%02s%02s%02s%02s" \
            [lindex $bytes [expr {$i + 3}]] [lindex $bytes [expr {$i + 2}]] \
            [lindex $bytes [expr {$i + 1}]] [lindex $bytes $i]]
    }
    close $fout
    puts "ROM: [expr {[llength $bytes] / 4}] word ditulis ke $dst"
}

if {[info script] eq $::argv0 || ![info exists ::BUILD_TCL]} {
    hex_bytes_to_words rtl/demo_led_berkedip_xcelium_v2.hex rtl/demo_led_berkedip_xcelium_v2_words.hex
}
