// File name:   ECU.sv
// Created:     5/22/2021
// Author:      Zachary Ellis
// Version:     1.0  Initial Design Entry
// Description: CAN error control unit

module ECU (
    input bitstrobe,
    input tx_strobe,
    input nRST,
    input curr_sample,
    input rx_bitstuff_error,
    input rx_form_error,
    input rx_crc_error,
    input tx_bit_error,
    input tx_ack_error,
    input [1:0] rx_code,
    input [1:0]tx_code,
    output start_err_tx,
    output reg [8:0] TEC,
    output reg [8:0] REC,
    output [1:0] error_state,
    output reg [2:0] LEC
);

    assign error_state[0] = REC[7] | TEC[7];
    assign error_state[1] = TEC[8];

    assign start_err_tx = rx_bitstuff_error | rx_form_error | rx_crc_error |
                          tx_bit_error | tx_ack_error;

    wire [4:0] error_vec = {rx_bitstuff_error, rx_form_error, rx_crc_error,
                      tx_bit_error, tx_ack_error};

    always @(posedge tx_strobe, negedge nRST) begin
        if(nRST == 0) LEC <= '0;
        else begin
            casez(error_vec)
                5'b00001: LEC <= 3'd1;
                5'b00010: LEC <= 3'd2;
                5'b00100: LEC <= 3'd3;
                5'b01?00: LEC <= 3'd4; //weird ACK rules I may have interpreted backwards but function is not impeded
                5'b10000: LEC <= 3'd5;
            endcase
        end
    end

    reg [8:0] next_REC;
    wire idle_period, long_idle;

    always_ff @(posedge bitstrobe, negedge nRST) begin
        if(nRST == 0) REC <= 0;
        else REC <= next_REC;
    end

    always_comb begin
        next_REC = REC;
        case(rx_code)
            2'b00: next_REC = REC;
            2'b01: next_REC = REC + 1;
            2'b10: next_REC = REC + 8;
            2'b11: begin
                if(REC[7]) next_REC = 9'd120;
                else if(|REC) next_REC = REC - 1;
            end
        endcase
        if(error_state[1] && long_idle) next_REC = 0;
    end

    reg [8:0] next_TEC;

    always_ff @(posedge tx_strobe, negedge nRST) begin
        if(nRST == 0) TEC <= 0;
        else TEC <= next_TEC;
    end

    always_comb begin
        next_TEC = TEC;
        case(tx_code)
            2'b00: next_TEC = TEC;
            2'b01: next_TEC = TEC + 1;
            2'b10: next_TEC = TEC + 8;
            2'b11: if(|TEC) next_TEC = TEC - 1;
        endcase
        if(TEC[8]) begin
            next_TEC = 9'b100000000;
            if(long_idle) next_TEC = 0;
        end
    end

    flex_counter #(
        .NUM_CNT_BITS(4)
    )
    U1 (
        .clk(bitstrobe),
        .n_rst(nRST),
        .clear(curr_sample),
        .count_enable(1'b1),
        .rollover_val(4'd11),
        .count_out(),
        .rollover_flag(idle_period)
    );

    flex_counter #(
        .NUM_CNT_BITS(8)
    )
    U2 (
        .clk(idle_period),
        .n_rst(nRST),
        .clear(curr_sample),
        .count_enable(1'b1),
        .rollover_val(11'd128),
        .count_out(),
        .rollover_flag(long_idle)
    );

endmodule