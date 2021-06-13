// File name:   flex_counter.sv
// Created:     9/15/2020
// Author:      Zachary Ellis
// Version:     1.0  Initial Design Entry
// Description: Flexible Counter for Lab 4
module flex_counter #(
    parameter NUM_CNT_BITS = 4
)
(
    input clk,
    input n_rst,
    input clear,
    input count_enable,
    input [NUM_CNT_BITS - 1:0] rollover_val,
    output reg [NUM_CNT_BITS - 1:0] count_out,
    output reg rollover_flag
);

    reg [NUM_CNT_BITS - 1:0] next_count;
    reg next_rollover;

    always_ff @ (posedge clk, negedge n_rst)
    begin
        if(n_rst == 1'b0) begin
            count_out <= '0;
            rollover_flag <= 1'b0;
        end else begin
            count_out <= next_count;
            rollover_flag <= next_rollover;
        end
    end

    always_comb
    begin
        next_rollover = 1'b0;
        next_count = count_out;
        if(clear == 1'b1) begin
            next_count = '0;
            next_count[0] = 1'b1;
        end
        else if(count_enable)
        begin
            if(count_out == rollover_val) begin
                next_count[NUM_CNT_BITS - 1:1] = '0;
                next_count[0] = 1'b1;
            end
            else
                next_count = count_out + 1;
        end
        if(next_count == rollover_val)
            next_rollover = 1'b1;
    end


endmodule