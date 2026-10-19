`timescale 1ns/1ps
// Board clock input/FPGA power-up reset release
module xup_clock_reset #(
    parameter int ClockFrequencyMhz = 50
) (
    input logic refclk_p,
    input logic refclk_n,
    output logic fabric_clk,
    output logic fabric_aresetn
);
    logic clock_locked;
    clkgen_wrapper #(.ClockFrequencyMhz(ClockFrequencyMhz)) clock_generator (
        .clk_p_i(refclk_p), .clk_n_i(refclk_n),
        .rst_ni(1'b1), .srst_ni(1'b1), .clk_main_o(fabric_clk),
        .clk_isp_o(), .clk_spim_o(), .rst_no(), .locked_o(clock_locked)
    );
    fabric_reset reset_release (
        .clk(fabric_clk), .clock_locked_async(clock_locked),
        .aresetn(fabric_aresetn)
    );
endmodule
