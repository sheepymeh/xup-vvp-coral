# Production core sources
set core_sources [get_files -all */$XUP_CORE_MODULE.sv]
if {[llength $core_sources] != 1} {
    error "Expected exactly one core source: $core_sources"
}
set core_rtl_dir [file dirname [lindex $core_sources 0]]
set_property include_dirs [list $core_rtl_dir [file join $root_dir generated]] [current_fileset]

# JTAG AXI IP
create_ip -name jtag_axi -vendor xilinx.com -library ip -version 1.2 -module_name core_jtag_axi
set_property -dict [list \
    CONFIG.PROTOCOL AXI4 \
    CONFIG.M_AXI_DATA_WIDTH 32 \
    CONFIG.M_AXI_ADDR_WIDTH 32 \
    CONFIG.M_AXI_ID_WIDTH 1 \
] [get_ips {core_jtag_axi}]
# Keep RTL available for synthesis/elaboration
set_property generate_synth_checkpoint false [get_files {*/core_jtag_axi.xci}]
generate_target all [get_ips {core_jtag_axi}]
update_compile_order -fileset sources_1

# Core block design
source [file join $root_dir tcl setup create_core_bd.tcl]
