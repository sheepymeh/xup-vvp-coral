# JTAG fabric clock/reset
create_bd_design $xup_bd_name

set fabric_clk [create_bd_port -dir I -type clk -freq_hz $XUP_FABRIC_HZ fabric_clk]
set_property CONFIG.FREQ_HZ $XUP_FABRIC_HZ $fabric_clk
set fabric_resetn [create_bd_port -dir I -type rst fabric_aresetn]
set_property CONFIG.POLARITY ACTIVE_LOW $fabric_resetn
set_property CONFIG.ASSOCIATED_RESET fabric_aresetn $fabric_clk

# JTAG AXI host interface
set jtag_axi [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_HOST]
set_property -dict [list \
    CONFIG.PROTOCOL AXI4 \
    CONFIG.DATA_WIDTH 32 \
    CONFIG.ADDR_WIDTH 32 \
    CONFIG.ID_WIDTH 1 \
    CONFIG.HAS_REGION 1 \
    CONFIG.HAS_QOS 1 \
    CONFIG.SUPPORTS_NARROW_BURST 1 \
    CONFIG.NUM_READ_OUTSTANDING 1 \
    CONFIG.NUM_WRITE_OUTSTANDING 1 \
] $jtag_axi
set_property CONFIG.ASSOCIATED_BUSIF S_AXI_HOST $fabric_clk
set jtag_address_space [get_bd_addr_spaces {S_AXI_HOST}]

# Route JTAG to status/core/external memory
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 jtag_interconnect
set_property -dict [list \
    CONFIG.NUM_SI 1 \
    CONFIG.NUM_MI 3 \
    CONFIG.NUM_CLKS 1 \
] [get_bd_cells {jtag_interconnect}]
create_bd_cell -type module -reference status_regs status

connect_bd_intf_net $jtag_axi [get_bd_intf_pins {jtag_interconnect/S00_AXI}]
connect_bd_intf_net [get_bd_intf_pins {jtag_interconnect/M00_AXI}] [get_bd_intf_pins {status/S_AXI}]
connect_bd_net \
    $fabric_clk \
    [get_bd_pins {jtag_interconnect/aclk}] \
    [get_bd_pins {status/aclk}]
connect_bd_net \
    $fabric_resetn \
    [get_bd_pins {jtag_interconnect/aresetn}] \
    [get_bd_pins {status/aresetn}]

# Status-register address map
assign_bd_address -offset $XUP_SHELL_BASE -range $XUP_SHELL_SIZE -target_address_space $jtag_address_space [get_bd_addr_segs {status/S_AXI/reg0}] -force
