# Settings shared by project setup/run hooks
set root_dir [file normalize [file join [file dirname [info script]] ..]]
source [file join $root_dir tcl utils.tcl]
source [file join $root_dir config board.tcl]
source [file join $root_dir config build_settings.tcl]
source [file join $root_dir generated memory_map.tcl]

# RVV/VME cores both include RVV
set XUP_RVV_ENABLED [expr {$XUP_CORE_TYPE ne "scalar"}]
set XUP_VME_ENABLED [expr {$XUP_CORE_TYPE eq "vme"}]
if {$XUP_CORE_TYPE eq "scalar"} {
    set XUP_FABRIC_HZ $XUP_SCALAR_FABRIC_HZ
} elseif {$XUP_VME_ENABLED} {
    set XUP_FABRIC_HZ $XUP_VME_FABRIC_HZ
}

set XUP_PCIE_ENABLED [expr {$XUP_PCIE ne "none"}]
if {$XUP_PCIE_ENABLED} {
    source [file join $root_dir config pcie_xdma.tcl]
}

# Read run outputs from FuseSoC's exported source tree
set xup_work_dir [file normalize [file join $root_dir .. .. ..]]
set release_dir [file join $xup_work_dir release]
set report_dir [file join $xup_work_dir reports]

# External memory banks
source [file join $root_dir tcl setup extmem_backend.tcl]
if {[extmem_backend::is_onchip $XUP_EXT_MEM]} {
    set XUP_EXTMEM_BANKS [extmem_backend::onchip::split_aligned_banks $XUP_EXTERNAL_BASE \
        $XUP_EXT_MEM $XUP_EXTERNAL_SIZE]
} else {
    set XUP_EXTMEM_BANKS [list [dict create \
        kind $XUP_EXT_MEM \
        prefix extmem \
        base $XUP_EXTERNAL_BASE \
        size $XUP_EXTERNAL_SIZE\
    ]]
    if {$XUP_EXT_MEM eq "dram"} {
        source [file join $root_dir config dimm0_mig.tcl]
    }
}

file mkdir $release_dir $report_dir
