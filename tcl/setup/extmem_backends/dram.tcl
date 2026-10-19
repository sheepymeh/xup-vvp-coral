# DIMM0 DDR4 interface with 128-bit AXI fabric port
namespace eval extmem_backend::dram {}

proc extmem_backend::dram::create_bank {prefix data_bits capacity_bytes} {
    if {$data_bits != 128} {
        error "Expected 128-bit CoreMiniAxi fabric"
    }

    # Configure MIG
    set mig ${prefix}_mig
    create_bd_cell -type ip -vlnv xilinx.com:ip:ddr4:2.2 $mig
    xup_dimm_configure [get_bd_cells $mig]

    # Use MIG AXI width independently of DIMM data-bus width
    set mig_data_bits [get_property CONFIG.DATA_WIDTH [get_bd_intf_pins $mig/C0_DDR4_S_AXI]]
    if {![string is integer -strict $mig_data_bits] || $mig_data_bits < 32 || ($mig_data_bits & ($mig_data_bits - 1)) != 0} {
        error "MIG C0_DDR4_S_AXI returned unexpected AXI data width '$mig_data_bits'"
    }

    # Cross into MIG clock domain/convert width
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 ${prefix}_clock_converter
    set_property -dict [list \
        CONFIG.PROTOCOL AXI4 \
        CONFIG.DATA_WIDTH 128 \
        CONFIG.ACLK_ASYNC 1 \
    ] [get_bd_cells ${prefix}_clock_converter]

    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 ${prefix}_width_converter
    set_property -dict [list \
        CONFIG.PROTOCOL AXI4 \
        CONFIG.SI_DATA_WIDTH 128 \
        CONFIG.MI_DATA_WIDTH $mig_data_bits \
        CONFIG.READ_WRITE_MODE READ_WRITE \
    ] [get_bd_cells ${prefix}_width_converter]

    connect_bd_intf_net [get_bd_intf_pins ${prefix}_clock_converter/M_AXI] [get_bd_intf_pins ${prefix}_width_converter/S_AXI]
    connect_bd_intf_net [get_bd_intf_pins ${prefix}_width_converter/M_AXI] [get_bd_intf_pins $mig/C0_DDR4_S_AXI]
    connect_bd_net \
        [get_bd_pins $mig/c0_ddr4_ui_clk] \
        [get_bd_pins ${prefix}_clock_converter/m_axi_aclk] \
        [get_bd_pins ${prefix}_width_converter/s_axi_aclk]

    # Handle power-up reset/DCI calibration
    create_bd_cell -type module -reference xup_ddr4_powerup_reset ${prefix}_powerup_reset
    connect_bd_net \
        [get_bd_pins ${prefix}_powerup_reset/sys_rst] \
        [get_bd_pins $mig/sys_rst]

    # Use UI reset for MIG AXI. Gating on calibration can deadlock
    create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 ${prefix}_ui_reset
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 ${prefix}_constant_one
    set_property -dict [list \
        CONFIG.CONST_WIDTH 1 \
        CONFIG.CONST_VAL 1 \
    ] [get_bd_cells ${prefix}_constant_one]
    connect_bd_net \
        [get_bd_pins $mig/c0_ddr4_ui_clk] \
        [get_bd_pins ${prefix}_ui_reset/slowest_sync_clk]
    connect_bd_net \
        [get_bd_pins $mig/c0_ddr4_ui_clk_sync_rst] \
        [get_bd_pins ${prefix}_ui_reset/ext_reset_in]
    connect_bd_net \
        [get_bd_pins ${prefix}_constant_one/dout] \
        [get_bd_pins ${prefix}_ui_reset/dcm_locked]
    connect_bd_net \
        [get_bd_pins ${prefix}_ui_reset/peripheral_aresetn] \
        [get_bd_pins $mig/c0_ddr4_aresetn] \
        [get_bd_pins ${prefix}_clock_converter/m_axi_aresetn] \
        [get_bd_pins ${prefix}_width_converter/s_axi_aresetn]

    # Synchronize calibration status into fabric domain
    create_bd_cell -type module -reference ddr4_ready_sync ${prefix}_ddr4_ready_sync
    connect_bd_net \
        [get_bd_ports {fabric_clk}] \
        [get_bd_pins ${prefix}_ddr4_ready_sync/clk]
    connect_bd_net \
        [get_bd_ports {fabric_aresetn}] \
        [get_bd_pins ${prefix}_ddr4_ready_sync/resetn]
    connect_bd_net \
        [get_bd_pins $mig/c0_init_calib_complete] \
        [get_bd_pins ${prefix}_ddr4_ready_sync/async_calib_complete]

    # Connect DIMM0 pins/reference clock
    xup_external_interface $mig/C0_DDR4 C0_DDR4_0
    set refclk [xup_external_interface $mig/C0_SYS_CLK dimm0_refclk]
    set_property CONFIG.FREQ_HZ 100000000 $refclk

    set segments [get_bd_addr_segs -of_objects [get_bd_intf_pins $mig/C0_DDR4_S_AXI]]
    if {[llength $segments] != 1} {
        error "Expected exactly one MIG AXI address segment: $segments"
    }

    return [dict create \
        address_segment [lindex $segments 0] \
        axi [get_bd_intf_pins ${prefix}_clock_converter/S_AXI] \
        capacity_bytes $capacity_bytes \
        clock_pins [list [get_bd_pins ${prefix}_clock_converter/s_axi_aclk]] \
        data_bits $data_bits \
        ready_pin [get_bd_pins ${prefix}_ddr4_ready_sync/ready] \
        reset_pins [list [get_bd_pins ${prefix}_clock_converter/s_axi_aresetn]] \
    ]
}
