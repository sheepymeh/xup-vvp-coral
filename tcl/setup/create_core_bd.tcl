# Connect shell/external memory to CoralNPU
set xup_bd_name core_bd
source [file join $root_dir tcl setup create_jtag_fabric.tcl]
set_property CONFIG.FEATURES \
    [expr {1 | ($XUP_RVV_ENABLED << 1) | ($XUP_VME_ENABLED << 2)}] \
    [get_bd_cells {status}]

# Boot from ITCM. Disable external interrupts/debug requests
create_bd_cell -type module -reference core_mini_axi core
foreach {name width value} {
    core_zero 1 0
    core_zero_op 2 0
    core_zero_word 32 0
    core_one 1 1
} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 $name
    set_property -dict [list CONFIG.CONST_WIDTH $width CONFIG.CONST_VAL $value] [get_bd_cells $name]
}
connect_bd_net \
    [get_bd_pins {core_zero/dout}] \
    [get_bd_pins {core/irq}] \
    [get_bd_pins {core/timer_irq}] \
    [get_bd_pins {core/software_irq}] \
    [get_bd_pins {core/dm_req_valid}] \
    [get_bd_pins {core/te}]
connect_bd_net \
    [get_bd_pins {core_zero_op/dout}] \
    [get_bd_pins {core/dm_req_op}]
connect_bd_net \
    [get_bd_pins {core_zero_word/dout}] \
    [get_bd_pins {core/boot_addr}] \
    [get_bd_pins {core/dm_req_address}] \
    [get_bd_pins {core/dm_req_data}]
connect_bd_net \
    [get_bd_pins {core_one/dout}] \
    [get_bd_pins {core/dm_rsp_ready}]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 jtag_core_width_converter
# PACKING_LEVEL 0: CSR interface depends on write addresses
set_property -dict [list \
    CONFIG.ACLK_ASYNC 0 \
    CONFIG.ADDR_WIDTH 32 \
    CONFIG.FIFO_MODE 0 \
    CONFIG.MI_DATA_WIDTH 128 \
    CONFIG.PACKING_LEVEL 0 \
    CONFIG.PROTOCOL AXI4 \
    CONFIG.READ_WRITE_MODE READ_WRITE \
    CONFIG.SI_DATA_WIDTH 32 \
    CONFIG.SI_ID_WIDTH 6 \
] [get_bd_cells {jtag_core_width_converter}]

# Arbitrate external memory access between core/JTAG/XDMA
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 extmem_interconnect
set bank_count [llength $XUP_EXTMEM_BANKS]
set_property -dict [list \
    CONFIG.NUM_SI [expr {$XUP_PCIE_ENABLED ? 3 : 2}] \
    CONFIG.NUM_MI $bank_count \
    CONFIG.NUM_CLKS 1 \
] [get_bd_cells {extmem_interconnect}]
set extmem_banks {}
foreach bank $XUP_EXTMEM_BANKS {
    set memory_bank [extmem_backend::create_bank [dict get $bank kind] [dict get $bank prefix] 128 [dict get $bank size]]
    dict set memory_bank base [dict get $bank base]
    set index [llength $extmem_banks]
    connect_bd_intf_net [get_bd_intf_pins [format extmem_interconnect/M%02d_AXI $index]] [dict get $memory_bank axi]
    connect_bd_net [get_bd_ports {fabric_clk}] {*}[dict get $memory_bank clock_pins]
    connect_bd_net [get_bd_ports {fabric_aresetn}] {*}[dict get $memory_bank reset_pins]
    lappend extmem_banks $memory_bank
}
# On-chip banks share fabric reset and become ready together
connect_bd_net [dict get [lindex $extmem_banks 0] ready_pin] [get_bd_pins {status/extmem_ready}]

# Host-to-width converter
connect_bd_intf_net [get_bd_intf_pins {jtag_interconnect/M01_AXI}] [get_bd_intf_pins {jtag_core_width_converter/S_AXI}]
# Width converter to core (ITCM/DTCM/CSR)
connect_bd_intf_net [get_bd_intf_pins {jtag_core_width_converter/M_AXI}] [get_bd_intf_pins {core/S_AXI}]
# Host-to-external memory path
connect_bd_intf_net [get_bd_intf_pins {jtag_interconnect/M02_AXI}] [get_bd_intf_pins {extmem_interconnect/S00_AXI}]
# Core-to-external memory path
connect_bd_intf_net [get_bd_intf_pins {core/M_AXI}] [get_bd_intf_pins {extmem_interconnect/S01_AXI}]
# JTAG AXI enters top through S_AXI_HOST
set extmem_address_spaces [list [get_bd_addr_spaces {S_AXI_HOST}] [get_bd_addr_spaces {core/M_AXI}]]
if {$XUP_PCIE_ENABLED} {
    source [file join $root_dir tcl setup pcie_host.tcl]
    lappend extmem_address_spaces [xup_pcie::attach]
}

# Connect clock/reset/fault signals
connect_bd_net \
    [get_bd_ports {fabric_clk}] \
    [get_bd_pins {core/aclk}] \
    [get_bd_pins {jtag_core_width_converter/s_axi_aclk}] \
    [get_bd_pins {extmem_interconnect/aclk}]
connect_bd_net \
    [get_bd_ports {fabric_aresetn}] \
    [get_bd_pins {core/aresetn}] \
    [get_bd_pins {jtag_core_width_converter/s_axi_aresetn}] \
    [get_bd_pins {extmem_interconnect/aresetn}]
connect_bd_net \
    [get_bd_pins {core/fault}] \
    [get_bd_pins {status/core_fault}]

# Pass global memory addresses through fabric without translation
set jtag_address_space [get_bd_addr_spaces {S_AXI_HOST}]
set core_address_space [get_bd_addr_spaces {core/M_AXI}]
if {[llength $jtag_address_space] != 1 || [llength $core_address_space] != 1} {
    error "Expected one host/core manager address space. Found host='$jtag_address_space' core='$core_address_space' available='[get_bd_addr_spaces]'"
}
set core_segment [get_bd_addr_segs {core/S_AXI/reg0}]
# Core internal-memory regions
foreach {name base size} [list \
    itcm $XUP_ITCM_BASE $XUP_ITCM_SIZE \
    dtcm $XUP_DTCM_BASE $XUP_DTCM_SIZE \
    csr $XUP_CORE_CSR_BASE $XUP_CORE_CSR_SIZE \
] {
    create_bd_addr_seg -range $size -offset $base $jtag_address_space $core_segment SEG_core_$name
}
# External memory region
foreach memory_bank $extmem_banks {
    foreach space $extmem_address_spaces {
        assign_bd_address -offset [dict get $memory_bank base] -range [dict get $memory_bank capacity_bytes] \
            -target_address_space $space [dict get $memory_bank address_segment] -force
    }
}

validate_bd_design
save_bd_design
set bd_file [get_files -quiet */core_bd.bd]
# Expose generated IP RTL to shared build-rule elaboration
set_property synth_checkpoint_mode None $bd_file
generate_target all $bd_file
set wrappers [make_wrapper -files $bd_file -top]
add_files -norecurse $wrappers
