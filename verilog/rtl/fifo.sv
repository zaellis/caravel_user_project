// File name:   fifo.sv
// Created:     5/26/2021
// Author:      Zachary Ellis
// Version:     1.0  Initial Design Entry
// Description: CAN receiver fifo

/////////////////////////////////////////////////////
// Changes to be made
// - add input signals from RCU
// - add ID filtering / filter match index to struct
// - figure out reading from fifo logic
// - figure out SystemVerilog packages to be able to
//   pass structs around
/////////////////////////////////////////////////////

module fifo (
    input clk,
    input nRST,
    input clear,
    input [28:0] ID,
    input [7:0] data,
    input [3:0] data_index,
    input load_data,
    input [3:0] pkt_size,
    input RTR,
    input EXT,
    input pkt_done,
    input enable_overrun,
    input new_ID,
    input [19:0] mask_enable,
    input [30:0] filter_0, //this is a yosys thing since you cant do input [19:0] [31:0]
    input [30:0] mask_0,
    input [30:0] filter_1,
    input [30:0] mask_1,
    input [30:0] filter_2,
    input [30:0] mask_2,
    input [30:0] filter_3,
    input [30:0] mask_3,
    input [30:0] filter_4,
    input [30:0] mask_4,
    input [30:0] filter_5,
    input [30:0] mask_5,
    input [30:0] filter_6,
    input [30:0] mask_6,
    input [30:0] filter_7,
    input [30:0] mask_7,
    input [30:0] filter_8,
    input [30:0] mask_8,
    input [30:0] filter_9,
    input [30:0] mask_9,
    input [30:0] filter_10,
    input [30:0] mask_10,
    input [30:0] filter_11,
    input [30:0] mask_11,
    input [30:0] filter_12,
    input [30:0] mask_12,
    input [30:0] filter_13,
    input [30:0] mask_13,
    input [30:0] filter_14,
    input [30:0] mask_14,
    input [30:0] filter_15,
    input [30:0] mask_15,
    input [30:0] filter_16,
    input [30:0] mask_16,
    input [30:0] filter_17,
    input [30:0] mask_17,
    input [30:0] filter_18,
    input [30:0] mask_18,
    input [30:0] filter_19,
    input [30:0] mask_19,
    input read_fifo,
    output reg [3:0] occupancy,
    output full,
    output empty,
    output reg overrun,
    output reg [31:0] data_L,
    output reg [31:0] data_H,
    output reg [28:0] ID_out,
    output reg [3:0] pkt_size_out,
    output reg RTR_out,
    output reg EXT_out,
    output reg [4:0] fmi_out,
    output reg fifo_read
);

    `ifdef SIM //vivado and yosys disagree
        wire [19:0] [30:0] filters;
        wire [19:0] [30:0] masks;
    `else
        wire [30:0] filters[19:0];
        wire [30:0] masks[19:0];
    `endif

    assign filters[0] = filter_0;
    assign masks[0] = mask_0;
    assign filters[1] = filter_1;
    assign masks[1] = mask_1;
    assign filters[2] = filter_2;
    assign masks[2] = mask_2;
    assign filters[3] = filter_3;
    assign masks[3] = mask_3;
    assign filters[4] = filter_4;
    assign masks[4] = mask_4;
    assign filters[5] = filter_5;
    assign masks[5] = mask_5;
    assign filters[6] = filter_6;
    assign masks[6] = mask_6;
    assign filters[7] = filter_7;
    assign masks[7] = mask_7;
    assign filters[8] = filter_8;
    assign masks[8] = mask_8;
    assign filters[9] = filter_9;
    assign masks[9] = mask_9;
    assign filters[10] = filter_10;
    assign masks[10] = mask_10;
    assign filters[11] = filter_11;
    assign masks[11] = mask_11;
    assign filters[12] = filter_12;
    assign masks[12] = mask_12;
    assign filters[13] = filter_13;
    assign masks[13] = mask_13;
    assign filters[14] = filter_14;
    assign masks[14] = mask_14;
    assign filters[15] = filter_15;
    assign masks[15] = mask_15;
    assign filters[16] = filter_16;
    assign masks[16] = mask_16;
    assign filters[17] = filter_17;
    assign masks[17] = mask_17;
    assign filters[18] = filter_18;
    assign masks[18] = mask_18;
    assign filters[19] = filter_19;
    assign masks[19] = mask_19;

    typedef struct packed
    {
        logic [28:0] pkt_ID;
        logic [3:0] pkt_size;
        logic [7:0] [7:0] pkt_data;
        logic RTR;
        logic EXT;
        logic [4:0] fmi;
    } pkt_t;

    
    `ifdef SIM //vivado and yosys disagree
        reg [7:0] [7:0] pkt_buffer;
    `else
        reg [7:0] pkt_buffer[7:0];
    `endif

    reg [4:0] filter_index;
    reg [4:0] fmi;
    reg filter_match;

    always_ff @(posedge clk, negedge nRST) begin
        if(nRST == 0) begin
            filter_index <= '0;
            fmi <= '0;
            filter_match <= '0;
        end
        else begin
            if(new_ID || (|filter_index)) begin
                if(mask_enable[filter_index] && (({RTR, EXT, ID} & masks[filter_index]) == (filters[filter_index] & masks[filter_index]))) begin
                    fmi <= filter_index;
                    filter_index <= '0;
                    filter_match <= 1;
                end
                else begin
                    if(filter_index == 5'd19) filter_index <= 0;
                    else filter_index <= filter_index + 1;
                    filter_match <= 0;
                end
            end
        end
    end

    always_ff @(posedge clk, negedge nRST) begin
        if(nRST == 0) pkt_buffer <= '0;
        else begin
            if(load_data) pkt_buffer[data_index] <= data;
            if(pkt_done_edge) pkt_buffer <= '0;
        end
    end

    pkt_t [7:0] pkt_fifo;

    reg [2:0] start_fifo, end_fifo;

    assign full = (occupancy == 4'd8);
    assign empty = (occupancy == 4'd0);

    reg [1:0] delay_ff;

    wire pkt_done_edge;

    assign pkt_done_edge = ~delay_ff[0] & delay_ff[1];

    always_ff @(posedge clk, negedge nRST) begin
        if(nRST == 0)
            delay_ff <= '0;
        else begin
            delay_ff[0] <= pkt_done;
            delay_ff[1] <= delay_ff[0];
        end
    end

    always @(posedge clk, negedge nRST) begin
        if(nRST == 0) begin 
            pkt_fifo <= '0;
            start_fifo <= '0;
            end_fifo <= '0;
            fifo_read <= 0;
            occupancy <= '0;
            data_L <= '0;
            data_H <= '0;
            ID_out <= '0;
            pkt_size_out <= '0;
            RTR_out <= '0;
            EXT_out <= '0;
            fmi_out <= '0;
            overrun <= '0;
        end
        else begin
            data_L <= pkt_fifo[start_fifo].pkt_data[3:0];
            data_H <= pkt_fifo[start_fifo].pkt_data[7:4];
            ID_out <= pkt_fifo[start_fifo].pkt_ID;
            pkt_size_out <= pkt_fifo[start_fifo].pkt_size;
            RTR_out <= pkt_fifo[start_fifo].RTR;
            EXT_out <= pkt_fifo[start_fifo].EXT;
            fmi_out <= pkt_fifo[start_fifo].fmi;
            if(clear) begin
                pkt_fifo <= '0;
                start_fifo <= '0;
                end_fifo <= '0;
                fifo_read <= 0;
                occupancy <= '0;
                overrun <= '0;
            end
            else if(pkt_done_edge & filter_match) begin //add filtering to this
                if(~full || (full & enable_overrun)) begin
                    pkt_fifo[end_fifo].pkt_data <= pkt_buffer;
                    pkt_fifo[end_fifo].pkt_size <= pkt_size;
                    pkt_fifo[end_fifo].pkt_ID <= ID;
                    pkt_fifo[end_fifo].RTR <= RTR;
                    pkt_fifo[end_fifo].EXT <= EXT;
                    pkt_fifo[end_fifo].fmi <= fmi;
                    end_fifo <= end_fifo + 1;
                    if(full) begin
                        overrun <= 1;
                        start_fifo <= start_fifo + 1;
                    end
                    else begin
                        overrun <= 0;
                        occupancy <= occupancy + 1;
                    end
                end
            end
            else if(read_fifo) begin
                fifo_read <= 1;
                overrun <= 0;
                if(empty == 0) begin
                    pkt_fifo[start_fifo] <= '0;
                    occupancy <= occupancy - 1;
                    start_fifo <= start_fifo + 1;
                end
            end
            else fifo_read <= 0;
        end
    end

endmodule