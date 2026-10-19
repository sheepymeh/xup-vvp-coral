# External memory AXI interface/backend initialization
namespace eval extmem_backend {}

source [file join [file dirname [info script]] extmem_backends onchip.tcl]

proc extmem_backend::is_onchip {kind} {
    return [expr {$kind in {bram uram}}]
}

proc extmem_backend::create_bank {kind prefix data_bits capacity_bytes} {
    if {$capacity_bytes <= 0 || $capacity_bytes % ($data_bits / 8) != 0} {
        error "Memory backend capacity must be multiple of AXI data words"
    }

    if {![is_onchip $kind]} {
        error "Unknown memory backend: $kind"
    }
    return [onchip::create_bank $kind $prefix $data_bits $capacity_bytes]
}

