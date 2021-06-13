// File name:   RCU.sv
// Created:     12/1/2020
// Author:      Zachary Ellis
// Version:     2.0  Extended Functionality
// Description: CAN receiver control unit

module RCU (
    input clk,
    input bitstrobe,
    input nRST,
    input CANRX,
    input tx_busy,
    input [1:0] error_state,
    input CRC_err,
    input enddata,
    output reg endCRC,
    output reg stopCRC,
    output reg busy,
    output Dataphase,
    output reg bitstuff,
    output reg bitstuff_error,
    output reg form_error,
    output reg [1:0] rx_err_code,
    output reg [3:0] pkt_size,
    output reg [28:0] msg_id,
    output reg [7:0] payload,
    output reg RTR,
    output reg EXT,
    output reg curr_sample,
    output reg SOF,
    output reg pkt_done,
    output reg new_ID
);

    wire nbitstrobe;
    wire [17:0] rawchunks;
    always_ff @(posedge bitstrobe) begin
        curr_sample <= CANRX;
    end

    typedef enum logic [4:0]{
        Idle,
        getID,
        SRRTR,
        IDEverif,
        SRRorRTR,
        getIDext,
        extRTR,
        r1,
        r0,
        getpktsize,
        dataphase,
        crc,
        crc_delim,
        ack,
        ack_delim,
        EOF,
        intermission,
        ErrF,
        ErrD,
        OVD,
        OVR
    } statem_type;

    typedef enum logic [3:0] {
        Reset,
        z1,
        z2,
        z3,
        z4,
        z5,
        o1,
        o2,
        o3,
        o4,
        o5,
        bso,
        bsz,
        error
    } states_type;

    statem_type statem, next_statem;
    states_type states, next_states;

    reg [4:0] bitcount, next_bitcount;

    reg [28:0] next_msg_id;
    reg [3:0] next_pkt_size;

    reg next_RTR;
    reg next_EXT;
    
    reg [1:0] err_code, next_err_code;

    reg bitstuff_error_delay;

    reg [3:0] dcount, next_dcount;

    always_ff @(posedge bitstrobe, negedge nRST) begin
        if(nRST == 0) begin
            statem <= Idle;
            RTR <= '0;
            EXT <= '0;
            bitcount <= '0;
            err_code <= '0;
            dcount <= '0;
        end 
        else begin
            statem <= next_statem;
            RTR <= next_RTR;
            EXT <= next_EXT;
            bitcount <= next_bitcount;
            err_code <= next_err_code;
            dcount <= next_dcount;
        end
    end

    always_comb begin
        next_statem = statem;
        next_RTR = RTR;
        next_EXT = EXT;
        busy = 1'b1;
        next_bitcount = bitcount + 1;
        endCRC = 1'b0;
        stopCRC = 1'b0;
        SOF = 1'b0;
        form_error = 1'b0;
        next_err_code = err_code;
        rx_err_code = 0;
        next_dcount = 0;
        new_ID = 1'b0;
        pkt_done = 1'b0;
        case(statem)
            Idle: begin
                if(curr_sample == 0) begin //weird corner case
                    next_statem = getID;
                    SOF = 1'b1;
                end
                busy = 1'b0;
                next_RTR = 1'b0;
                next_EXT = 1'b0;
            end
            getID: begin
                if(bitcount == 5'd11 && ~bitstuff) begin
                    next_statem = SRRTR;
                end
                busy = 1'b0;
            end
            SRRTR: begin
                if(~bitstuff) begin
                    if(curr_sample == 0) next_statem = IDEverif;
                    else next_statem = SRRorRTR;
                end
                busy = 1'b0;
            end
            IDEverif: begin
                if(~bitstuff) begin
                    if(curr_sample == 0) next_statem = r0;
                    else begin
                        next_statem = ErrF;
                        form_error = 1'b1;
                        next_err_code = 1;
                    end
                end
                busy = 1'b0;
            end
            SRRorRTR: begin
                if(~bitstuff) begin
                    if(curr_sample == 0) begin
                        next_statem = r0;
                        next_RTR = 1'b1;
                    end
                    else begin
                        next_statem = getIDext;
                        next_EXT = 1'b1;
                    end
                end
                busy = 1'b0;
            end
            getIDext: begin
                if(bitcount == 5'd18 && ~bitstuff) next_statem = extRTR;
                busy = 1'b0;
            end
            extRTR: begin
                if(~bitstuff) begin
                    next_statem = r1;
                    if(curr_sample == 1) next_RTR = 1'b1;
                end
                busy = 1'b0;
            end
            r1: begin
                if(~bitstuff) next_statem = r0;
            end
            r0: begin
                if(~bitstuff) next_statem = getpktsize;
                new_ID = 1'b1;
            end
            getpktsize: begin
                if(bitcount == 5'd4 && ~bitstuff) begin
                    next_statem = dataphase;
                    if(next_pkt_size == 0 || RTR == 1'b1) next_statem = crc;
                end
            end
            dataphase: if(enddata && ~bitstuff) next_statem = crc;
            crc: begin 
                if(bitcount == 5'd15 && ~bitstuff)  begin
                    next_statem = crc_delim;
                    endCRC = 1'b1;
                end
            end
            crc_delim: begin
                next_statem = ack;
                if(curr_sample == 0) begin
                    form_error = 1'b1;
                    next_statem = ErrF;
                    next_err_code = 1;
                end
            end
            ack: next_statem = ack_delim;
            ack_delim: begin
                next_statem = EOF;
                if(curr_sample == 0) begin
                    form_error = 1'b1;
                    next_statem = ErrF;
                    next_err_code = 1;
                end
            end
            EOF: begin
                if(curr_sample == 0) begin
                    form_error = 1'b1;
                    next_statem = ErrF;
                    next_err_code = 1;
                end
                if(bitcount == 5'd7) begin
                    next_statem = intermission;
                    form_error = 1'b0;
                    next_err_code = 3;
                    pkt_done = 1'b1;
                end
            end
            intermission: begin
                if(curr_sample == 0) next_statem = OVD;
                if(bitcount == 5'd3) next_statem = Idle;
                rx_err_code = err_code;
                next_err_code = 0;
                busy = 1'b0;
            end
            ErrF: begin
                if(bitcount == 5'd6) next_statem = ErrD;
                stopCRC = 1;
                if(error_state == 0 && curr_sample == 1'b1 && |err_code) rx_err_code = 2; //make sure rx is sending the flag
                busy = 1'b0;
            end
            ErrD: begin
                if(bitcount == 8) next_statem = intermission;
                if(dcount == 8) rx_err_code = 2;
                if(curr_sample == 0) begin
                    next_bitcount = bitcount;
                    next_dcount = dcount + 1;
                    case(dcount)
                        4'd0: rx_err_code = |err_code ? 2 : 0;
                        4'd8: begin
                            next_dcount = 1;
                            rx_err_code = 2;
                        end
                    endcase
                end
                busy = 1'b0;
            end
            OVD: begin
                if(bitcount == 6) next_statem = OVR;
                if(error_state == 0 && curr_sample == 1'b1) rx_err_code = 2;
            end
            OVR: begin
                if(bitcount == 8) next_statem = intermission;
                if(dcount == 8) rx_err_code = 2;
                if(curr_sample == 0) begin
                    next_bitcount = bitcount;
                    next_dcount = dcount + 1;
                    if(dcount == 8) next_dcount = 1;
                end
            end
        endcase
        if(bitstuff) next_bitcount = bitcount;
        if(bitstuff_error_delay) begin
            next_statem = ErrF;
            next_err_code = 1;
        end
        if(CRC_err) begin
            next_statem = ErrF;
            next_err_code = 1;
        end
        if(next_statem != statem) next_bitcount = 1;
        if(tx_busy && (next_statem != ErrF && next_statem != ErrD)) begin
            next_statem = intermission;
            next_bitcount = 1;
        end
    end

    always_ff @(posedge clk, negedge nRST) begin
        if(nRST == 0) bitstuff_error_delay <= 1'b0;
        else bitstuff_error_delay <= bitstuff_error;
    end

    assign Dataphase = (statem == dataphase);

    assign nbitstrobe = ~bitstrobe;

    always_ff @(posedge nbitstrobe, negedge nRST) begin
        if(nRST == 0) begin
            states <= Reset;
        end
        else begin
            states <= next_states;
        end
    end

    always_comb begin
        bitstuff = 1'b0;
        bitstuff_error = 1'b0;
        next_states = states;
        case(states)
            Reset: begin
                if(CANRX) next_states = o1;
                else next_states = z1;
            end
            z1: begin
                if(CANRX) next_states = o1;
                else next_states = z2;
            end
            z2: begin
                if(CANRX) next_states = o1;
                else next_states = z3;
            end
            z3: begin
                if(CANRX) next_states = o1;
                else next_states = z4;
            end
            z4: begin
                if(CANRX) next_states = o1;
                else next_states = z5;
            end
            z5: begin
                if(CANRX) begin
                    next_states = o1;
                    bitstuff = 1'b1;
                end
                else next_states = error;
            end
            o1: begin
                if(CANRX) next_states = o2;
                else next_states = z1;
            end
            o2: begin
                if(CANRX) next_states = o3;
                else next_states = z1;
            end
            o3: begin
                if(CANRX) next_states = o4;
                else next_states = z1;
            end
            o4: begin
                if(CANRX) next_states = o5;
                else next_states = z1;
            end
            o5: begin
                if(CANRX) next_states = error;
                else begin
                    next_states = z1;
                    bitstuff = 1'b1;
                end
            end
            bso: begin
                bitstuff = 1'b1;
                if(CANRX) next_states = o2;
                else next_states = z1;
            end
            bsz: begin
                bitstuff = 1'b1;
                if(CANRX) next_states = o1;
                else next_states = z2;
            end
            error:begin
                bitstuff_error = 1'b1;
                if(CANRX) next_states = o1;
                else next_states = z1;
            end
        endcase
        if(next_statem == Idle || next_statem == crc_delim || next_statem == EOF || next_statem == ErrF || next_statem == ErrD || next_statem == intermission) next_states = Reset;
    end

    flex_stp_sr #(
        .NUM_BITS(18)
    )
    PKTCUTTER(
        .clk(bitstrobe),
        .n_rst(nRST),
        .shift_enable(~bitstuff),
        .serial_in(CANRX),
        .parallel_out(rawchunks)
    );

    always_ff @(posedge bitstrobe, negedge nRST) begin
        if(nRST == 0) begin
            msg_id <= '0;
            pkt_size <= '0;
        end
        else begin
            msg_id <= next_msg_id;
            pkt_size <= next_pkt_size;
        end
    end

    always_comb begin
        next_msg_id = msg_id;
        next_pkt_size = pkt_size;
        payload = '0;
        if(statem == getID) next_msg_id = {rawchunks[10:0], 18'd0};
        else if(statem == getIDext) next_msg_id = {msg_id[28:18], rawchunks};
        else if(statem == getpktsize) next_pkt_size = rawchunks[3:0];
        else if(statem == dataphase) payload = rawchunks[7:0];
    end

endmodule