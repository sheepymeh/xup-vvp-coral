// Vivado AXI interface metadata. This adapter preserves addresses
// Generated core fixes address/data/ID widths at 32/128/6 bits

module core_mini_axi (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK",
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:M_AXI, ASSOCIATED_RESET aresetn" *)
    input wire aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR",
       X_INTERFACE_PARAMETER = "PROTOCOL AXI4, DATA_WIDTH 128, ADDR_WIDTH 32, ID_WIDTH 6, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_CACHE 1, HAS_REGION 1, HAS_QOS 1, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, MAX_BURST_LENGTH 256, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1" *)
    input wire [31:0] s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
    input wire [2:0] s_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWID" *)
    input wire [5:0] s_axi_awid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWLEN" *)
    input wire [7:0] s_axi_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWSIZE" *)
    input wire [2:0] s_axi_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWBURST" *)
    input wire [1:0] s_axi_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWLOCK" *)
    input wire s_axi_awlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWCACHE" *)
    input wire [3:0] s_axi_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWQOS" *)
    input wire [3:0] s_axi_awqos,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREGION" *)
    input wire [3:0] s_axi_awregion,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input wire s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output wire s_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input wire [127:0] s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WLAST" *)
    input wire s_axi_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input wire [15:0] s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input wire s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output wire s_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BID" *)
    output wire [5:0] s_axi_bid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output wire [1:0] s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output wire s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input wire s_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input wire [31:0] s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input wire [2:0] s_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARID" *)
    input wire [5:0] s_axi_arid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARLEN" *)
    input wire [7:0] s_axi_arlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARSIZE" *)
    input wire [2:0] s_axi_arsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARBURST" *)
    input wire [1:0] s_axi_arburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARLOCK" *)
    input wire s_axi_arlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARCACHE" *)
    input wire [3:0] s_axi_arcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARQOS" *)
    input wire [3:0] s_axi_arqos,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREGION" *)
    input wire [3:0] s_axi_arregion,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input wire s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output wire s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output wire [127:0] s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RID" *)
    output wire [5:0] s_axi_rid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output wire [1:0] s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RLAST" *)
    output wire s_axi_rlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output wire s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input wire s_axi_rready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWADDR",
       X_INTERFACE_PARAMETER = "PROTOCOL AXI4, DATA_WIDTH 128, ADDR_WIDTH 32, ID_WIDTH 6, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_CACHE 1, HAS_REGION 1, HAS_QOS 1, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, MAX_BURST_LENGTH 256, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1" *)
    output wire [31:0] m_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *)
    output wire [2:0] m_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWID" *)
    output wire [5:0] m_axi_awid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLEN" *)
    output wire [7:0] m_axi_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWSIZE" *)
    output wire [2:0] m_axi_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWBURST" *)
    output wire [1:0] m_axi_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLOCK" *)
    output wire m_axi_awlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWCACHE" *)
    output wire [3:0] m_axi_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWQOS" *)
    output wire [3:0] m_axi_awqos,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREGION" *)
    output wire [3:0] m_axi_awregion,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *)
    output wire m_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *)
    input wire m_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WDATA" *)
    output wire [127:0] m_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WLAST" *)
    output wire m_axi_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *)
    output wire [15:0] m_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WVALID" *)
    output wire m_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WREADY" *)
    input wire m_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BID" *)
    input wire [5:0] m_axi_bid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BRESP" *)
    input wire [1:0] m_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BVALID" *)
    input wire m_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BREADY" *)
    output wire m_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)
    output wire [31:0] m_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARPROT" *)
    output wire [2:0] m_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARID" *)
    output wire [5:0] m_axi_arid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLEN" *)
    output wire [7:0] m_axi_arlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARSIZE" *)
    output wire [2:0] m_axi_arsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARBURST" *)
    output wire [1:0] m_axi_arburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLOCK" *)
    output wire m_axi_arlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARCACHE" *)
    output wire [3:0] m_axi_arcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARQOS" *)
    output wire [3:0] m_axi_arqos,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREGION" *)
    output wire [3:0] m_axi_arregion,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *)
    output wire m_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *)
    input wire m_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RDATA" *)
    input wire [127:0] m_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RID" *)
    input wire [5:0] m_axi_rid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RRESP" *)
    input wire [1:0] m_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RLAST" *)
    input wire m_axi_rlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RVALID" *)
    input wire m_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RREADY" *)
    output wire m_axi_rready,

    output wire halted,
    output wire fault,
    output wire wfi,
    input wire irq,
    input wire [31:0] boot_addr,
    input wire timer_irq,
    input wire software_irq,
    output wire dm_req_ready,
    input wire dm_req_valid,
    input wire [31:0] dm_req_address,
    input wire [31:0] dm_req_data,
    input wire [1:0] dm_req_op,
    input wire dm_rsp_ready,
    output wire dm_rsp_valid,
    output wire [31:0] dm_rsp_data,
    output wire [1:0] dm_rsp_op,
    input wire te
);
    // Derived from upstream tests/uvm/tb/coralnpu_tb_top.sv DUT instantiation
    __CORE_MODULE__ core (
        .io_aclk(aclk),
        .io_aresetn(aresetn),
        .io_axi_slave_write_addr_bits_addr(s_axi_awaddr),
        .io_axi_slave_write_addr_bits_prot(s_axi_awprot),
        .io_axi_slave_write_addr_bits_id(s_axi_awid),
        .io_axi_slave_write_addr_bits_len(s_axi_awlen),
        .io_axi_slave_write_addr_bits_size(s_axi_awsize),
        .io_axi_slave_write_addr_bits_burst(s_axi_awburst),
        .io_axi_slave_write_addr_bits_lock(s_axi_awlock),
        .io_axi_slave_write_addr_bits_cache(s_axi_awcache),
        .io_axi_slave_write_addr_bits_qos(s_axi_awqos),
        .io_axi_slave_write_addr_bits_region(s_axi_awregion),
        .io_axi_slave_write_addr_valid(s_axi_awvalid),
        .io_axi_slave_write_addr_ready(s_axi_awready),
        .io_axi_slave_write_data_bits_data(s_axi_wdata),
        .io_axi_slave_write_data_bits_last(s_axi_wlast),
        .io_axi_slave_write_data_bits_strb(s_axi_wstrb),
        .io_axi_slave_write_data_valid(s_axi_wvalid),
        .io_axi_slave_write_data_ready(s_axi_wready),
        .io_axi_slave_write_resp_bits_id(s_axi_bid),
        .io_axi_slave_write_resp_bits_resp(s_axi_bresp),
        .io_axi_slave_write_resp_valid(s_axi_bvalid),
        .io_axi_slave_write_resp_ready(s_axi_bready),
        .io_axi_slave_read_addr_bits_addr(s_axi_araddr),
        .io_axi_slave_read_addr_bits_prot(s_axi_arprot),
        .io_axi_slave_read_addr_bits_id(s_axi_arid),
        .io_axi_slave_read_addr_bits_len(s_axi_arlen),
        .io_axi_slave_read_addr_bits_size(s_axi_arsize),
        .io_axi_slave_read_addr_bits_burst(s_axi_arburst),
        .io_axi_slave_read_addr_bits_lock(s_axi_arlock),
        .io_axi_slave_read_addr_bits_cache(s_axi_arcache),
        .io_axi_slave_read_addr_bits_qos(s_axi_arqos),
        .io_axi_slave_read_addr_bits_region(s_axi_arregion),
        .io_axi_slave_read_addr_valid(s_axi_arvalid),
        .io_axi_slave_read_addr_ready(s_axi_arready),
        .io_axi_slave_read_data_bits_data(s_axi_rdata),
        .io_axi_slave_read_data_bits_id(s_axi_rid),
        .io_axi_slave_read_data_bits_resp(s_axi_rresp),
        .io_axi_slave_read_data_bits_last(s_axi_rlast),
        .io_axi_slave_read_data_valid(s_axi_rvalid),
        .io_axi_slave_read_data_ready(s_axi_rready),
        .io_axi_master_write_addr_bits_addr(m_axi_awaddr),
        .io_axi_master_write_addr_bits_prot(m_axi_awprot),
        .io_axi_master_write_addr_bits_id(m_axi_awid),
        .io_axi_master_write_addr_bits_len(m_axi_awlen),
        .io_axi_master_write_addr_bits_size(m_axi_awsize),
        .io_axi_master_write_addr_bits_burst(m_axi_awburst),
        .io_axi_master_write_addr_bits_lock(m_axi_awlock),
        .io_axi_master_write_addr_bits_cache(m_axi_awcache),
        .io_axi_master_write_addr_bits_qos(m_axi_awqos),
        .io_axi_master_write_addr_bits_region(m_axi_awregion),
        .io_axi_master_write_addr_valid(m_axi_awvalid),
        .io_axi_master_write_addr_ready(m_axi_awready),
        .io_axi_master_write_data_bits_data(m_axi_wdata),
        .io_axi_master_write_data_bits_last(m_axi_wlast),
        .io_axi_master_write_data_bits_strb(m_axi_wstrb),
        .io_axi_master_write_data_valid(m_axi_wvalid),
        .io_axi_master_write_data_ready(m_axi_wready),
        .io_axi_master_write_resp_bits_id(m_axi_bid),
        .io_axi_master_write_resp_bits_resp(m_axi_bresp),
        .io_axi_master_write_resp_valid(m_axi_bvalid),
        .io_axi_master_write_resp_ready(m_axi_bready),
        .io_axi_master_read_addr_bits_addr(m_axi_araddr),
        .io_axi_master_read_addr_bits_prot(m_axi_arprot),
        .io_axi_master_read_addr_bits_id(m_axi_arid),
        .io_axi_master_read_addr_bits_len(m_axi_arlen),
        .io_axi_master_read_addr_bits_size(m_axi_arsize),
        .io_axi_master_read_addr_bits_burst(m_axi_arburst),
        .io_axi_master_read_addr_bits_lock(m_axi_arlock),
        .io_axi_master_read_addr_bits_cache(m_axi_arcache),
        .io_axi_master_read_addr_bits_qos(m_axi_arqos),
        .io_axi_master_read_addr_bits_region(m_axi_arregion),
        .io_axi_master_read_addr_valid(m_axi_arvalid),
        .io_axi_master_read_addr_ready(m_axi_arready),
        .io_axi_master_read_data_bits_data(m_axi_rdata),
        .io_axi_master_read_data_bits_id(m_axi_rid),
        .io_axi_master_read_data_bits_resp(m_axi_rresp),
        .io_axi_master_read_data_bits_last(m_axi_rlast),
        .io_axi_master_read_data_valid(m_axi_rvalid),
        .io_axi_master_read_data_ready(m_axi_rready),
        .io_halted(halted),
        .io_fault(fault),
        .io_wfi(wfi),
        .io_irq(irq),
        .io_boot_addr(boot_addr),
        .io_timer_irq(timer_irq),
        .io_software_irq(software_irq),
        .io_dm_req_ready(dm_req_ready),
        .io_dm_req_valid(dm_req_valid),
        .io_dm_req_bits_address(dm_req_address),
        .io_dm_req_bits_data(dm_req_data),
        .io_dm_req_bits_op(dm_req_op),
        .io_dm_rsp_ready(dm_rsp_ready),
        .io_dm_rsp_valid(dm_rsp_valid),
        .io_dm_rsp_bits_data(dm_rsp_data),
        .io_dm_rsp_bits_op(dm_rsp_op),
        .io_te(te)
    );
endmodule

