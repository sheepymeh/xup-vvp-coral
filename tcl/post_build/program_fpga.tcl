# Program FPGA with matching debug probes when supplied
source [file join [file dirname [info script]] jtag_axi.tcl]
source [lindex $argv 0]
set argv [lrange $argv 1 end]

hardware_entry {
    lassign $argv server target device axi_selector bit
    set ltx [lindex $argv 5]

    set selected [connect_selected_device $server $target $device]
    set_property PROGRAM.FILE $bit $selected
    # Clear stale probe associations when no LTX is supplied
    set_property PROBES.FILE $ltx $selected
    program_hw_devices $selected
    refresh_hw_device $selected
    puts "Programmed $selected with $bit"
    puts "AXI masters: [get_hw_axis -of_objects $selected]"

    # Read board/core status
    set axi [select_axi $selected $axi_selector]
    set state {}
    foreach {name offset} [list \
        heartbeat $XUP_SHELL_HEARTBEAT_OFFSET \
        readiness $XUP_SHELL_READINESS_OFFSET \
        features $XUP_SHELL_FEATURES_OFFSET \
        fault $XUP_SHELL_FAULT_OFFSET \
    ] {
        dict set state $name [axi_read32 $axi [expr {$XUP_SHELL_BASE + $offset}]]
    }
    dict set state control [axi_read32 $axi [expr {$XUP_CORE_CSR_BASE + $XUP_CORE_CSR_CONTROL_OFFSET}]]
    puts "XUP_PROGRAM_RESULT $state"
}
