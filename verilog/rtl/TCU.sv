// File name:   TCU.sv
// Created:     5/17/2021
// Author:      Zachary Ellis
// Version:     1.0  Initial Design Entry
// Description: CAN transmitter control unit

/////////////////////////////////////////////////////
// Changes to be made
// - change data interface to 64 bit bus
/////////////////////////////////////////////////////

module TCU (
    input clk,
    input tx_strobe,
    input bitstrobe,
    input nRST,
    input pkt_ready,
    input tx_enable,
    input rx_busy,
    input [3:0] byte_num,
    input byte_complete,
    input enddata,
    input [3:0] pkt_size,
    input [28:0] msg_id,
    input [63:0] data, //this needs to be fixed
    input RTR,
    input EXT,
    input curr_sample,
    input start_err_tx,
    input [1:0] error_state,
    output reg busy,
    output Dataphase,
    output reg bitstuff,
    output reg CANTX,
    output reg bit_error,
    output reg ack_error,
    output reg [1:0] tx_err_code,
    output reg tx_arb_loss,
    output reg tx_done
);

    typedef enum logic [4:0]{
        Idle,
        SOF,
        ID,
        SRRTR,
        IDsize,
        IDext,
        extRTR,
        r1,
        r0,
        pktsize,
        dataphase,
        CRC,
        ACK,
        EOF,
        intermission,
        SUST,
        ERRD,
        ERRR,
        OVD,
        OVR,
        arb_loss,
        bus_off
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
        bsz
    } states_type;

    statem_type statem, next_statem;
    states_type states, next_states;

    reg [4:0] bitcount, next_bitcount;
    reg load_enable;
    reg datablock;

    reg [1:0] err_code, next_err_code;
    reg [3:0] dcount, next_dcount;

    wire ntx_strobe;
    assign ntx_strobe = ~tx_strobe;

    reg bitstrobe_shift;

    always_ff @(posedge clk) begin
        bitstrobe_shift <= bitstrobe;
    end

    reg curr_sample_valid;

    always_ff @(posedge bitstrobe_shift, negedge ntx_strobe) begin
        if(ntx_strobe == 0) curr_sample_valid <= 1'b0;
        else curr_sample_valid <= 1'b1;
    end


    always_ff @(posedge tx_strobe, negedge nRST) begin
        if(nRST == 0) begin
            statem <= Idle;
            bitcount <= '0;
            err_code <= '0;
            dcount <= '0;
        end
        else begin
            statem <= next_statem;
            bitcount <= next_bitcount;
            err_code <= next_err_code;
            dcount <= next_dcount;
        end
    end

    always_comb begin
        next_statem = statem;
        next_bitcount = bitcount + 1;
        datablock = 1'b0;
        load_enable = 1'b0;
        busy = 1'b1;
        bit_error = 1'b0;
        ack_error = 1'b0;
        next_err_code = err_code;
        tx_err_code = 0;
        next_dcount = 0;
        tx_arb_loss = 0;
        tx_done = 0;
        case(statem)
            Idle: begin
                if(pkt_ready) next_statem = SOF;
                datablock = 1'b1;
                busy = 1'b0;
            end
            SOF: begin
                next_statem = ID;
                datablock = 1'b1;
                load_enable = 1'b1;
                busy = 1'b0;
            end
            ID: begin
                if(bitcount == 11 && ~bitstuff) next_statem = SRRTR;
                busy = 1'b0;
            end
            SRRTR: begin
                if(~bitstuff) next_statem = IDsize;
                datablock = 1'b1;
                busy = 1'b0;
            end
            IDsize: begin
                if(~bitstuff) begin
                    if(EXT) begin
                        next_statem = IDext;
                        load_enable = 1'b1;
                    end
                    else next_statem = r0;
                end
                datablock = 1'b1;
                busy = 1'b0;
            end
            IDext: begin
                if(bitcount == 18 && ~bitstuff) next_statem = extRTR;
                busy = 1'b0;
            end
            extRTR: begin
                if(~bitstuff) next_statem = r1;
                datablock = 1'b1;
                busy = 1'b0;
            end
            r1: begin
                if(~bitstuff) next_statem = r0;
                datablock = 1'b1;
            end
            r0: begin
                if(~bitstuff) begin
                    next_statem = pktsize;
                    load_enable = 1'b1;
                end
                datablock = 1'b1;
            end
            pktsize: begin
                if(bitcount == 4 && ~bitstuff) begin
                    if(RTR) next_statem = CRC;
                    else next_statem = dataphase;
                    load_enable = 1'b1;
                end
            end
            dataphase: begin
                if(enddata && ~bitstuff) begin
                    next_statem = CRC;
                    load_enable = 1'b1;
                end
            end
            CRC: if(bitcount == 15 && ~bitstuff) next_statem = ACK;
            ACK: begin 
                if(bitcount == 2 && curr_sample_valid && curr_sample == 1) begin
                    ack_error = 1;
                    if(~(|error_state)) next_err_code = 2;
                end
                if(bitcount == 3) next_statem = EOF;
                datablock = 1'b1;
            end
            EOF: begin
                if(bitcount == 7) begin
                    next_statem = intermission;
                    tx_done = 1;
                end
                datablock = 1'b1;
            end
            intermission: begin //add error passive / active logic
                if(bitcount == 3) begin
                    if(error_state == 0) next_statem = Idle;
                    else next_statem = SUST;
                    if(pkt_ready) next_statem = SOF;
                end
                if(curr_sample == 0) begin
                    case(bitcount[1:0])
                        2'b01: next_statem = OVD;
                        2'b10: next_statem = OVD;
                        2'b11: next_statem = Idle;
                    endcase
                end
                busy = 1'b0;
                tx_err_code = err_code;
                next_err_code = 0;
            end
            SUST: begin
                if(bitcount == 5'd8) begin
                    if(pkt_ready) next_statem = SOF;
                    else next_statem = Idle;
                end
            end
            ERRD: begin
                if(bitcount == 5'd6) next_statem = ERRR;
                if(error_state == 0 && curr_sample == 1'b1 && |err_code) tx_err_code = 2; //make sure tx is sending the flag
            end
            ERRR: begin
                if(bitcount == 8) next_statem = intermission;
                if(dcount == 8) tx_err_code = 2;
                if(curr_sample == 0) begin
                    next_bitcount = bitcount;
                    next_dcount = dcount + 1;
                    if(dcount == 8) next_dcount = 1;
                end
            end
            OVD: begin
                if(bitcount == 6) next_statem = OVR;
                if(error_state == 0 && curr_sample == 1'b1) tx_err_code = 2;
            end
            OVR: begin
                if(bitcount == 8) next_statem = intermission;
                if(dcount == 8) tx_err_code = 2;
                if(curr_sample == 0) begin
                    next_bitcount = bitcount;
                    next_dcount = dcount + 1;
                    if(dcount == 8) next_dcount = 1;
                end
            end
            arb_loss: begin
                if(bitcount == 5'b11111) next_statem = intermission; 
                busy = 1'b0;
            end
            bus_off: next_statem = intermission;
        endcase
        if(bitstuff) next_bitcount = bitcount;
        if(curr_sample_valid && (curr_sample != CANTX)) begin
            if(statem == pktsize || statem == dataphase || statem == CRC ||
            statem == ACK || statem == EOF) begin
                if(statem == EOF && bitcount == 7) bit_error = 1'b0;
                else if(statem == ACK && bitcount == 2) bit_error = 1'b0;
                else begin
                    bit_error = 1'b1;
                    next_err_code = 2;
                end
            end
            else if (states == bso || states == bsz) bit_error = 1'b1;
            else if(statem == intermission && rx_busy == 1'b0) begin
                if(bitcount == 3) begin
                    next_statem = arb_loss;
                end
                else next_statem = OVD;
            end
            else if(statem != SOF) begin
                next_statem = arb_loss;
                tx_arb_loss = 1;
            end
        end
        if(rx_busy) begin
            next_statem = intermission;
            next_bitcount = 1;
        end
        if(next_statem != statem) next_bitcount = 1;
        if(start_err_tx) begin
            next_statem = ERRD;
            next_bitcount = 1;
        end
        if(error_state[1]) next_statem = bus_off;
        if(~tx_enable) next_statem = Idle;
    end

    assign Dataphase = (statem == dataphase);

    always_ff @(posedge ntx_strobe, negedge nRST) begin
        if(nRST == 0) begin
            states <= Reset;
        end
        else begin
            states <= next_states;
        end
    end

    always_comb begin
        bitstuff = 1'b0;
        next_states = states;
        case(states)
            Reset: begin
                if(CANTX) next_states = o1;
                else next_states = z1;
            end
            z1: begin
                if(CANTX) next_states = o1;
                else next_states = z2;
            end
            z2: begin
                if(CANTX) next_states = o1;
                else next_states = z3;
            end
            z3: begin
                if(CANTX) next_states = o1;
                else next_states = z4;
            end
            z4: begin
                if(CANTX) next_states = o1;
                else next_states = z5;
            end
            z5: next_states = bso;
            o1: begin
                if(CANTX) next_states = o2;
                else next_states = z1;
            end
            o2: begin
                if(CANTX) next_states = o3;
                else next_states = z1;
            end
            o3: begin
                if(CANTX) next_states = o4;
                else next_states = z1;
            end
            o4: begin
                if(CANTX) next_states = o5;
                else next_states = z1;
            end
            o5: next_states = bsz;
            bso: begin
                next_states = o2;
                bitstuff = 1'b1;
            end
            bsz: begin
                next_states = z2;
                bitstuff = 1'b1;
            end
        endcase
        if(next_statem == Idle || next_statem == ACK ||
        next_statem == EOF || next_statem == intermission ||
        next_statem == SUST || next_statem == ERRD ||
        next_statem == ERRR || next_statem == OVD ||
        next_statem == OVR || next_statem == arb_loss || next_statem == bus_off) next_states = Reset; // keep and eye on this
    end

    typedef enum logic {
        Off,
        Running
    } statec_type;

    statec_type CRCstate, next_CRCstate;
    reg [14:0] CRCval, Next_CRCval;

    always_ff @(posedge tx_strobe, negedge nRST) begin
        if(nRST == 0) begin
            CRCstate <= Off;
        end
        else begin
            CRCstate <= next_CRCstate;
        end
    end

    always_comb begin
        next_CRCstate = CRCstate;
        case(CRCstate)
            Off: if(next_statem == SOF) next_CRCstate = Running;
            Running: begin
                if(statem == CRC) next_CRCstate = Off;
                if(statem == ERRD) next_CRCstate = Off;
            end
        endcase
    end

    wire inv;
    wire bit_clk;

    reg bitstuff_shift, tx_strobe_shift;


    always_ff @(posedge clk, negedge nRST) begin
        if(nRST == 0) begin
            bitstuff_shift <= 1'b0;
            tx_strobe_shift <= 1'b0;
        end
        else begin
            bitstuff_shift <= bitstuff;
            tx_strobe_shift <= tx_strobe;
        end
    end

    assign inv = CANTX ^ CRCval[14];
    assign bit_clk = (bitstuff_shift) ? 0 : tx_strobe_shift;

    always_ff @(posedge bit_clk, negedge nRST) begin
        if (nRST == 0) begin
            CRCval <= '0;
        end
        else begin
            CRCval <= Next_CRCval;
        end
    end

    always_comb begin
        Next_CRCval = CRCval;
        if(CRCstate == Off) Next_CRCval = '0;
        else begin
            Next_CRCval[14] = CRCval[13] ^ inv;
            Next_CRCval[13] = CRCval[12];
            Next_CRCval[12] = CRCval[11];
            Next_CRCval[11] = CRCval[10];
            Next_CRCval[10] = CRCval[9] ^ inv;
            Next_CRCval[9] = CRCval[8];
            Next_CRCval[8] = CRCval[7] ^ inv;
            Next_CRCval[7] = CRCval[6] ^ inv;
            Next_CRCval[6] = CRCval[5];
            Next_CRCval[5] = CRCval[4];
            Next_CRCval[4] = CRCval[3] ^ inv;
            Next_CRCval[3] = CRCval[2] ^ inv;
            Next_CRCval[2] = CRCval[1];
            Next_CRCval[1] = CRCval[0];
            Next_CRCval[0] = inv;
        end
    end

    wire block;

    assign block = bitstuff | datablock;

    reg [17:0] data_in; //, next_data_in;

    wire sr_out;

    flex_pts_sr #(
        .NUM_BITS(18)
    )
    PKTASSMBLY(
        .clk(tx_strobe),
        .n_rst(nRST),
        .shift_enable(~block),
        .load_enable(load_enable | byte_complete),
        .parallel_in(data_in),
        .serial_out(sr_out)
    );

    `ifdef SIM
        wire [7:0] [7:0] data_partition;
    `else
        wire [7:0] data_partition[7:0];
    `endif

    assign data_partition[0] = data[7:0];
    assign data_partition[1] = data[15:8];
    assign data_partition[2] = data[23:16];
    assign data_partition[3] = data[31:24];
    assign data_partition[4] = data[39:32];
    assign data_partition[5] = data[47:40];
    assign data_partition[6] = data[55:48];
    assign data_partition[7] = data[63:56];

    always_comb begin
        data_in = '0;
        case(statem)
            SOF: data_in = {msg_id[28:18], 7'd0};
            IDsize: if(EXT) data_in = msg_id[17:0];
            r0: data_in = {pkt_size, 14'd0};
            pktsize: begin
                if(RTR) data_in = {CRCval, 3'd0};
                else data_in = {data_partition[byte_num], 10'd0}; //fix this
            end
            dataphase: begin
                data_in = {data_partition[byte_num], 10'd0};
                if(enddata) data_in = {CRCval, 3'd0};
            end
        endcase
    end

    always_comb begin
        CANTX = sr_out;
        case(statem)
            Idle: CANTX = 1'b1;
            SOF: CANTX = 1'b0;
            SRRTR: CANTX = EXT ? 1'b1 : RTR ? 1'b1 : 1'b0;
            IDsize: CANTX = EXT ? 1'b1 : 1'b0;
            extRTR: CANTX = RTR ? 1'b1 : 1'b0;
            r1: CANTX = 1'b0;
            r0: CANTX = 1'b0;
            ACK: CANTX = 1'b1;
            EOF: CANTX = 1'b1;
            intermission: CANTX = 1'b1;
            SUST: CANTX = 1'b1;
            ERRD: CANTX = error_state[0] ? 1'b1 : 1'b0;
            ERRR: CANTX = 1'b1;
            OVD: CANTX = 1'b0;
            OVR: CANTX = 1'b1;
            bus_off: CANTX = 1'b1;
            arb_loss: CANTX = 1'b1;
        endcase
        if(states == bso) CANTX = 1'b1;
        if(states == bsz) CANTX = 1'b0;
    end

endmodule