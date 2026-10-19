// Reset XUP-VVP DDR4 controller/bank 65 DCIRESET
//
// sys_rst is high while the DDR4 controller is held in reset
// Register sys_rst on CFGMCLK so no combinational LUT drives the DDR4 IP's
// asynchronous reset. FPGA configuration GSR initializes it high. Deassert
// only after EOS, startup DCI reset pulse, POR hold, synchronized DCI LOCKED
//
// CFGMCLK is not an accurate timebase. COUNTER_BITS sets a minimum oscillator
// cycle count, not a guaranteed delay in milliseconds
module xup_ddr4_powerup_reset #(
    parameter integer COUNTER_BITS = 22,
    parameter integer DCI_PULSE_CYCLES = 4096
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 sys_rst RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    output wire sys_rst
);
    wire cfgmclk;
    wire eos;
    wire startup_clk;
    wire dci_locked_async;
    wire dci_reset;

    // EOS/CFGMCLK may be asynchronous
    (* ASYNC_REG = "TRUE" *) logic [1:0] eos_pipe = 2'b00;
    (* ASYNC_REG = "TRUE" *) logic [1:0] dci_locked_pipe = 2'b00;
    logic [COUNTER_BITS-1:0] count = {COUNTER_BITS{1'b0}};
    logic sys_rst_q = 1'b1;

    STARTUPE3 #(
        .PROG_USR("FALSE"), .SIM_CCLK_FREQ(0.0)
    ) startup_inst (
        .CFGCLK(), .CFGMCLK(cfgmclk), .DI(), .EOS(eos), .PREQ(),
        .DO(4'b0000), .DTS(4'b1111), .FCSBO(1'b1), .FCSBTS(1'b1),
        .GSR(1'b0), .GTS(1'b0), .KEYCLEARB(1'b1), .PACK(1'b0),
        .USRCCLKO(1'b0), .USRCCLKTS(1'b1),
        .USRDONEO(1'b1), .USRDONETS(1'b1)
    );
    BUFG cfg_buf (.I(cfgmclk), .O(startup_clk));

            // Assert DCIRESET during startup + DCI_PULSE_CYCLES cycles
            // after EOS reaches this domain. Bank 65 DCI pins need LOCKED
    assign dci_reset = !eos_pipe[1] || (count < DCI_PULSE_CYCLES);
    DCIRESET dci_reset_inst (
        .LOCKED(dci_locked_async),
        .RST(dci_reset)
    );

    always_ff @(posedge startup_clk) begin
        eos_pipe <= {eos_pipe[0], eos};

        if (!eos_pipe[1]) begin
            count <= {COUNTER_BITS{1'b0}};
            dci_locked_pipe <= 2'b00;
            sys_rst_q <= 1'b1;
        end
        else begin
            if (!(&count)) count <= count + 1'b1;
            // Resynchronize LOCKED/hold reset if it drops. DCI lock loss may
            // require a new controller reset/calibration sequence
            dci_locked_pipe <= {dci_locked_pipe[0], dci_locked_async};
            sys_rst_q <= !(&count) || !dci_locked_pipe[1];
        end
    end

    assign sys_rst = sys_rst_q;
endmodule
