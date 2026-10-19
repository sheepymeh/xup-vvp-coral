# AXI BRAM/UltraRAM banks
namespace eval extmem_backend::onchip {}

# Split memory into aligned banks within BMG limits
proc extmem_backend::onchip::split_aligned_banks {base kind remaining} {
    if {![::extmem_backend::is_onchip $kind]} {
        error "Unknown on-chip backend: $kind"
    }
    if {$base % 4096 != 0} {
        error "On-chip memory base not aligned to 4 KiB"
    }
    if {$remaining <= 0 || $remaining % 4096 != 0} {
        error "$kind capacity not multiple of 4 KiB"
    }

    set banks {}
    while {$remaining > 0} {
        # 1M 128-bit words per bank = 16 MiB
        set size 0x1000000
        while {$size > $remaining || $base % $size != 0} {
            # Shrink bank to fit remaining capacity/stay aligned
            set size [expr {$size / 2}]
        }
        lappend banks [dict create \
            kind $kind \
            prefix extmem_bank[llength $banks] \
            base $base \
            size $size \
        ]
        incr base $size
        incr remaining -$size
    }

    return $banks
}

proc extmem_backend::onchip::create_bank {kind prefix data_bits capacity_bytes} {
    set controller ${prefix}_controller
    set memory ${prefix}_memory

    # Configure AXI controller
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 $controller
    set_property -dict [list \
        CONFIG.DATA_WIDTH $data_bits \
        CONFIG.SINGLE_PORT_BRAM 1 \
        CONFIG.PROTOCOL AXI4 \
        CONFIG.ECC_TYPE 0 \
        CONFIG.USE_ECC 0 \
    ] [get_bd_cells $controller]

    # Configure storage primitive/byte enables
    create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 $memory
    set_property -dict [list \
        CONFIG.Memory_Type Single_Port_RAM \
        CONFIG.Use_BRAM_Block BRAM_Controller \
        CONFIG.PRIM_type_to_Implement [string toupper $kind] \
        CONFIG.Write_Width_A $data_bits \
        CONFIG.Read_Width_A $data_bits \
        CONFIG.Write_Depth_A [expr {$capacity_bytes / ($data_bits / 8)}] \
        CONFIG.Use_Byte_Write_Enable true \
        CONFIG.Byte_Size 8 \
        CONFIG.Enable_A Use_ENA_Pin \
    ] [get_bd_cells $memory]
    connect_bd_intf_net [get_bd_intf_pins $controller/BRAM_PORTA] [get_bd_intf_pins $memory/BRAM_PORTA]

    set reset_pin [get_bd_pins $controller/s_axi_aresetn]
    return [dict create \
        axi [get_bd_intf_pins $controller/S_AXI] \
        address_segment [get_bd_addr_segs $controller/S_AXI/Mem0] \
        clock_pins [list [get_bd_pins $controller/s_axi_aclk]] \
        reset_pins [list $reset_pin] \
        ready_pin $reset_pin \
        capacity_bytes $capacity_bytes \
        data_bits $data_bits \
    ]
}

