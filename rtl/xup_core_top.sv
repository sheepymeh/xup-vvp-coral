`timescale 1ns/1ps
`default_nettype none
module xup_core_top #(
    parameter int ClockFrequencyMhz = 50,
    parameter int PcieLanes = 4
) (
    input wire logic fabric_refclk_p,
    input wire logic fabric_refclk_n
`ifdef XUP_PCIE
    , input wire logic sys_clk_p
    , input wire logic sys_clk_n
    , input wire logic sys_rst_n
    , input wire logic [PcieLanes-1:0] pci_exp_rxp
    , input wire logic [PcieLanes-1:0] pci_exp_rxn
    , output logic [PcieLanes-1:0] pci_exp_txp
    , output logic [PcieLanes-1:0] pci_exp_txn
`endif
`ifdef XUP_DIMM
    , input wire logic dimm0_refclk_clk_p
    , input wire logic dimm0_refclk_clk_n
    , output wire C0_DDR4_0_act_n
    , output wire [16:0] C0_DDR4_0_adr
    , output wire [1:0] C0_DDR4_0_ba
    , output wire [1:0] C0_DDR4_0_bg
    , output wire [0:0] C0_DDR4_0_cke
    , output wire [0:0] C0_DDR4_0_odt
    , output wire [0:0] C0_DDR4_0_cs_n
    , output wire [0:0] C0_DDR4_0_ck_t
    , output wire [0:0] C0_DDR4_0_ck_c
    , output wire C0_DDR4_0_reset_n
    , inout wire [63:0] C0_DDR4_0_dq
    , inout wire [7:0] C0_DDR4_0_dqs_c
    , inout wire [7:0] C0_DDR4_0_dqs_t
    , inout wire [7:0] C0_DDR4_0_dm_n
`endif
);
    logic fabric_clk;
    logic fabric_aresetn;
    logic jtag_awid;
    logic [31:0] jtag_awaddr;
    logic [7:0] jtag_awlen;
    logic [2:0] jtag_awsize;
    logic [1:0] jtag_awburst;
    logic jtag_awlock;
    logic [3:0] jtag_awcache;
    logic [2:0] jtag_awprot;
    logic [3:0] jtag_awqos;
    logic jtag_awvalid;
    logic jtag_awready;
    logic [31:0] jtag_wdata;
    logic [3:0] jtag_wstrb;
    logic jtag_wlast;
    logic jtag_wvalid;
    logic jtag_wready;
    logic jtag_bid;
    logic [1:0] jtag_bresp;
    logic jtag_bvalid;
    logic jtag_bready;
    logic jtag_arid;
    logic [31:0] jtag_araddr;
    logic [7:0] jtag_arlen;
    logic [2:0] jtag_arsize;
    logic [1:0] jtag_arburst;
    logic jtag_arlock;
    logic [3:0] jtag_arcache;
    logic [2:0] jtag_arprot;
    logic [3:0] jtag_arqos;
    logic jtag_arvalid;
    logic jtag_arready;
    logic jtag_rid;
    logic [31:0] jtag_rdata;
    logic [1:0] jtag_rresp;
    logic jtag_rlast;
    logic jtag_rvalid;
    logic jtag_rready;

    xup_clock_reset #(.ClockFrequencyMhz(ClockFrequencyMhz)) clock_reset (
        .refclk_p(fabric_refclk_p), .refclk_n(fabric_refclk_n),
        .fabric_clk(fabric_clk),
        .fabric_aresetn(fabric_aresetn)
    );

    // Keep JTAG outside reusable fabric so simulation can connect its 32-bit
    // port to AMD AXI VIP without simulating JTAG
    core_jtag_axi jtag_host (
        .aclk(fabric_clk), .aresetn(fabric_aresetn),
        .m_axi_awid(jtag_awid),
        .m_axi_awaddr(jtag_awaddr),
        .m_axi_awlen(jtag_awlen),
        .m_axi_awsize(jtag_awsize),
        .m_axi_awburst(jtag_awburst),
        .m_axi_awlock(jtag_awlock),
        .m_axi_awcache(jtag_awcache),
        .m_axi_awprot(jtag_awprot),
        .m_axi_awqos(jtag_awqos),
        .m_axi_awvalid(jtag_awvalid),
        .m_axi_awready(jtag_awready),
        .m_axi_wdata(jtag_wdata),
        .m_axi_wstrb(jtag_wstrb),
        .m_axi_wlast(jtag_wlast),
        .m_axi_wvalid(jtag_wvalid),
        .m_axi_wready(jtag_wready),
        .m_axi_bid(jtag_bid),
        .m_axi_bresp(jtag_bresp),
        .m_axi_bvalid(jtag_bvalid),
        .m_axi_bready(jtag_bready),
        .m_axi_arid(jtag_arid),
        .m_axi_araddr(jtag_araddr),
        .m_axi_arlen(jtag_arlen),
        .m_axi_arsize(jtag_arsize),
        .m_axi_arburst(jtag_arburst),
        .m_axi_arlock(jtag_arlock),
        .m_axi_arcache(jtag_arcache),
        .m_axi_arprot(jtag_arprot),
        .m_axi_arqos(jtag_arqos),
        .m_axi_arvalid(jtag_arvalid),
        .m_axi_arready(jtag_arready),
        .m_axi_rid(jtag_rid),
        .m_axi_rdata(jtag_rdata),
        .m_axi_rresp(jtag_rresp),
        .m_axi_rlast(jtag_rlast),
        .m_axi_rvalid(jtag_rvalid),
        .m_axi_rready(jtag_rready)
    );

`ifdef XUP_PCIE
    logic pcie_refclk;
    logic pcie_gt_refclk;
    IBUFDS_GTE4 #(.REFCLK_HROW_CK_SEL(2'b00)) pcie_refclk_buffer (
        .I(sys_clk_p), .IB(sys_clk_n),
        .O(pcie_gt_refclk), .ODIV2(pcie_refclk), .CEB(1'b0)
    );
`endif

    core_bd_wrapper fabric (
        .fabric_clk(fabric_clk), .fabric_aresetn(fabric_aresetn),
        .S_AXI_HOST_awid(jtag_awid),
        .S_AXI_HOST_awaddr(jtag_awaddr),
        .S_AXI_HOST_awlen(jtag_awlen),
        .S_AXI_HOST_awsize(jtag_awsize),
        .S_AXI_HOST_awburst(jtag_awburst),
        .S_AXI_HOST_awlock(jtag_awlock),
        .S_AXI_HOST_awcache(jtag_awcache),
        .S_AXI_HOST_awprot(jtag_awprot),
        .S_AXI_HOST_awqos(jtag_awqos),
        .S_AXI_HOST_awvalid(jtag_awvalid),
        .S_AXI_HOST_awready(jtag_awready),
        .S_AXI_HOST_wdata(jtag_wdata),
        .S_AXI_HOST_wstrb(jtag_wstrb),
        .S_AXI_HOST_wlast(jtag_wlast),
        .S_AXI_HOST_wvalid(jtag_wvalid),
        .S_AXI_HOST_wready(jtag_wready),
        .S_AXI_HOST_bid(jtag_bid),
        .S_AXI_HOST_bresp(jtag_bresp),
        .S_AXI_HOST_bvalid(jtag_bvalid),
        .S_AXI_HOST_bready(jtag_bready),
        .S_AXI_HOST_arid(jtag_arid),
        .S_AXI_HOST_araddr(jtag_araddr),
        .S_AXI_HOST_arlen(jtag_arlen),
        .S_AXI_HOST_arsize(jtag_arsize),
        .S_AXI_HOST_arburst(jtag_arburst),
        .S_AXI_HOST_arlock(jtag_arlock),
        .S_AXI_HOST_arcache(jtag_arcache),
        .S_AXI_HOST_arprot(jtag_arprot),
        .S_AXI_HOST_arqos(jtag_arqos),
        .S_AXI_HOST_arvalid(jtag_arvalid),
        .S_AXI_HOST_arready(jtag_arready),
        .S_AXI_HOST_rid(jtag_rid),
        .S_AXI_HOST_rdata(jtag_rdata),
        .S_AXI_HOST_rresp(jtag_rresp),
        .S_AXI_HOST_rlast(jtag_rlast),
        .S_AXI_HOST_rvalid(jtag_rvalid),
        .S_AXI_HOST_rready(jtag_rready)
`ifdef XUP_PCIE
        , .sys_clk(pcie_refclk)
        , .sys_clk_gt(pcie_gt_refclk)
        , .sys_rst_n(sys_rst_n)
        , .pci_exp_rxp(pci_exp_rxp)
        , .pci_exp_rxn(pci_exp_rxn)
        , .pci_exp_txp(pci_exp_txp)
        , .pci_exp_txn(pci_exp_txn)
`endif
`ifdef XUP_DIMM
        , .dimm0_refclk_clk_p(dimm0_refclk_clk_p)
        , .dimm0_refclk_clk_n(dimm0_refclk_clk_n)
        , .C0_DDR4_0_act_n(C0_DDR4_0_act_n)
        , .C0_DDR4_0_adr(C0_DDR4_0_adr)
        , .C0_DDR4_0_ba(C0_DDR4_0_ba)
        , .C0_DDR4_0_bg(C0_DDR4_0_bg)
        , .C0_DDR4_0_cke(C0_DDR4_0_cke)
        , .C0_DDR4_0_odt(C0_DDR4_0_odt)
        , .C0_DDR4_0_cs_n(C0_DDR4_0_cs_n)
        , .C0_DDR4_0_ck_t(C0_DDR4_0_ck_t)
        , .C0_DDR4_0_ck_c(C0_DDR4_0_ck_c)
        , .C0_DDR4_0_reset_n(C0_DDR4_0_reset_n)
        , .C0_DDR4_0_dq(C0_DDR4_0_dq)
        , .C0_DDR4_0_dqs_c(C0_DDR4_0_dqs_c)
        , .C0_DDR4_0_dqs_t(C0_DDR4_0_dqs_t)
        , .C0_DDR4_0_dm_n(C0_DDR4_0_dm_n)
`endif
    );
endmodule
