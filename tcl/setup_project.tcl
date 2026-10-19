# FuseSoC/Edalize entry point
source [file join [file dirname [info script]] project_context.tcl]

if {$XUP_FABRIC_HZ % 1000000 != 0} {
    error "Clock generator requires a whole-MHz fabric frequency"
}
if {$XUP_REFERENCE_HZ != 100000000} {
    error "Upstream UltraScale+ clock generator requires a 100 MHz reference"
}

# Add project sources
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property source_mgmt_mode All [current_project]
set_property include_dirs [list [file join $root_dir generated]] [current_fileset]
# Register generated SystemVerilog header for block-design parsing
add_files -norecurse [file join $root_dir generated memory_map.svh]

set_param general.maxThreads $XUP_BUILD_JOBS
set_param synth.maxThreads $XUP_BUILD_JOBS

if {$XUP_EXT_MEM eq "dram"} {
    # STARTUPE3 clock pins appear after linking
    set startup [get_files -quiet *dimm0_startup_timing.xdc]
    if {[llength $startup] != 1} {
        error "Expected 1 DIMM startup timing constraint"
    }
    set_property USED_IN_SYNTHESIS false $startup
    set_property USED_IN_IMPLEMENTATION true $startup
}

set pending_gate [open [file join $report_dir build_gates.txt] w]
puts $pending_gate "result=NOT_RUN"
close $pending_gate

# Add core design/synthesis hook
source [file join $root_dir tcl setup create_core_design.tcl]
set_property top xup_core_top [current_fileset]
update_compile_order -fileset sources_1
set_property STEPS.SYNTH_DESIGN.TCL.POST [file join $root_dir tcl synthesis synthesis.tcl] [get_runs {synth_1}]
if {$XUP_BUILD_PROFILE eq "debug"} {
    set_property STRATEGY Flow_RuntimeOptimized [get_runs {synth_1}]
}

# Write build-configuration reports
report_ip_status -file [file join $report_dir ip_status.rpt]
write_bd_tcl -force [file join $report_dir ${xup_bd_name}_generated.tcl]
set configuration [open [file join $report_dir build_configuration.txt] w]
puts $configuration "core=$XUP_CORE_TYPE\npcie=$XUP_PCIE\next_mem=$XUP_EXT_MEM\nexternal_bytes=$XUP_EXTERNAL_SIZE\njobs=$XUP_BUILD_JOBS\npart=$XUP_FPGA_PART\nvivado=[version -short]\nreference_hz=$XUP_REFERENCE_HZ\nfabric_hz=$XUP_FABRIC_HZ\nproject_file=[current_project].xpr"
foreach ip [get_ips] {
    puts $configuration "ip=[get_property NAME $ip] vlnv=[get_property IPDEF $ip]"
}
foreach bank $XUP_EXTMEM_BANKS {
    puts $configuration "extmem_bank=$bank"
}
puts $configuration "profile=$XUP_BUILD_PROFILE\nsynthesis_strategy=[get_property STRATEGY [get_runs {synth_1}]]"
if {$XUP_PCIE_ENABLED} {
    puts $configuration "pcie_lanes=$XUP_PCIE_LANES\npcie_axi_bits=$XUP_PCIE_AXI_BITS\npcie_axi_mhz=$XUP_PCIE_AXI_MHZ"
}
close $configuration
