# XDMA CONFIG.pcie_blk_locn/select_quad control GT placement
set_property PACKAGE_PIN AT11 [get_ports {sys_clk_p}]
set_property PACKAGE_PIN AT10 [get_ports {sys_clk_n}]
create_clock -name pcie_refclk -period 10.000 [get_ports {sys_clk_p}]

# PERST shares DIMM I/O supply (1.2 V, bank 65)
set_property -dict {PACKAGE_PIN AP26 IOSTANDARD LVCMOS12 PULLUP true} [get_ports {sys_rst_n}]
set_false_path -from [get_ports {sys_rst_n}]
