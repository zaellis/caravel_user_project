// File name:   CRCcheck.sv
// Created:     11/28/2020
// Author:      Zachary Ellis
// Version:     2.0 Extended support
// Description: Check CAN CRC on receiver side

module CRCcheck (
    input clk,
    input bitstrobe,
    input tx_strobe,
    input endCRC,
    input stopCRC,
    input nRST,
    input bitstuff,
    input [3:0] pkt_size,
    input SOF,
    input CANRX,
    output reg ACK,
    output CRCerror
);

    typedef enum logic [2:0] {
        Idle,
        Running,
        ENDCRC,
        delimeter,
        doACK
    } state_type;

    state_type state, next_state;
    reg [14:0] CRC, Next_CRC;

    always_ff @(posedge clk, negedge nRST) begin
        if(nRST == 0) begin
            state <= Idle;
        end
        else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        ACK = 1'b1;
        case(state)
            Idle: if(SOF) next_state = Running;
            Running: if(endCRC && ~bitstuff) next_state = ENDCRC;
            ENDCRC: if(bitstrobe && ~bitstuff) next_state = delimeter;
            delimeter: if(tx_strobe && ~bitstuff) next_state = doACK;
            doACK: begin
                if(tx_strobe) next_state = Idle;
                ACK = |CRC;
            end
        endcase
        if(stopCRC) next_state = Idle;
    end

    wire inv;
    wire bit_clk;

    assign inv = CANRX ^ CRC[14];
    assign bit_clk = (bitstuff) ? 0 : bitstrobe;

    always_ff @(posedge bit_clk, negedge nRST) begin
        if (nRST == 0) begin
            CRC <= '0;
        end
        else begin
            CRC <= Next_CRC;
        end
    end

    always_comb begin
        Next_CRC = CRC;
        if(state == Idle) Next_CRC = '0; //Next_CRC = 15'b100010110011001;
        else if(state == Running) begin
            Next_CRC[14] = CRC[13] ^ inv;
            Next_CRC[13] = CRC[12];
            Next_CRC[12] = CRC[11];
            Next_CRC[11] = CRC[10];
            Next_CRC[10] = CRC[9] ^ inv;
            Next_CRC[9] = CRC[8];
            Next_CRC[8] = CRC[7] ^ inv;
            Next_CRC[7] = CRC[6] ^ inv;
            Next_CRC[6] = CRC[5];
            Next_CRC[5] = CRC[4];
            Next_CRC[4] = CRC[3] ^ inv;
            Next_CRC[3] = CRC[2] ^ inv;
            Next_CRC[2] = CRC[1];
            Next_CRC[1] = CRC[0];
            Next_CRC[0] = inv;
        end
    end

    reg [1:0] CRCerror_delay;

    assign CRCerror = CRCerror_delay[1];

    always_ff @(posedge bitstrobe, negedge nRST) begin
        if(nRST == 0) CRCerror_delay <= '0;
        else begin
            CRCerror_delay[0] <= (state == doACK) ? ACK : 0;
            CRCerror_delay[1] <= CRCerror_delay[0];
        end
    end


endmodule