# Load/start/inspect CoralNPU over JTAG
set xup_map_tcl [lindex $argv 0]
set argv [lrange $argv 1 end]
source [file join [file dirname [info script]] jtag_memory.tcl]

proc core_region_bounds {region} {
    switch -- $region {
        itcm {
            return [list $::XUP_ITCM_BASE $::XUP_ITCM_SIZE]
        }
        dtcm {
            return [list $::XUP_DTCM_BASE $::XUP_DTCM_SIZE]
        }
        external {
            return [list $::XUP_EXTERNAL_BASE $::XUP_EXTERNAL_SIZE]
        }
        default {
            error "Unknown memory region found: $region"
        }
    }
}

proc core_load_plan {path} {
    set stream [open $path r]
    set plan [read $stream]
    close $stream
    dict set plan payload [file join [file dirname $path] segments.bin]
    return $plan
}

proc core_csr_write {axi offset value} {
    if {$offset != $::XUP_CORE_CSR_CONTROL_OFFSET && $offset != $::XUP_CORE_CSR_START_PC_OFFSET} {
        error "Loader writes only complete control/start-PC CSR words"
    }

    axi_uint32 $value
    if {$offset == $::XUP_CORE_CSR_CONTROL_OFFSET} {
        set reset_only [expr {1 << $::XUP_CORE_CSR_RESET_BIT}]
        if {$value != 0 && $value != $reset_only && $value != $::XUP_CORE_CSR_RESET_VALUE} {
            error "Loader control must be reset/gated ($::XUP_CORE_CSR_RESET_VALUE), reset/ungated ($reset_only), or running (0)"
        }
    }

    # Write complete, uncached 32-bit CSR words
    set address [expr {$::XUP_CORE_CSR_BASE + $offset}]
    axi_write32 $axi $address $value
    axi_compare $address [list $value] [list [axi_read32 $axi $address]] "CSR readback"
}

proc core_wait_ready {axi {required_readiness 3}} {
    # Wait for fabric reset release and external memory readiness
    set address [expr {$::XUP_SHELL_BASE + $::XUP_SHELL_READINESS_OFFSET}]
    set timeout_ms 30000
    set poll_interval_ms 100
    set deadline [expr {[clock milliseconds] + $timeout_ms}]
    while {1} {
        set observed [axi_read32 $axi $address]
        if {($observed & $required_readiness) == $required_readiness} {
            return
        }
        if {[clock milliseconds] >= $deadline} {
            error "Timed out waiting for core to become ready: got $observed, required $required_readiness"
        }
        after $poll_interval_ms
    }
}

proc core_write_verified {axi address words region context} {
    lassign [core_region_bounds $region] base size
    axi_memory_write_words $axi $address $words $base $size
    axi_compare $address $words [axi_memory_read_words $axi $address [llength $words] $base $size] $context
}

proc core_write_segment {axi payload segment} {
    set address [dict get $segment address]
    set remaining [dict get $segment memory_size]
    set file_remaining [dict get $segment file_size]
    set region [dict get $segment region]
    seek $payload [dict get $segment file_offset]

    set count 0
    while {$remaining > 0} {
        set leading [expr {$address & 3}]
        set length [expr {min($remaining, 1024 - $leading)}]
        set file_bytes [expr {min($length, $file_remaining)}]
        set data [read $payload $file_bytes]
        if {[string length $data] != $file_bytes} {
            error "Truncated ELF segment payload"
        }
        append data [string repeat \x00 [expr {$length - $file_bytes}]]

        set trailing [expr {($leading + $length) % 4}]
        set padded [string repeat \x00 $leading]$data
        if {$trailing} {
            append padded [string repeat \x00 [expr {4 - $trailing}]]
        }
        binary scan $padded iu* words

        # Preserve bytes outside the segment at its two word boundaries
        set start [expr {$address & ~3}]
        if {$leading} {
            set mask [expr {(1 << (8 * $leading)) - 1}]
            lset words 0 [expr {[lindex $words 0] | ([axi_read32 $axi $start] & $mask)}]
        }
        if {$trailing} {
            set last [expr {$start + 4 * ([llength $words] - 1)}]
            set mask [expr {0xffffffff ^ ((1 << (8 * $trailing)) - 1)}]
            lset words end [expr {[lindex $words end] | ([axi_read32 $axi $last] & $mask)}]
        }
        core_write_verified $axi $start $words $region "PT_LOAD/BSS readback"
        incr count [llength $words]
        incr address $length
        incr remaining -$length
        incr file_remaining -$file_bytes
    }
    return $count
}

proc core_load_stopped {axi plan} {
    core_csr_write $axi $::XUP_CORE_CSR_CONTROL_OFFSET $::XUP_CORE_CSR_RESET_VALUE
    set payload [open [dict get $plan payload] rb]
    set count 0
    try {
        foreach segment [dict get $plan segments] {
            incr count [core_write_segment $axi $payload $segment]
        }
    } finally {
        close $payload
    }
    core_csr_write $axi $::XUP_CORE_CSR_START_PC_OFFSET [dict get $plan entry_point]
    puts "XUP_CORE_LOAD_RESULT [dict create state LOADED_STOPPED entry_point [dict get $plan entry_point] verified_words $count]"
}

proc core_start_loaded {axi plan} {
    if {
        [catch {
            # Ungate under reset so the upstream reset synchronizer can run
            core_csr_write $axi $::XUP_CORE_CSR_CONTROL_OFFSET [expr {1 << $::XUP_CORE_CSR_RESET_BIT}]
            core_csr_write $axi $::XUP_CORE_CSR_CONTROL_OFFSET 0
        } message options]
    } {
        catch {core_csr_write $axi $::XUP_CORE_CSR_CONTROL_OFFSET $::XUP_CORE_CSR_RESET_VALUE}
        return -options $options $message
    }
    set result [dict create state STARTED entry_point [dict get $plan entry_point]]
    puts "XUP_CORE_RUN_RESULT $result"
    return $result
}

proc core_loader_prepare {arguments} {
    lassign $arguments server target device axi_selector action plan_file

    set plan {}
    switch -- $action {
        load - run {
            if {[llength $arguments] != 6} {
                error "$action requires a load-plan file"
            }
            set plan [core_load_plan $plan_file]
        }
        stop - status {
            if {[llength $arguments] != 5} {
                error "$action takes no load-plan file"
            }
        }
        default {
            error "Unknown core action: $action"
        }
    }

    return [dict create \
        server $server \
        target $target \
        device $device \
        axi_selector $axi_selector \
        plan $plan \
        action $action \
    ]
}

proc core_loader_session {session} {
    set action [dict get $session action]
    set plan [dict get $session plan]
    set selected [connect_selected_device [dict get $session server] \
        [dict get $session target] [dict get $session device]]
    refresh_hw_device $selected
    set axi [select_axi $selected [dict get $session axi_selector]]

    # Status/stop work before external memory is ready
    switch -- $action {
        status {
            set readiness [axi_read32 $axi [expr {$::XUP_SHELL_BASE + $::XUP_SHELL_READINESS_OFFSET}]]
            set features [axi_read32 $axi [expr {$::XUP_SHELL_BASE + $::XUP_SHELL_FEATURES_OFFSET}]]
            set fault [axi_read32 $axi [expr {$::XUP_SHELL_BASE + $::XUP_SHELL_FAULT_OFFSET}]]
            set control [axi_read32 $axi [expr {$::XUP_CORE_CSR_BASE + $::XUP_CORE_CSR_CONTROL_OFFSET}]]
            set status [axi_read32 $axi [expr {$::XUP_CORE_CSR_BASE + $::XUP_CORE_CSR_STATUS_OFFSET}]]
            set kind [expr {$features & 4 ? {VME} : ($features & 2 ? {RVV} : {scalar})}]
            puts "XUP_STATUS Core: $kind"
            puts "XUP_STATUS Reset: [expr {$control & (1 << $::XUP_CORE_CSR_RESET_BIT) ? {asserted} : {released}}]"
            puts "XUP_STATUS Clock: [expr {$control & 2 ? {gated} : {running}}]"
            puts "XUP_STATUS Memory: [expr {$readiness & 2 ? {ready} : {waiting for readiness}}]"
            puts "XUP_STATUS Execution: [expr {$status & 1 ? {halted} : {not halted}}]"
            puts "XUP_STATUS Fault: [expr {$fault || ($status & 2) ? {asserted} : {clear}}]"
            puts "XUP_STATUS Registers: readiness=$readiness features=$features control=[format 0x%08x $control] status=[format 0x%08x $status]"
        }
        stop {
            core_csr_write $axi $::XUP_CORE_CSR_CONTROL_OFFSET $::XUP_CORE_CSR_RESET_VALUE
            puts "XUP_CORE_CONTROL_RESULT [dict create state STOPPED control $::XUP_CORE_CSR_RESET_VALUE]"
        }
        load - run {
            core_wait_ready $axi
            core_load_stopped $axi $plan
            if {$action eq "run"} {
                core_start_loaded $axi $plan
            }
        }
    }
}

if {![info exists ::XUP_CORE_LOADER_LIBRARY] || !$::XUP_CORE_LOADER_LIBRARY} {
    # Validate load plan before opening hardware session
    if {[catch {set xup_loader_session [core_loader_prepare $argv]} message]} {
        puts stderr "CORE LOADER PREPARATION FAILED: $message"
        exit 1
    }
    hardware_entry {
        core_loader_session $xup_loader_session
    }
}
