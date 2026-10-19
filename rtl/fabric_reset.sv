`timescale 1ns/1ps
// Power-up init. Async assert/sync deassert after clock lock
module fabric_reset (
    input logic clk,
    input logic clock_locked_async,
    output logic aresetn
);
    (* ASYNC_REG = "TRUE" *)
    logic [3:0] release_pipe = 4'b0000;
    always_ff @(posedge clk or negedge clock_locked_async) begin
        if (!clock_locked_async)
            release_pipe <= 4'b0000;
        else
            release_pipe <= {release_pipe[2:0], 1'b1};
    end
    assign aresetn = release_pipe[3];
endmodule
