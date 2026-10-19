# Implementation only. STARTUPE3 is inside the xup_ddr4_powerup_reset OOC
# module, so its internal pins are unavailable during top-level synthesis
create_clock -name startup_cfgmclk -period 20.000 [get_pins -hierarchical -filter {REF_PIN_NAME == CFGMCLK}]

# Calibration status crosses from MIG to fabric clock domain
# Exempt first synchronizer stage/time the stage-to-stage path
set_false_path -to [get_pins -hierarchical -regexp {.*extmem_ddr4_ready_sync/inst/ready_pipe_reg\[0\]/D}]

# DIMM RESET_n is an asynchronous initialization signal
set_false_path -to [get_ports {C0_DDR4_0_reset_n}]
