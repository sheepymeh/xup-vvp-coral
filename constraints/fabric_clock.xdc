# Si5341-B OUT5, 100 MHz LVDS, bank 64 at 1.8 V
set_property PACKAGE_PIN AV22 [get_ports {fabric_refclk_p}]
set_property PACKAGE_PIN AV21 [get_ports {fabric_refclk_n}]
set_property IOSTANDARD LVDS [get_ports {fabric_refclk_p fabric_refclk_n}]
set_property DIFF_TERM_ADV TERM_100 [get_ports {fabric_refclk_p}]
create_clock -name fabric_refclk -period 10.000 [get_ports {fabric_refclk_p}]
