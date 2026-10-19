# Vivado JTAG AXI word-transfer helpers
source [file join [file dirname [info script]] jtag_session.tcl]

proc select_axi {device selector} {
    # Vivado forbids combining a search pattern with -of_objects
    set matches {}
    foreach axi [get_hw_axis -of_objects $device] {
        if {[string match $selector [get_property NAME $axi]]} {
            lappend matches $axi
        }
    }
    if {[llength $matches] != 1} {
        error "AXI selector must match exactly once: $matches"
    }

    return [lindex $matches 0]
}

proc axi_bool {value name} {
    if {![string is boolean -strict $value]} {
        error "Unknown AXI property $name: $value"
    }
    return [expr {$value ? 1 : 0}]
}

proc axi_assert_response {axi direction} {
    refresh_hw_axi $axi
    set prefix [expr {$direction eq "READ" ? "STATUS.AXI_READ" : "STATUS.AXI_WRITE"}]
    set done [axi_bool [get_property ${prefix}_DONE $axi] ${prefix}_DONE]
    set busy [axi_bool [get_property ${prefix}_BUSY $axi] ${prefix}_BUSY]
    set response_name [expr {$direction eq "READ" ? "STATUS.RRESP" : "STATUS.BRESP"}]
    set response [string toupper [string trim [get_property $response_name $axi]]]

    if {!$done || $busy} {
        error "AXI $direction incomplete: done=$done busy=$busy"
    }
    if {$response ni {OKAY 0 00 0X0 0X00 0B00}} {
        error "AXI $direction response $response_name=$response (requires OKAY)"
    }
}

proc axi_word_address {address} {
    if {![string is entier -strict $address] || $address < 0 || $address > 0xfffffffc || $address % 4} {
        error "Expected aligned 32-bit word address: $address"
    }
    return [format %08X $address]
}

proc axi_uint32 {value} {
    if {![string is entier -strict $value] || $value < 0 || $value > 0xffffffff} {
        error "Expected uint32 value: $value"
    }
    return $value
}

proc axi_read32 {axi address} {
    set encoded [axi_word_address $address]

    create_hw_axi_txn xup_read32 $axi -force -type READ -address $encoded -len 1 -cache 0
    set txn [get_hw_axi_txns {xup_read32}]
    run_hw_axi $txn
    axi_assert_response $axi READ

    set value [string trim [get_property DATA $txn]]
    if {![regexp {^(?:0[xX])?([0-9A-Fa-f]{8})$} $value match hex]} {
        error "Unknown single-word DATA format at $encoded: $value"
    }

    return [scan $hex %x]
}

proc axi_write32 {axi address value} {
    set encoded [axi_word_address $address]
    set value [axi_uint32 $value]

    create_hw_axi_txn xup_write32 $axi -force -type WRITE -address $encoded -len 1 -cache 0 -data [format %08X $value]
    run_hw_axi [get_hw_axi_txns {xup_write32}]
    axi_assert_response $axi WRITE
}
