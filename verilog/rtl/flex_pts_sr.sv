// File name:   flex_pts_sr.sv
// Created:     9/27/2020
// Author:      Zachary Ellis
// Version:     1.0  Initial Design Entry
// Description: flexible parallel to serial shift register

module flex_pts_sr #(
    parameter NUM_BITS = 4,
    parameter SHIFT_MSB = 1
)
(
    input clk,
    input n_rst,
    input shift_enable,
    input load_enable,
    input [NUM_BITS - 1:0] parallel_in,
    output serial_out
);

    reg next_out;
    reg [NUM_BITS - 1:0] new_parallel;
    reg [NUM_BITS - 1:0] next_parallel;

    assign serial_out = (SHIFT_MSB) ? new_parallel[NUM_BITS - 1] : new_parallel[0];

    always_comb begin
        next_parallel = new_parallel;
        case({load_enable, shift_enable})
            2'b11: next_parallel = parallel_in;
            2'b10: next_parallel = parallel_in;
            2'b01: begin
                if (SHIFT_MSB) next_parallel = {new_parallel[NUM_BITS-2:0], 1'b1};
                else next_parallel = {1'b1, new_parallel[NUM_BITS-1:1]};
            end
            default: next_parallel = new_parallel;
        endcase
    end

    always_ff @ (posedge clk, negedge n_rst)begin
        if(n_rst == 0) begin
            new_parallel <= '1;
        end
        else begin
            new_parallel <= next_parallel;
        end
    end
endmodule