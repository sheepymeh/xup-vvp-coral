# Vivado implementation run-hook procedures
namespace eval xup_implementation {}

proc xup_implementation::configure_implementation {} {
    global root_dir XUP_VME_ENABLED XUP_BUILD_PROFILE

    if {$XUP_BUILD_PROFILE eq "debug"} {
        set_property STRATEGY Flow_Quick [get_runs {impl_1}]
    } elseif {$XUP_VME_ENABLED} {
        # Upstream Nexus VME directives, excluding board-specific pblocks
        set_property -name {STEPS.OPT_DESIGN.ARGS.MORE OPTIONS} -value {-muxf_remap} -objects [get_runs {impl_1}]
        set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE SSI_BalanceSLRs [get_runs {impl_1}]
        set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs {impl_1}]
        set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE ExploreWithAggressiveHoldFix [get_runs {impl_1}]
        set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE MoreGlobalIterations [get_runs {impl_1}]
        set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs {impl_1}]
        set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs {impl_1}]
    }

    # Apply options/hooks after strategy setup, which resets run properties
    set_property -name {STEPS.PLACE_DESIGN.ARGS.MORE OPTIONS} -value {-ultrathreads} -objects [get_runs {impl_1}]
    set_property -name {STEPS.ROUTE_DESIGN.ARGS.MORE OPTIONS} -value {-ultrathreads} -objects [get_runs {impl_1}]

    foreach {property script} {
        STEPS.OPT_DESIGN.TCL.PRE implementation/finalize_synth.tcl
        STEPS.OPT_DESIGN.TCL.POST implementation/apply_incremental.tcl
        STEPS.PLACE_DESIGN.TCL.PRE implementation/prepare_placement.tcl
        STEPS.ROUTE_DESIGN.TCL.PRE implementation/optimize_pcie_reset.tcl
        STEPS.ROUTE_DESIGN.TCL.POST implementation/check_route.tcl
        STEPS.WRITE_BITSTREAM.TCL.PRE implementation/check_bitstream.tcl
        STEPS.WRITE_BITSTREAM.TCL.POST implementation/capture_release.tcl
    } {
        set_property $property [file join $root_dir tcl $script] [get_runs {impl_1}]
    }
    puts "XUP_IMPLEMENTATION_PROFILE $XUP_BUILD_PROFILE strategy=[get_property STRATEGY [get_runs {impl_1}]]"
}

proc xup_implementation::finalize_synth {} {
    global root_dir XUP_FABRIC_HZ

    # Check pins/configure JTAG debug hub after linking
    source [file join $root_dir upstream fpga check_pin_assignments.tcl]
    set hub [get_debug_cores {dbg_hub}]
    if {[llength $hub] != 1} {
        error "Expected one Vivado JTAG debug hub"
    }
    set_property C_CLK_INPUT_FREQ_HZ $XUP_FABRIC_HZ $hub
    set_property C_ENABLE_CLK_DIVIDER false $hub
    connect_debug_port dbg_hub/clk [get_nets {fabric_clk}]
}

proc xup_implementation::apply_incremental {} {
    global xup_work_dir report_dir XUP_CORE_TYPE XUP_FPGA_PART XUP_FABRIC_HZ

    set checkpoint [file join $xup_work_dir incremental latest.dcp]
    set configuration [file join $xup_work_dir incremental latest.txt]
    if {![file isfile $checkpoint] || ![file isfile $configuration]} {
        puts "XUP_INCREMENTAL full implementation, no reference selected"
        return
    }

    set stream [open $configuration r]
    set settings {}
    foreach line [split [read $stream] \n] {
        if {[regexp {^([^=]+)=(.*)$} $line match key value]} {
            dict set settings $key $value
        }
    }
    close $stream
    foreach {key expected} [list core $XUP_CORE_TYPE part $XUP_FPGA_PART vivado [version -short] fabric_hz $XUP_FABRIC_HZ] {
        if {![dict exists $settings $key] || [dict get $settings $key] ne $expected} {
            puts "XUP_INCREMENTAL full implementation, incompatible reference $key (expected $expected)"
            return
        }
    }

    puts "XUP_INCREMENTAL reference=$checkpoint directive=RuntimeOptimized"
    read_checkpoint -incremental -auto_incremental -directive RuntimeOptimized $checkpoint
    set ::XUP_INCREMENTAL_LOADED 1
    report_incremental_reuse -quiet -file [file join $report_dir incremental_initial.rpt]
}

proc xup_implementation::prepare_placement {} {
    global XUP_EXT_MEM XUP_VME_ENABLED

    if {$XUP_EXT_MEM ne "dram" || !$XUP_VME_ENABLED} {
        return
    }

    # Reserve DIMM0 clock regions X4Y5-X4Y7 for MIG
    set region [create_pblock pblock_dimm0_mig]
    resize_pblock $region -add {
        SLICE_X117Y300:SLICE_X145Y479
        RAMB18_X8Y120:RAMB18_X9Y191
        RAMB36_X8Y60:RAMB36_X9Y95
        DSP48E2_X16Y120:DSP48E2_X19Y191
    }
    add_cells_to_pblock $region [get_cells {fabric/core_bd_i/extmem_mig}]
    set_property -dict {IS_SOFT false EXCLUDE_PLACEMENT true CONTAIN_ROUTING false} $region
}

proc xup_implementation::optimize_pcie_reset {} {
    global XUP_PCIE_ENABLED

    if {!$XUP_PCIE_ENABLED} {
        return
    }

    # Replicate distribution stage, preserve preceding reset synchronizer
    set driver [get_cells -hier -filter {NAME =~ */diablo_gt.diablo_gt_phy_wrapper/rst_psrst_n_r_rep_reg}]
    if {[llength $driver] != 1} {
        error "Expected one PCIe PHY reset distribution register"
    }
    # Incremental references can replay physical replication
    set replicas [get_cells -hier -quiet -filter {NAME =~ */diablo_gt.diablo_gt_phy_wrapper/rst_psrst_n_r_rep_reg_replica*}]
    if {[llength $replicas]} {
        return
    }
    set output [get_pins -of_objects $driver -filter {REF_PIN_NAME == Q}]
    set net [get_nets -top_net_of_hierarchical_group -segments -of_objects $output]
    phys_opt_design -force_replication_on_nets $net
}

proc xup_implementation::timing_metrics {report_path} {
    set stream [open $report_path r]
    set report [read $stream]
    close $stream

    # Read timing summary/validate numeric columns
    set header_seen 0
    foreach line [split $report \n] {
        if {[regexp {WNS\(ns\).*TNS\(ns\).*WHS\(ns\).*THS\(ns\)} $line]} {
            set header_seen 1
            continue
        }
        if {!$header_seen} {
            continue
        }

        set columns [regexp -all -inline {\S+} $line]
        if {[llength $columns] < 12} {
            continue
        }

        set valid 1
        foreach index {0 1 4 5 8 9} {
            if {![string is double -strict [lindex $columns $index]]} {
                set valid 0
            }
        }
        foreach index {2 3 6 7 10 11} {
            if {![string is entier -strict [lindex $columns $index]]} {
                set valid 0
            }
        }
        if {$valid} {
            return [dict create \
                WNS [lindex $columns 0] \
                TNS [lindex $columns 1] \
                WHS [lindex $columns 4] \
                THS [lindex $columns 5] \
                WPWS [lindex $columns 8] \
                TPWS [lindex $columns 9] \
            ]
        }
    }

    return {}
}

proc xup_implementation::check_route {} {
    # Check routing completeness
    set route [report_route_status -return_string]
    set counts {}
    foreach {label pattern} {
        routable {# of routable nets[^:]*:\s*(\d+)}
        routed {# of fully routed nets[^:]*:\s*(\d+)}
        errors {# of nets with routing errors[^:]*:\s*(\d+)}
    } {
        if {![regexp -nocase -line $pattern $route match count]} {
            error "Cannot parse route status: $label"
        }
        dict set counts $label $count
    }
    if {[dict get $counts errors] != 0 || [dict get $counts routed] != [dict get $counts routable]} {
        error "Incomplete or invalid routing: $counts"
    }
    check_blackboxes implementation
}

proc xup_implementation::write_reports {} {
    global report_dir
    set prefix [file join $report_dir xup_coral]
    report_timing_summary -report_unconstrained -max_paths 20 -file "${prefix}_routed_timing.rpt"
    report_route_status -file "${prefix}_routed_status.rpt"
    if {[info exists ::XUP_INCREMENTAL_LOADED]} {
        report_incremental_reuse -quiet -file [file join $report_dir incremental_routed.rpt]
    }

    report_drc -file [file join $report_dir drc.rpt]
    report_utilization -file [file join $report_dir utilization.rpt]
    report_clock_utilization -file [file join $report_dir clocks.rpt]
    report_cdc -details -file [file join $report_dir cdc.rpt]
    report_exceptions -file [file join $report_dir exceptions.rpt]
    check_timing -verbose -file [file join $report_dir check_timing.rpt]
}

proc xup_implementation::check_bitstream {} {
    global report_dir

    # Recheck timing after post-route optimization
    check_route
    write_reports
    set gate [open [file join $report_dir build_gates.txt] w]
    set failed {}

    # Read current-design timing because child hooks lack parent run statistics
    set metrics [timing_metrics [file join $report_dir xup_coral_routed_timing.rpt]]
    foreach label {WNS TNS WHS THS WPWS TPWS} {
        set value [expr {[dict exists $metrics $label] ? [dict get $metrics $label] : {UNPARSED}}]
        puts $gate "$label=$value"
        if {![string is double -strict $value] || $value < 0} {
            lappend failed "$label=$value"
        }
    }

    # Report worst setup/hold paths
    foreach delay {max min} {
        set path [get_timing_paths -delay_type $delay -max_paths 1 -nworst 1]
        if {![llength $path]} {
            lappend failed "No $delay timing paths"
        } else {
            set slack [get_property SLACK $path]
            puts $gate "worst_${delay}_slack=$slack"
            if {![string is double -strict $slack] || $slack < 0} {
                lappend failed "$delay slack=$slack"
            }
        }
    }

    # Report critical DRCs
    set drcs [get_drc_violations -filter {SEVERITY == Error || SEVERITY == {Critical Warning}}]
    puts $gate "critical_drc_count=[llength $drcs]"
    if {[llength $drcs]} {
        lappend failed "Critical DRCs: $drcs"
    }

    # Report unconstrained clocks, endpoints/I/O
    set timing_file [open [file join $report_dir check_timing.rpt] r]
    set checks [read $timing_file]
    close $timing_file
    foreach check {no_clock constant_clock unconstrained_internal_endpoints no_input_delay no_output_delay multiple_clock generated_clocks loops partial_input_delay partial_output_delay latch_loops} {
        switch -- $check {
            no_input_delay {
                # Exclude false-pathed inputs such as async PCIe PERST
                set pattern {There (?:are|is) ([0-9]+) input ports? with no input delay specified\.}
            }
            no_output_delay {
                # Exclude false-pathed outputs such as DIMM RESET_n
                set pattern {There (?:are|is) ([0-9]+) ports? with no output delay specified\.}
            }
            default {
                set pattern [format {checking %s \(([0-9]+)\)} $check]
            }
        }
        if {![regexp $pattern $checks match count]} {
            lappend failed "Unparsed timing check $check"
        } else {
            puts $gate "$check=$count"
            if {$count != 0} {
                lappend failed "$check=$count"
            }
        }
    }

    # Report AXI CDC FIFO bus-skew constraints
    set skew_path [file join $report_dir bus_skew_routed.rpt]
    report_bus_skew -file $skew_path
    set skew_file [open $skew_path r]
    set skew_report [read $skew_file]
    close $skew_file
    set skews [regexp -all -inline {Slack \((MET|VIOLATED)\)\s*:\s*(\S+)ns} $skew_report]
    if {![llength $skews]} {
        lappend failed "No reported bus-skew constraints"
    }
    foreach {match state slack} $skews {
        if {$state ne "MET" || ![string is double -strict $slack] || $slack < 0} {
            lappend failed "Bus-skew constraint: $state $slack ns"
        }
    }

    puts $gate "bus_skew_constraints=[expr {[llength $skews] / 3}]"
    puts $gate "result=[expr {[llength $failed] ? {FAIL} : {PASS}}]"
    puts $gate "failures=$failed"
    close $gate
    if {[llength $failed]} {
        error "Build gates failed: $failed"
    }
}

proc xup_implementation::capture_release {} {
    global release_dir

    # Write release artifacts
    file copy -force xup_core_top.bit [file join $release_dir xup_coral.bit]
    write_checkpoint -force [file join $release_dir xup_coral_routed.dcp]
    write_debug_probes -force [file join $release_dir xup_coral.ltx]
    puts "BUILD PASS: [file join $release_dir xup_coral.bit]"
}
