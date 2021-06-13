// File name:   wb_slave.sv
// Created:     6/1/2020
// Author:      Zachary Ellis
// Version:     Initial design entry
// Description: wishbone slave interface for CAN controller

/////////////////////////////////////////////////////
// Changes to be made
// - implement signals added based on notes
// - finish all IO
// - make assignments in the main always block
// - interrupts?
// - mailbox status register?
/////////////////////////////////////////////////////

module wb_slave (
    //wb_interface
    input wb_clk_i,
    input wb_rst_i,
    input [31:0] wb_adr_i,
    input [31:0] wb_dat_i,
    input [3:0] wb_sel_i,
    input wb_we_i,
    input wb_cyc_i,
    input wb_stb_i,
    output wb_ack_o,      
    output [31:0] wb_dat_o,
    //connection to the rest of the peripheral
    //general inputs
    input bitstrobe,
    input curr_sample,
    input rx_busy,
    input tx_busy,
    //general outputs
    output reg CAN_clk,
    output CAN_nRST,
    output tx_enable,
    //timing stuff
    output [3:0] TS1, //need to add this to timer
    output [3:0] TS2, //need to add this to timer
    //error stuff
    input [7:0] REC,
    input [7:0] TEC,
    input error_passive,
    input bus_off,
    input [2:0] LEC, //need to add this to ECU
    //fifo stuff
    input [3:0] fifo_occupancy,
    input fifo_full,
    input fifo_empty,
    input fifo_overrun,
    input [31:0] fifo_data_L,
    input [31:0] fifo_data_H,
    input [28:0] fifo_ID,
    input [3:0] fifo_pkt_size,
    input fifo_RTR,
    input fifo_EXT,
    input [4:0] fifo_fmi,
    input fifo_read,
    output fifo_clear,
    output overrun_enable,
    output [19:0] mask_enable,
    output [30:0] filter_0, //this is a yosys thing since you cant do input [19:0] [31:0]
    output [30:0] mask_0,
    output [30:0] filter_1,
    output [30:0] mask_1,
    output [30:0] filter_2,
    output [30:0] mask_2,
    output [30:0] filter_3,
    output [30:0] mask_3,
    output [30:0] filter_4,
    output [30:0] mask_4,
    output [30:0] filter_5,
    output [30:0] mask_5,
    output [30:0] filter_6,
    output [30:0] mask_6,
    output [30:0] filter_7,
    output [30:0] mask_7,
    output [30:0] filter_8,
    output [30:0] mask_8,
    output [30:0] filter_9,
    output [30:0] mask_9,
    output [30:0] filter_10,
    output [30:0] mask_10,
    output [30:0] filter_11,
    output [30:0] mask_11,
    output [30:0] filter_12,
    output [30:0] mask_12,
    output [30:0] filter_13,
    output [30:0] mask_13,
    output [30:0] filter_14,
    output [30:0] mask_14,
    output [30:0] filter_15,
    output [30:0] mask_15,
    output [30:0] filter_16,
    output [30:0] mask_16,
    output [30:0] filter_17,
    output [30:0] mask_17,
    output [30:0] filter_18,
    output [30:0] mask_18,
    output [30:0] filter_19,
    output [30:0] mask_19,
    output read_fifo,
    //tx mailbox output to TCU
    input tx_done,    //add to TCU
    input tx_arb_loss,//add to TCU
    output reg tx_pkt_ready,
    output reg [28:0] tx_ID,
    output reg [3:0] tx_pkt_size,
    output reg tx_RTR,
    output reg tx_EXT,
    output reg [63:0] tx_data
);

    localparam BASE_ADDR = 32'h30000000;

    typedef struct packed {
        logic [25:0] res;
        logic overrun_enable;
        logic auto_retrans;
        logic tx_priority; //need to implement these two features somewhere
        logic sleep;
        logic reset;
        logic start;
    } MCR_t; //Master control register 0x0000

    MCR_t MCR;

    assign overrun_enable = MCR.overrun_enable;

    typedef struct packed {
        logic [26:0] res;
        logic tx_busy;
        logic rx_busy;
        logic curr_sample;
        logic [1:0] mode;
    } MSR_t; //Master status register 0x0004

    MSR_t MSR;

    typedef struct packed {
        logic [22:0] res;
        logic empty;
        logic full;
        logic [3:0] occupancy;
        logic overrun;
        logic read_fifo;
        logic clear;
    } FSCR_t; //FIFO status and control register 0x0008

    FSCR_t FSCR;
    assign fifo_clear = FSCR.clear;
    assign read_fifo = FSCR.read_fifo;

    typedef struct packed {
        logic [20:0] res;
        logic [4:0] fmi;
        logic EXT;
        logic RTR;
        logic [3:0] size;
    } FIR_t; //FIFO packet info register 0x000c

    FIR_t FIR;

    typedef struct packed {
        logic [2:0] res;
        logic [28:0] ID;
    } FIDR_t; //FIFO ID register 0x0010

    FIDR_t FIDR;

    reg [31:0] FDLR; //FIFO data low register 0x0014
    reg [31:0] FDHR; //FIFO data high register 0x0018

    reg [31:0] FMER; //Filter enable register 0x001c
    
    `ifdef SIM //vivado and yosys disagree
        reg [19:0] [31:0] filters; //filter registers 0x0020 - 0x006c
        reg [19:0] [31:0] masks; //filter mask registers 0x0070 - 0x00bc
    `else
        reg [31:0] filters[19:0]; //filter registers 0x0020 - 0x006c
        reg [31:0] masks[19:0]; //filter mask registers 0x0070 - 0x00bc
    `endif

    typedef struct packed {
        logic [10:0] res;
        logic [2:0] LEC; //last error code
        logic bus_off;
        logic error_passive;
        logic [7:0] TEC;
        logic [7:0] REC;
    } ESR_t; //Error status register 0x00c0

    ESR_t ESR;

    typedef struct packed {
        logic [15:0] res;
        logic [2:0] TS2;
        logic [2:0] TS1;
        logic [9:0] BRP;
    } TMGR_t; //timing 0x00c4
    
    TMGR_t TMGR;

    assign TS1 = TMGR.TS1 + 1;
    assign TS2 = TMGR.TS2 + 1;

    typedef struct packed {
        logic data_ready;
        logic EXT;
        logic RTR;
        logic [28:0] ID;
    } MLIDxR_t; //TX mailbox #x ID register

    MLIDxR_t [2:0] MLIDxR; //0x00c8 - 0x00d0

    typedef struct packed {
        logic [27:0] res;
        logic [3:0] DLC;
    } MLSxR_t; //TX mailbox #x packet size register

    MLSxR_t [2:0] MLSxR; //0x00d4 -0x00dc

    `ifdef SIM //vivado and yosys disagree
        reg [2:0] [31:0] MLDLxR; //TX mailbox data low registers 0x00e0 - 0x00e8
        reg [2:0] [31:0] MLDHxR; //TX mailbox data high registers 0x00ec - 0x00f4
    `else
        reg [31:0] MLDLxR[2:0]; //TX mailbox data low registers 0x00e0 - 0x00e8
        reg [31:0] MLDHxR[2:0]; //TX mailbox data high registers 0x00ec - 0x00f4
    `endif

    wire nRST = ~wb_rst_i;

    wire [31:0] data_sel;
    assign data_sel[31:24] = {8{wb_sel_i[3]}};
    assign data_sel[23:16] = {8{wb_sel_i[2]}};
    assign data_sel[15:8] = {8{wb_sel_i[1]}};
    assign data_sel[7:0] = {8{wb_sel_i[0]}};

    reg [31:0] raw_dat_o;

    assign wb_dat_o = raw_dat_o & data_sel;
    wire valid = wb_cyc_i & wb_stb_i;

    reg [1:0] chosen_mailbox;
    reg lock; //lock output while it is being transmitted

    reg [1:0] ack;
    assign wb_ack_o = ack[1] & valid;

    always @(posedge wb_clk_i, negedge nRST) begin
        if(nRST == 0) begin
            MCR <= '0;
            MSR <= '0;
            FSCR <= '0;
            FIR <= '0;
            FIDR <= '0;
            FDLR <= '0;
            FDHR <= '0;
            FMER <= '0;
            filters <= '0;
            masks <= '0;
            ESR <= '0;
            TMGR <= '0;
            MLIDxR <= '0;
            MLSxR <= '0;
            MLDLxR <= '0;
            MLDHxR <= '0;
            ack <= '0;
            raw_dat_o <= '0;
            lock <= 0;
        end
        else begin
            
            ack[0] <= wb_cyc_i & wb_stb_i;
            ack[1] <= ack[0];
            raw_dat_o <= '0;

            MCR.reset <= 1'b0;

            if(valid) begin
                case(wb_adr_i[7:2])
                    6'd0: begin
                        if(wb_we_i) MCR <= wb_dat_i & data_sel;
                        else raw_dat_o <= MCR & data_sel;
                        MCR.res <= '0;
                    end
                    6'd1: begin
                        if(~wb_we_i) raw_dat_o <= MSR & data_sel;
                        MSR.res <= '0;
                    end
                    6'd2: begin
                        if(wb_we_i) FSCR <= wb_dat_i & data_sel;
                        else raw_dat_o <= FSCR & data_sel;
                        FSCR.res <= '0;
                    end
                    6'd3: begin
                        if(~wb_we_i) raw_dat_o <= FIR & data_sel;
                        FIR.res <= '0;
                    end
                    6'd4: begin
                        if(~wb_we_i) raw_dat_o <= FIDR & data_sel;
                        FIDR.res <= '0;
                    end
                    6'd5: if(~wb_we_i) raw_dat_o <= FDLR & data_sel;
                    6'd6: if(~wb_we_i) raw_dat_o <= FDHR & data_sel;
                    6'd7: begin
                        if(wb_we_i) FMER <= wb_dat_i & data_sel;
                        else raw_dat_o <= FMER & data_sel;
                        FMER[31:20] <= '0;
                    end
                    6'd8: begin
                        if(wb_we_i) filters[0] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[0] & data_sel;
                        filters[0][31] <= 1'b0;
                    end
                    6'd9: begin
                        if(wb_we_i) filters[1] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[1] & data_sel;
                        filters[1][31] <= 1'b0;
                    end
                    6'd10: begin
                        if(wb_we_i) filters[2] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[2] & data_sel;
                        filters[2][31] <= 1'b0;
                    end
                    6'd11: begin
                        if(wb_we_i) filters[3] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[3] & data_sel;
                        filters[3][31] <= 1'b0;
                    end
                    6'd12: begin
                        if(wb_we_i) filters[4] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[4] & data_sel;
                        filters[4][31] <= 1'b0;
                    end
                    6'd13: begin
                        if(wb_we_i) filters[5] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[5] & data_sel;
                        filters[5][31] <= 1'b0;
                    end
                    6'd14: begin
                        if(wb_we_i) filters[6] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[6] & data_sel;
                        filters[6][31] <= 1'b0;
                    end
                    6'd15: begin
                        if(wb_we_i) filters[7] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[7] & data_sel;
                        filters[7][31] <= 1'b0;
                    end
                    6'd16: begin
                        if(wb_we_i) filters[8] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[8] & data_sel;
                        filters[8][31] <= 1'b0;
                    end
                    6'd17: begin
                        if(wb_we_i) filters[9] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[9] & data_sel;
                        filters[9][31] <= 1'b0;
                    end
                    6'd18: begin
                        if(wb_we_i) filters[10] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[10] & data_sel;
                        filters[10][31] <= 1'b0;
                    end
                    6'd19: begin
                        if(wb_we_i) filters[11] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[11] & data_sel;
                        filters[11][31] <= 1'b0;
                    end
                    6'd20: begin
                        if(wb_we_i) filters[12] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[12] & data_sel;
                        filters[12][31] <= 1'b0;
                    end
                    6'd21: begin
                        if(wb_we_i) filters[13] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[13] & data_sel;
                        filters[13][31] <= 1'b0;
                    end
                    6'd22: begin
                        if(wb_we_i) filters[14] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[14] & data_sel;
                        filters[14][31] <= 1'b0;
                    end
                    6'd23: begin
                        if(wb_we_i) filters[15] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[15] & data_sel;
                        filters[15][31] <= 1'b0;
                    end
                    6'd24: begin
                        if(wb_we_i) filters[16] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[16] & data_sel;
                        filters[16][31] <= 1'b0;
                    end
                    6'd25: begin
                        if(wb_we_i) filters[17] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[17] & data_sel;
                        filters[17][31] <= 1'b0;
                    end
                    6'd26: begin
                        if(wb_we_i) filters[18] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[18] & data_sel;
                        filters[18][31] <= 1'b0;
                    end
                    6'd27: begin
                        if(wb_we_i) filters[19] <= wb_dat_i & data_sel;
                        else raw_dat_o <= filters[19] & data_sel;
                        filters[19][31] <= 1'b0;
                    end
                    6'd28: begin
                        if(wb_we_i) masks[0] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[0] & data_sel;
                        masks[0][31] <= 1'b0;
                    end
                    6'd29: begin
                        if(wb_we_i) masks[1] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[1] & data_sel;
                        masks[1][31] <= 1'b0;
                    end
                    6'd30: begin
                        if(wb_we_i) masks[2] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[2] & data_sel;
                        masks[2][31] <= 1'b0;
                    end
                    6'd31: begin
                        if(wb_we_i) masks[3] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[3] & data_sel;
                        masks[3][31] <= 1'b0;
                    end
                    6'd32: begin
                        if(wb_we_i) masks[4] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[4] & data_sel;
                        masks[4][31] <= 1'b0;
                    end
                    6'd33: begin
                        if(wb_we_i) masks[5] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[5] & data_sel;
                        masks[5][31] <= 1'b0;
                    end
                    6'd34: begin
                        if(wb_we_i) masks[6] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[6] & data_sel;
                        masks[6][31] <= 1'b0;
                    end
                    6'd35: begin
                        if(wb_we_i) masks[7] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[7] & data_sel;
                        masks[7][31] <= 1'b0;
                    end
                    6'd36: begin
                        if(wb_we_i) masks[8] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[8] & data_sel;
                        masks[8][31] <= 1'b0;
                    end
                    6'd37: begin
                        if(wb_we_i) masks[9] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[9] & data_sel;
                        masks[9][31] <= 1'b0;
                    end
                    6'd38: begin
                        if(wb_we_i) masks[10] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[10] & data_sel;
                        masks[10][31] <= 1'b0;
                    end
                    6'd39: begin
                        if(wb_we_i) masks[11] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[11] & data_sel;
                        masks[11][31] <= 1'b0;
                    end
                    6'd40: begin
                        if(wb_we_i) masks[12] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[12] & data_sel;
                        masks[12][31] <= 1'b0;
                    end
                    6'd41: begin
                        if(wb_we_i) masks[13] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[13] & data_sel;
                        masks[13][31] <= 1'b0;
                    end
                    6'd42: begin
                        if(wb_we_i) masks[14] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[14] & data_sel;
                        masks[14][31] <= 1'b0;
                    end
                    6'd43: begin
                        if(wb_we_i) masks[15] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[15] & data_sel;
                        masks[15][31] <= 1'b0;
                    end
                    6'd44: begin
                        if(wb_we_i) masks[16] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[16] & data_sel;
                        masks[16][31] <= 1'b0;
                    end
                    6'd45: begin
                        if(wb_we_i) masks[17] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[17] & data_sel;
                        masks[17][31] <= 1'b0;
                    end
                    6'd46: begin
                        if(wb_we_i) masks[18] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[18] & data_sel;
                        masks[18][31] <= 1'b0;
                    end
                    6'd47: begin
                        if(wb_we_i) masks[19] <= wb_dat_i & data_sel;
                        else raw_dat_o <= masks[19] & data_sel;
                        masks[19][31] <= 1'b0;
                    end
                    6'd48: begin
                        if(~wb_we_i) raw_dat_o <= ESR & data_sel;
                        ESR.res <= '0;
                    end
                    6'd49: begin
                        if(wb_we_i) TMGR <= wb_dat_i & data_sel;
                        else raw_dat_o = TMGR & data_sel;
                        TMGR.res <= '0;
                    end
                    6'd50: begin
                        if(wb_we_i) MLIDxR[0] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLIDxR[0] & data_sel;
                    end
                    6'd51: begin
                        if(wb_we_i) MLIDxR[1] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLIDxR[1] & data_sel;
                    end
                    6'd52: begin
                        if(wb_we_i) MLIDxR[2] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLIDxR[2] & data_sel;
                    end
                    6'd53: begin
                        if(wb_we_i) MLSxR[0] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLSxR[0] & data_sel;
                        MLSxR[0].res <= '0;
                    end
                    6'd54: begin
                        if(wb_we_i) MLSxR[1] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLSxR[1] & data_sel;
                        MLSxR[1].res <= '0;
                    end
                    6'd55: begin
                        if(wb_we_i) MLSxR[2] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLSxR[2] & data_sel;
                        MLSxR[2].res <= '0;
                    end
                    6'd56: begin
                        if(wb_we_i) MLDLxR[0] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLDLxR[0] & data_sel;
                    end
                    6'd57: begin
                        if(wb_we_i) MLDLxR[1] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLDLxR[1] & data_sel;
                    end
                    6'd58: begin
                        if(wb_we_i) MLDLxR[2] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLDLxR[2] & data_sel;
                    end
                    6'd59: begin
                        if(wb_we_i) MLDHxR[0] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLDHxR[0] & data_sel;
                    end
                    6'd60: begin
                        if(wb_we_i) MLDHxR[1] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLDHxR[1] & data_sel;
                    end
                    6'd61: begin
                        if(wb_we_i) MLDHxR[2] <= wb_dat_i & data_sel;
                        else raw_dat_o <= MLDHxR[2] & data_sel;
                    end
                    default: raw_dat_o <= 0;
                endcase
            end

            if(~(valid)) raw_dat_o <= '0;

            MCR.reset <= 1'b0;
            FSCR.clear <= 1'b0;
            if(MSR.mode == 0) MCR.sleep <= 1'b0;

            MSR.curr_sample <= curr_sample;
            MSR.rx_busy <= rx_busy;
            MSR.tx_busy <= tx_busy;
            FSCR.overrun <= fifo_overrun;
            FSCR.occupancy <= fifo_occupancy;
            FSCR.full <= fifo_full;
            FSCR.empty <= fifo_empty;
            FIR.size <= fifo_pkt_size;
            FIR.RTR <= fifo_RTR;
            FIR.EXT <= fifo_EXT;
            FIR.fmi <= fifo_fmi;
            FIDR.ID <= fifo_ID;
            ESR.REC <= REC;
            ESR.TEC <= TEC;
            ESR.error_passive <= error_passive;
            ESR.bus_off <= bus_off;
            ESR.LEC <= LEC;
            FDLR <= fifo_data_L;
            FDHR <= fifo_data_H;

            if(fifo_read) FSCR.read_fifo <= '0;
            if(tx_done) begin
                MLIDxR[chosen_mailbox].data_ready <= 0;
                lock <= 0;
            end
            else if(~MCR.auto_retrans && tx_arb_loss) begin
                MLIDxR[chosen_mailbox].data_ready <= 0;
                lock <= 0;
            end

        end
    end

    reg enable_CAN, next_enable_CAN;
    reg [1:0] next_MSR_mode;

    wire TX_clear;

    always_ff @(posedge wb_clk_i, negedge nRST) begin //might need to integrate this into main always block
        if(nRST == 0) begin
            enable_CAN <= 1'b0;
            MSR.mode <= '0;
        end
        else begin
            enable_CAN <= next_enable_CAN;
            MSR.mode <= next_MSR_mode;
        end
    end

    always_comb begin
        next_enable_CAN = enable_CAN;
        next_MSR_mode = MSR.mode;
        case(MSR.mode)
            2'b00: begin
                if(MCR.start) begin
                    next_MSR_mode = 2'b01;
                    next_enable_CAN = 1'b1;
                end
            end
            2'b01: if(TX_clear) next_MSR_mode = 2'b10;
            2'b10: begin
                if(MCR.sleep && ~tx_busy) begin
                    next_MSR_mode = 2'b00;
                    next_enable_CAN = 1'b0;
                end
            end
        endcase
    end

    assign CAN_nRST = nRST & ~MCR.reset;
    assign tx_enable = MSR.mode == 2;

    wire [10:0] BRP = TMGR.BRP + 1;
    reg [10:0] prescaler_count;

    always @(posedge wb_clk_i, negedge nRST) begin
        if(nRST == 0) begin
            prescaler_count <= '0;
            CAN_clk <= '0;
        end
        else if(enable_CAN) begin
            if(prescaler_count == BRP) begin
                prescaler_count <= 1;
                CAN_clk <= 1;
            end
            else begin
                prescaler_count <= prescaler_count + 1;
                CAN_clk <= 0;
            end
        end
    end

    flex_counter #(
        .NUM_CNT_BITS(4)
    )
    TX_CLEAR(
        .clk(bitstrobe),
        .n_rst(nRST),
        .clear(~curr_sample),
        .count_enable(curr_sample),
        .rollover_val(4'd11),
        .count_out(),
        .rollover_flag(TX_clear)
    );

    assign filter_0 = filters[0][30:0];
    assign mask_0 = masks[0][30:0];
    assign filter_1 = filters[1][30:0];
    assign mask_1 = masks[1][30:0];
    assign filter_2 = filters[2][30:0];
    assign mask_2 = masks[2][30:0];
    assign filter_3 = filters[3][30:0];
    assign mask_3 = masks[3][30:0];
    assign filter_4 = filters[4][30:0];
    assign mask_4 = masks[4][30:0];
    assign filter_5 = filters[5][30:0];
    assign mask_5 = masks[5][30:0];
    assign filter_6 = filters[6][30:0];
    assign mask_6 = masks[6][30:0];
    assign filter_7 = filters[7][30:0];
    assign mask_7 = masks[7][30:0];
    assign filter_8 = filters[8][30:0];
    assign mask_8 = masks[8][30:0];
    assign filter_9 = filters[9][30:0];
    assign mask_9 = masks[9][30:0];
    assign filter_10 = filters[10][30:0];
    assign mask_10 = masks[10][30:0];
    assign filter_11 = filters[11][30:0];
    assign mask_11 = masks[11][30:0];
    assign filter_12 = filters[12][30:0];
    assign mask_12 = masks[12][30:0];
    assign filter_13 = filters[13][30:0];
    assign mask_13 = masks[13][30:0];
    assign filter_14 = filters[14][30:0];
    assign mask_14 = masks[14][30:0];
    assign filter_15 = filters[15][30:0];
    assign mask_15 = masks[15][30:0];
    assign filter_16 = filters[16][30:0];
    assign mask_16 = masks[16][30:0];
    assign filter_17 = filters[17][30:0];
    assign mask_17 = masks[17][30:0];
    assign filter_18 = filters[18][30:0];
    assign mask_18 = masks[18][30:0];
    assign filter_19 = filters[19][30:0];
    assign mask_19 = masks[19][30:0];

    assign mask_enable = FMER[19:0];


    //WARNING: need to make sure to hold while mailbox is being read

    always_ff @(posedge wb_clk_i, negedge nRST) begin
        if(nRST == 0) begin
            tx_pkt_ready <= '0;
            tx_ID <= '0;
            tx_pkt_size <= '0;
            tx_RTR <= '0;
            tx_EXT <= '0;
            tx_data <= '0;
            chosen_mailbox <= '0;
        end
        else begin
            if(MCR.tx_priority & ~lock) begin
                if(MLIDxR[0].data_ready) begin
                    tx_pkt_ready <= 1;
                    tx_ID <= MLIDxR[0].ID;
                    tx_pkt_size <= MLSxR[0].DLC;
                    tx_RTR <= MLIDxR[0].RTR;
                    tx_EXT <= MLIDxR[0].EXT;
                    tx_data <= {MLDHxR[0], MLDLxR[0]};
                    chosen_mailbox <= '0;
                    lock <= 1;
                end
                else if(MLIDxR[1].data_ready) begin
                    tx_pkt_ready <= 1;
                    tx_ID <= MLIDxR[1].ID;
                    tx_pkt_size <= MLSxR[1].DLC;
                    tx_RTR <= MLIDxR[1].RTR;
                    tx_EXT <= MLIDxR[1].EXT;
                    tx_data <= {MLDHxR[1], MLDLxR[1]};
                    chosen_mailbox <= 1;
                    lock <= 1;
                end
                else if(MLIDxR[2].data_ready) begin
                    tx_pkt_ready <= 1;
                    tx_ID <= MLIDxR[2].ID;
                    tx_pkt_size <= MLSxR[2].DLC;
                    tx_RTR <= MLIDxR[2].RTR;
                    tx_EXT <= MLIDxR[2].EXT;
                    tx_data <= {MLDHxR[2], MLDLxR[2]};
                    chosen_mailbox <= 2;
                    lock <= 1;
                end
                else begin
                    tx_pkt_ready <= 0;
                    chosen_mailbox <= '0;
                    lock <= 0;
                end
            end
            else if(~lock) begin
                case({MLIDxR[2].data_ready, MLIDxR[1].data_ready, MLIDxR[0].data_ready})
                    3'b001: begin
                        tx_pkt_ready <= 1;
                        tx_ID <= MLIDxR[0].ID;
                        tx_pkt_size <= MLSxR[0].DLC;
                        tx_RTR <= MLIDxR[0].RTR;
                        tx_EXT <= MLIDxR[0].EXT;
                        tx_data <= {MLDHxR[0], MLDLxR[0]};
                        chosen_mailbox <= '0;
                        lock <= 1;
                    end
                    3'b010: begin
                        tx_pkt_ready <= 1;
                        tx_ID <= MLIDxR[1].ID;
                        tx_pkt_size <= MLSxR[1].DLC;
                        tx_RTR <= MLIDxR[1].RTR;
                        tx_EXT <= MLIDxR[1].EXT;
                        tx_data <= {MLDHxR[1], MLDLxR[1]};
                        chosen_mailbox <= 1;
                        lock <= 1;
                    end
                    3'b100: begin
                        tx_pkt_ready <= 1;
                        tx_ID <= MLIDxR[2].ID;
                        tx_pkt_size <= MLSxR[2].DLC;
                        tx_RTR <= MLIDxR[2].RTR;
                        tx_EXT <= MLIDxR[2].EXT;
                        tx_data <= {MLDHxR[2], MLDLxR[2]};
                        chosen_mailbox <= 2;
                        lock <= 1;
                    end
                    3'b011: begin
                        if(MLIDxR[0].ID <= MLIDxR[1].ID) begin
                            tx_pkt_ready <= 1;
                            tx_ID <= MLIDxR[0].ID;
                            tx_pkt_size <= MLSxR[0].DLC;
                            tx_RTR <= MLIDxR[0].RTR;
                            tx_EXT <= MLIDxR[0].EXT;
                            tx_data <= {MLDHxR[0], MLDLxR[0]};
                            chosen_mailbox <= '0;
                            lock <= 1;
                        end
                        else begin
                            tx_pkt_ready <= 1;
                            tx_ID <= MLIDxR[1].ID;
                            tx_pkt_size <= MLSxR[1].DLC;
                            tx_RTR <= MLIDxR[1].RTR;
                            tx_EXT <= MLIDxR[1].EXT;
                            tx_data <= {MLDHxR[1], MLDLxR[1]};
                            chosen_mailbox <= 1;
                            lock <= 1;
                        end
                    end
                    3'b101: begin
                        if(MLIDxR[0].ID <= MLIDxR[2].ID) begin
                            tx_pkt_ready <= 1;
                            tx_ID <= MLIDxR[0].ID;
                            tx_pkt_size <= MLSxR[0].DLC;
                            tx_RTR <= MLIDxR[0].RTR;
                            tx_EXT <= MLIDxR[0].EXT;
                            tx_data <= {MLDHxR[0], MLDLxR[0]};
                            chosen_mailbox <= '0;
                            lock <= 1;
                        end
                        else begin
                            tx_pkt_ready <= 1;
                            tx_ID <= MLIDxR[2].ID;
                            tx_pkt_size <= MLSxR[2].DLC;
                            tx_RTR <= MLIDxR[2].RTR;
                            tx_EXT <= MLIDxR[2].EXT;
                            tx_data <= {MLDHxR[2], MLDLxR[2]};
                            chosen_mailbox <= 2;
                            lock <= 1;
                        end
                    end
                    3'b110: begin
                        if(MLIDxR[1].ID <= MLIDxR[2].ID) begin
                            tx_pkt_ready <= 1;
                            tx_ID <= MLIDxR[1].ID;
                            tx_pkt_size <= MLSxR[1].DLC;
                            tx_RTR <= MLIDxR[1].RTR;
                            tx_EXT <= MLIDxR[1].EXT;
                            tx_data <= {MLDHxR[1], MLDLxR[1]};
                            chosen_mailbox <= 1;
                            lock <= 1;
                        end
                        else begin
                            tx_pkt_ready <= 1;
                            tx_ID <= MLIDxR[2].ID;
                            tx_pkt_size <= MLSxR[2].DLC;
                            tx_RTR <= MLIDxR[2].RTR;
                            tx_EXT <= MLIDxR[2].EXT;
                            tx_data <= {MLDHxR[2], MLDLxR[2]};
                            chosen_mailbox <= 2;
                            lock <= 1;
                        end
                    end
                    3'b111: begin
                        if(MLIDxR[0].ID <= MLIDxR[1].ID) begin
                            if(MLIDxR[0].ID <= MLIDxR[2].ID) begin
                                tx_pkt_ready <= 1;
                                tx_ID <= MLIDxR[0].ID;
                                tx_pkt_size <= MLSxR[0].DLC;
                                tx_RTR <= MLIDxR[0].RTR;
                                tx_EXT <= MLIDxR[0].EXT;
                                tx_data <= {MLDHxR[0], MLDLxR[0]};
                                chosen_mailbox <= '0;
                                lock <= 1;
                            end
                            else begin
                                tx_pkt_ready <= 1;
                                tx_ID <= MLIDxR[2].ID;
                                tx_pkt_size <= MLSxR[2].DLC;
                                tx_RTR <= MLIDxR[2].RTR;
                                tx_EXT <= MLIDxR[2].EXT;
                                tx_data <= {MLDHxR[2], MLDLxR[2]};
                                chosen_mailbox <= 2;
                                lock <= 1;
                            end
                        end
                        else if(MLIDxR[1].ID <= MLIDxR[2].ID) begin
                            tx_pkt_ready <= 1;
                            tx_ID <= MLIDxR[1].ID;
                            tx_pkt_size <= MLSxR[1].DLC;
                            tx_RTR <= MLIDxR[1].RTR;
                            tx_EXT <= MLIDxR[1].EXT;
                            tx_data <= {MLDHxR[1], MLDLxR[1]};
                            chosen_mailbox <= 1;
                            lock <= 1;
                        end
                        else begin
                            tx_pkt_ready <= 1;
                            tx_ID <= MLIDxR[2].ID;
                            tx_pkt_size <= MLSxR[2].DLC;
                            tx_RTR <= MLIDxR[2].RTR;
                            tx_EXT <= MLIDxR[2].EXT;
                            tx_data <= {MLDHxR[2], MLDLxR[2]};
                            chosen_mailbox <= 2;
                            lock <= 1;
                        end
                    end
                    default: begin
                        tx_pkt_ready <= 0;
                        chosen_mailbox <= '0;
                        lock <= 0;
                    end
                endcase
            end
        end
    end

endmodule