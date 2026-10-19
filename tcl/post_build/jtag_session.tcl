# Select JTAG device/clean up session
proc connect_selected_device {server target_selector device_selector} {
    open_hw_manager
    connect_hw_server -url $server

    set targets [get_hw_targets $target_selector]
    if {[llength $targets] != 1} {
        error "Target must match exactly once: $targets"
    }
    set target [lindex $targets 0]
    current_hw_target $target
    open_hw_target

    set devices [get_hw_devices $device_selector]
    if {[llength $devices] != 1} {
        error "Device must match exactly once: $devices"
    }
    set device [lindex $devices 0]
    current_hw_device $device
    return $device
}

proc hardware_entry {body} {
    set code [catch {uplevel 1 $body} message options]

    if {$code} {
        puts stderr "HARDWARE OPERATION FAILED: $message"
        if {[dict exists $options -errorinfo]} {
            puts stderr [dict get $options -errorinfo]
        }
    }

    catch {close_hw_target}
    catch {disconnect_hw_server}
    catch {close_hw_manager}
    exit [expr {$code ? 1 : 0}]
}
