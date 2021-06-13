// File name:   flex_stp_sr.sv
// Created:     9/27/2020
// Author:      Zachary Ellis
// Version:     1.0  Initial Design Entry
// Description: flexible serial to parallel shift register

module flex_stp_sr #(
    parameter NUM_BITS = 4,
    parameter SHIFT_MSB = 1
)
(
    input clk,
    input n_rst,
    input shift_enable,
    input serial_in,
    output reg [NUM_BITS - 1:0] parallel_out
);

    reg [NUM_BITS - 1:0] next_out;

    always_comb begin
        next_out = parallel_out;
        if(shift_enable) begin
            if(SHIFT_MSB)
                next_out = {parallel_out[NUM_BITS - 2:0], serial_in};
            else
                next_out = {serial_in, parallel_out[NUM_BITS - 1:1]};
        end
    end

    always_ff @ (posedge clk, negedge n_rst) begin
        if(n_rst == 0)
            parallel_out <= '1;
        else
            parallel_out <= next_out;
    end

endmodule