// $Id: $
// File name:   timer.sv
// Created:     11/28/2020
// Author:      Zachary Ellis
// Lab Section: 337-08
// Version:     2.0  Remove dumb timer logic
// Description: timing block for CAN reciever

module timer (
    input clk,
    input nRST,
    input [3:0] TS1,
    input [3:0] TS2,
    input edgedet,
    input bitstuff,
    input dataphase,
    input [3:0] pkt_size,
    output reg bitstrobe,
    output reg tx_strobe,
    output reg byte_complete,
    output [3:0] byte_num,
    output end_data
);

    typedef enum logic [1:0] {
        SYNC,
        PROP,
        PHASE1,
        PHASE2
    } timer_state_t;

    timer_state_t state, next_state;

    reg [3:0] count, next_count;
    reg next_bitstrobe;

    always_ff @(posedge clk, negedge nRST) begin
        if(nRST == 1'b0) begin
            state <= SYNC;
            count <= '0; //this is better for hardware and doesn't really affect function
        end
        else begin
            state <= next_state;
            count <= next_count;
        end
    end

    always_comb begin
        next_state = state;
        next_count = count + 1;
        bitstrobe = 1'b0;
        tx_strobe = 1'b0;
        case(state)
            SYNC: begin
                tx_strobe = 1'b1;
                next_state = PROP;
            end
            PROP: begin
                if(edgedet) next_state = PROP;
                else next_state = PHASE1;
            end
            PHASE1: begin
                if(edgedet) next_state = PROP;
                else if(count == TS1) next_state = PHASE2;
            end
            PHASE2: begin
                if(count == 1 && ~edgedet) bitstrobe = 1'b1; //weird edge case
                if(edgedet) begin
                    next_state = PROP;
                    tx_strobe = 1'b1;
                end
                else if(count == TS2) next_state = SYNC;
            end
        endcase
        if(next_state != state) next_count = 1;
    end

    wire [3:0] byte_numraw;

    assign byte_num = (byte_numraw) ? byte_numraw - 4'd1 : 4'd0;

    flex_counter #(
        .NUM_CNT_BITS(4)
    )
    BYTETIMER(
        .clk(bitstrobe),
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
        .count_out(byte_numraw),
        .rollover_flag(end_data)
    );

endmodule
