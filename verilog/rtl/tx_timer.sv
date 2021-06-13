// File name:   wb_CAN.sv
// Created:     5/14/2021
// Author:      Zachary Ellis
// Version:     1.1  Added functionality
// Description: internal timer for CAN TX

module tx_timer (
    input nRST,
    input tx_strobe,
    input dataphase,
    input bitstuff,
    input [3:0] pkt_size,
    output byte_complete,
    output [3:0] byte_num,
    output end_data
);

    flex_counter #(
        .NUM_CNT_BITS(4)
    )
    BYTETIMER(
        .clk(tx_strobe),
        .n_rst(nRST),
        .clear(!dataphase),
        .count_enable(~bitstuff),
        .rollover_val(4'd8),
        .count_out(),
        .rollover_flag(byte_complete)
    );

    flex_counter #(
        .NUM_CNT_BITS(4)
    )
    PAYLOADTIMER(
        .clk(byte_complete),
        .n_rst(dataphase),
        .clear(1'b0),
        .count_enable(1'b1),
        .rollover_val(pkt_size),
        .count_out(byte_num),
        .rollover_flag(end_data)
    );


endmodule