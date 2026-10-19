# Link-specific width/clock
switch -- $XUP_PCIE {
    gen3x16 {
        set XUP_PCIE_LANES 16
        set XUP_PCIE_SPEED 8.0_GT/s
        set XUP_PCIE_AXI_BITS 512
        set XUP_PCIE_AXI_MHZ 250
    }
    gen2x4 {
        set XUP_PCIE_LANES 4
        set XUP_PCIE_SPEED 5.0_GT/s
        # Match 128-bit NPU fabric width
        set XUP_PCIE_AXI_BITS 128
        set XUP_PCIE_AXI_MHZ 125
    }
    default {
        error "Unknown PCIe link configuration: $XUP_PCIE"
    }
}

# Shared XDMA settings
set XUP_PCIE_XDMA_SETTINGS [list \
    CONFIG.axi_data_width ${XUP_PCIE_AXI_BITS}_bit \
    CONFIG.axisten_freq $XUP_PCIE_AXI_MHZ \
    CONFIG.device_port_type PCI_Express_Endpoint_device \
    CONFIG.en_gt_selection true \
    CONFIG.functional_mode DMA \
    CONFIG.mode_selection Advanced \
    CONFIG.pcie_blk_locn X0Y1 \
    CONFIG.pf0_device_id 9031 \
    CONFIG.pl_link_cap_max_link_speed $XUP_PCIE_SPEED \
    CONFIG.pl_link_cap_max_link_width X$XUP_PCIE_LANES \
    CONFIG.ref_clk_freq 100_MHz \
    CONFIG.select_quad GTY_Quad_227 \
    CONFIG.sys_reset_polarity ACTIVE_LOW \
    CONFIG.vendor_id 10EE \
    CONFIG.xdma_axi_intf_mm AXI_Memory_Mapped \
    CONFIG.xdma_rnum_chnl 1 \
    CONFIG.xdma_wnum_chnl 1 \
]
