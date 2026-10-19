`timescale 1ns/1ps
// Synchronize MIG calibration status into the fabric AXI/status domain
module ddr4_ready_sync (
    input wire clk,
    input wire resetn,
    input wire async_calib_complete,
    output wire ready
);
    (* ASYNC_REG = "TRUE" *) logic [1:0] ready_pipe = 2'b00;
    always_ff @(posedge clk or negedge resetn)
        if (!resetn) ready_pipe <= 2'b00;
        else ready_pipe <= {ready_pipe[0], async_calib_complete};
    assign ready = ready_pipe[1];
endmodule
