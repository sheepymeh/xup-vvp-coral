# XDMA host access to external memory
namespace eval xup_pcie {}

proc xup_pcie::attach {} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.2 pcie_xdma
    set_property -dict $::XUP_PCIE_XDMA_SETTINGS [get_bd_cells {pcie_xdma}]

    # Connect lane/reference-clock/reset ports
    xup_external_interface pcie_xdma/pcie_mgt pci_exp
    foreach port_name {sys_clk sys_clk_gt sys_rst_n} {
        set port [create_bd_port -dir I $port_name]
        connect_bd_net \
            $port \
            [get_bd_pins pcie_xdma/$port_name]
    }

    # Cross from XDMA clock to NPU fabric clock
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 pcie_clock_converter
    set_property -dict [list \
        CONFIG.PROTOCOL AXI4 \
        CONFIG.DATA_WIDTH $::XUP_PCIE_AXI_BITS \
        CONFIG.ADDR_WIDTH 64 \
        CONFIG.ACLK_ASYNC 1 \
    ] [get_bd_cells {pcie_clock_converter}]
    connect_bd_intf_net [get_bd_intf_pins {pcie_xdma/M_AXI}] [get_bd_intf_pins {pcie_clock_converter/S_AXI}]
    set fabric_axi_master pcie_clock_converter/M_AXI

    # Convert width between XDMA/fabric buses
    if {$::XUP_PCIE_AXI_BITS != 128} {
        create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dwidth_converter:2.1 pcie_width_converter
        set_property -dict [list \
            CONFIG.PROTOCOL AXI4 \
            CONFIG.SI_DATA_WIDTH $::XUP_PCIE_AXI_BITS \
            CONFIG.MI_DATA_WIDTH 128 \
            CONFIG.ADDR_WIDTH 64 \
            CONFIG.READ_WRITE_MODE READ_WRITE \
        ] [get_bd_cells {pcie_width_converter}]
        connect_bd_intf_net [get_bd_intf_pins $fabric_axi_master] [get_bd_intf_pins {pcie_width_converter/S_AXI}]
        connect_bd_net \
            [get_bd_ports {fabric_clk}] \
            [get_bd_pins {pcie_width_converter/s_axi_aclk}]
        connect_bd_net \
            [get_bd_ports {fabric_aresetn}] \
            [get_bd_pins {pcie_width_converter/s_axi_aresetn}]
        set fabric_axi_master pcie_width_converter/M_AXI
    }

    connect_bd_intf_net [get_bd_intf_pins $fabric_axi_master] [get_bd_intf_pins {extmem_interconnect/S02_AXI}]
    connect_bd_net \
        [get_bd_pins {pcie_xdma/axi_aclk}] \
        [get_bd_pins {pcie_clock_converter/s_axi_aclk}]
    connect_bd_net \
        [get_bd_pins {pcie_xdma/axi_aresetn}] \
        [get_bd_pins {pcie_clock_converter/s_axi_aresetn}]
    connect_bd_net \
        [get_bd_ports {fabric_clk}] \
        [get_bd_pins {pcie_clock_converter/m_axi_aclk}]
    connect_bd_net \
        [get_bd_ports {fabric_aresetn}] \
        [get_bd_pins {pcie_clock_converter/m_axi_aresetn}]

    # Share external memory address map with core/JTAG
    return [get_bd_addr_spaces {pcie_xdma/M_AXI}]
}
