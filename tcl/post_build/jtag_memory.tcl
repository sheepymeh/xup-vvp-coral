# Bound JTAG AXI bursts. Vivado DATA lists highest-address words first
source [file join [file dirname [info script]] jtag_axi.tcl]
source $::xup_map_tcl

proc axi_memory_chunks {address count base size} {
    axi_word_address $address
    set address [expr {$address + 0}]
    if {![string is entier -strict $count] || $count <= 0} {
        error "Memory word count must be a positive integer: $count"
    }

    set end [expr {$address + 4 * $count}]
    if {
        ![string is entier -strict $base] || ![string is entier -strict $size] ||
        $base < 0 || $size <= 0 || $base % 4 || $size % 4 || $base + $size > 0x100000000
    } {
        error "Invalid bounded memory region: $base, $size"
    }
    if {$address < $base || $end > $base + $size} {
        error "Memory transfer outside bounded region: [format 0x%08X $address], $count words"
    }

    set chunks {}
    while {$count > 0} {
        set boundary_words [expr {(4096 - ($address & 4095)) / 4}]
        set region_words [expr {($base + $size - $address) / 4}]
        set length [expr {min($count, 256, $boundary_words, $region_words)}]
        lappend chunks [list $address $length]
        incr address [expr {4 * $length}]
        incr count -$length
    }

    return $chunks
}

proc axi_encode_words {words} {
    set encoded {}
    foreach word [lreverse $words] {
        lappend encoded [format %08X [axi_uint32 $word]]
    }

    return [join $encoded _]
}

proc axi_decode_data {data count} {
    set compact [string trim $data]
    regsub -all {[[:space:]_]} $compact {} compact
    regsub {^0[xX]} $compact {} compact
    if {![regexp {^[0-9A-Fa-f]+$} $compact] || [string length $compact] != 8 * $count} {
        error "Unknown memory DATA format: expected $count exact 32-bit words, received [string length $compact] hex characters"
    }

    set words {}
    for {set index 0} {$index < $count} {incr index} {
        set start [expr {8 * $index}]
        lappend words [scan [string range $compact $start [expr {$start + 7}]] %x]
    }

    return [lreverse $words]
}

proc axi_memory_write_words {axi address words base size} {
    # Validate payload before starting the transaction
    set chunks [axi_memory_chunks $address [llength $words] $base $size]
    foreach word $words {
        axi_uint32 $word
    }

    set offset 0
    foreach chunk $chunks {
        lassign $chunk current length
        set data [axi_encode_words [lrange $words $offset [expr {$offset + $length - 1}]]]
        create_hw_axi_txn xup_memory_write $axi -force -type WRITE \
            -address [axi_word_address $current] -len $length -burst INCR -cache 0 -data $data
        run_hw_axi [get_hw_axi_txns {xup_memory_write}]
        axi_assert_response $axi WRITE
        incr offset $length
    }
}

proc axi_memory_read_words {axi address count base size} {
    set chunks [axi_memory_chunks $address $count $base $size]

    set words {}
    foreach chunk $chunks {
        lassign $chunk current length
        create_hw_axi_txn xup_memory_read $axi -force -type READ \
            -address [axi_word_address $current] -len $length -burst INCR -cache 0
        set transaction [get_hw_axi_txns {xup_memory_read}]
        run_hw_axi $transaction
        axi_assert_response $axi READ
        lappend words {*}[axi_decode_data [get_property DATA $transaction] $length]
    }
    return $words
}

proc axi_compare {address expected observed context} {
    if {[llength $observed] != [llength $expected]} {
        error "$context returned [llength $observed] words, expected [llength $expected]"
    }

    set index 0
    foreach want $expected got $observed {
        if {$want != $got} {
            error "$context mismatch at [format 0x%08X [expr {$address + 4 * $index}]]: expected [format 0x%08X $want], got [format 0x%08X $got]"
        }
        incr index
    }
}
