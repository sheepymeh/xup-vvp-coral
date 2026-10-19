# Example profile. Match timing to installed module

proc xup_dimm_configure {cell} {
    set csv_files [get_files -all -quiet *BLS4G4D240FSB.csv]
    if {[llength $csv_files] != 1} {
        error "Missing DIMM profile: config/dimm_parts/BLS4G4D240FSB.csv"
    }

    set_property -dict [list \
        CONFIG.C0.DDR4_AxiNarrowBurst true \
        CONFIG.C0.DDR4_CLKOUT0_DIVIDE 5 \
        CONFIG.C0.DDR4_CustomParts [lindex $csv_files 0] \
        CONFIG.C0.DDR4_DataWidth 64 \
        CONFIG.C0.DDR4_InputClockPeriod 9996 \
        CONFIG.C0.DDR4_isCustom true \
        CONFIG.C0.DDR4_MemoryPart BLS4G4D240FSB-2400 \
        CONFIG.C0.DDR4_MemoryType UDIMMs \
        CONFIG.C0.DDR4_TimePeriod 833 \
    ] $cell
}
