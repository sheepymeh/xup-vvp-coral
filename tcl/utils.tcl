# Shared Vivado Tcl utilities
proc check_blackboxes {stage {allow_debug_hub 0}} {
    foreach cell [get_cells -hierarchical -filter {IS_BLACKBOX == 1}] {
        if {$allow_debug_hub && $cell eq "dbg_hub" && [get_property REF_NAME $cell] eq "dbg_hub_CV"} {
            continue
        }
        error "Unresolved $stage black box: $cell"
    }
}

proc xup_external_interface {internal external} {
    set pin [get_bd_intf_pins $internal]
    set port [create_bd_intf_port -mode [get_property MODE $pin] -vlnv [get_property VLNV $pin] $external]
    connect_bd_intf_net $pin $port
    return $port
}
