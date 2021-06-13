module wb_slave (
	wb_clk_i,
	wb_rst_i,
	wb_adr_i,
	wb_dat_i,
	wb_sel_i,
	wb_we_i,
	wb_cyc_i,
	wb_stb_i,
	wb_ack_o,
	wb_dat_o,
	bitstrobe,
	curr_sample,
	rx_busy,
	tx_busy,
	CAN_clk,
	CAN_nRST,
	tx_enable,
	TS1,
	TS2,
	REC,
	TEC,
	error_passive,
	bus_off,
	LEC,
	fifo_occupancy,
	fifo_full,
	fifo_empty,
	fifo_overrun,
	fifo_data_L,
	fifo_data_H,
	fifo_ID,
	fifo_pkt_size,
	fifo_RTR,
	fifo_EXT,
	fifo_fmi,
	fifo_read,
	fifo_clear,
	overrun_enable,
	mask_enable,
	filter_0,
	mask_0,
	filter_1,
	mask_1,
	filter_2,
	mask_2,
	filter_3,
	mask_3,
	filter_4,
	mask_4,
	filter_5,
	mask_5,
	filter_6,
	mask_6,
	filter_7,
	mask_7,
	filter_8,
	mask_8,
	filter_9,
	mask_9,
	filter_10,
	mask_10,
	filter_11,
	mask_11,
	filter_12,
	mask_12,
	filter_13,
	mask_13,
	filter_14,
	mask_14,
	filter_15,
	mask_15,
	filter_16,
	mask_16,
	filter_17,
	mask_17,
	filter_18,
	mask_18,
	filter_19,
	mask_19,
	read_fifo,
	tx_done,
	tx_arb_loss,
	tx_pkt_ready,
	tx_ID,
	tx_pkt_size,
	tx_RTR,
	tx_EXT,
	tx_data
);
	input wb_clk_i;
	input wb_rst_i;
	input [31:0] wb_adr_i;
	input [31:0] wb_dat_i;
	input [3:0] wb_sel_i;
	input wb_we_i;
	input wb_cyc_i;
	input wb_stb_i;
	output wb_ack_o;
	output [31:0] wb_dat_o;
	input bitstrobe;
	input curr_sample;
	input rx_busy;
	input tx_busy;
	output reg CAN_clk;
	output CAN_nRST;
	output tx_enable;
	output [3:0] TS1;
	output [3:0] TS2;
	input [7:0] REC;
	input [7:0] TEC;
	input error_passive;
	input bus_off;
	input [2:0] LEC;
	input [3:0] fifo_occupancy;
	input fifo_full;
	input fifo_empty;
	input fifo_overrun;
	input [31:0] fifo_data_L;
	input [31:0] fifo_data_H;
	input [28:0] fifo_ID;
	input [3:0] fifo_pkt_size;
	input fifo_RTR;
	input fifo_EXT;
	input [4:0] fifo_fmi;
	input fifo_read;
	output fifo_clear;
	output overrun_enable;
	output [19:0] mask_enable;
	output [30:0] filter_0;
	output [30:0] mask_0;
	output [30:0] filter_1;
	output [30:0] mask_1;
	output [30:0] filter_2;
	output [30:0] mask_2;
	output [30:0] filter_3;
	output [30:0] mask_3;
	output [30:0] filter_4;
	output [30:0] mask_4;
	output [30:0] filter_5;
	output [30:0] mask_5;
	output [30:0] filter_6;
	output [30:0] mask_6;
	output [30:0] filter_7;
	output [30:0] mask_7;
	output [30:0] filter_8;
	output [30:0] mask_8;
	output [30:0] filter_9;
	output [30:0] mask_9;
	output [30:0] filter_10;
	output [30:0] mask_10;
	output [30:0] filter_11;
	output [30:0] mask_11;
	output [30:0] filter_12;
	output [30:0] mask_12;
	output [30:0] filter_13;
	output [30:0] mask_13;
	output [30:0] filter_14;
	output [30:0] mask_14;
	output [30:0] filter_15;
	output [30:0] mask_15;
	output [30:0] filter_16;
	output [30:0] mask_16;
	output [30:0] filter_17;
	output [30:0] mask_17;
	output [30:0] filter_18;
	output [30:0] mask_18;
	output [30:0] filter_19;
	output [30:0] mask_19;
	output read_fifo;
	input tx_done;
	input tx_arb_loss;
	output reg tx_pkt_ready;
	output reg [28:0] tx_ID;
	output reg [3:0] tx_pkt_size;
	output reg tx_RTR;
	output reg tx_EXT;
	output reg [63:0] tx_data;
	localparam BASE_ADDR = 32'h30000000;
	reg [31:0] MCR;
	assign overrun_enable = MCR[5];
	reg [31:0] MSR;
	reg [31:0] FSCR;
	assign fifo_clear = FSCR[0];
	assign read_fifo = FSCR[1];
	reg [31:0] FIR;
	reg [31:0] FIDR;
	reg [31:0] FDLR;
	reg [31:0] FDHR;
	reg [31:0] FMER;
	reg [639:0] filters;
	reg [639:0] masks;
	reg [31:0] ESR;
	reg [31:0] TMGR;
	assign TS1 = TMGR[12-:3] + 1;
	assign TS2 = TMGR[15-:3] + 1;
	reg [95:0] MLIDxR;
	reg [95:0] MLSxR;
	reg [95:0] MLDLxR;
	reg [95:0] MLDHxR;
	wire nRST = ~wb_rst_i;
	wire [31:0] data_sel;
	assign data_sel[31:24] = {8 {wb_sel_i[3]}};
	assign data_sel[23:16] = {8 {wb_sel_i[2]}};
	assign data_sel[15:8] = {8 {wb_sel_i[1]}};
	assign data_sel[7:0] = {8 {wb_sel_i[0]}};
	reg [31:0] raw_dat_o;
	assign wb_dat_o = raw_dat_o & data_sel;
	wire valid = wb_cyc_i & wb_stb_i;
	reg [1:0] chosen_mailbox;
	reg lock;
	reg [1:0] ack;
	assign wb_ack_o = ack[1] & valid;
	always @(posedge wb_clk_i or negedge nRST)
		if (nRST == 0) begin
			MCR <= {32 {1'sb0}};
			MSR <= {32 {1'sb0}};
			FSCR <= {32 {1'sb0}};
			FIR <= {32 {1'sb0}};
			FIDR <= {32 {1'sb0}};
			FDLR <= {32 {1'sb0}};
			FDHR <= {32 {1'sb0}};
			FMER <= {32 {1'sb0}};
			filters <= {640 {1'sb0}};
			masks <= {640 {1'sb0}};
			ESR <= {32 {1'sb0}};
			TMGR <= {32 {1'sb0}};
			MLIDxR <= {96 {1'sb0}};
			MLSxR <= {96 {1'sb0}};
			MLDLxR <= {96 {1'sb0}};
			MLDHxR <= {96 {1'sb0}};
			ack <= {2 {1'sb0}};
			raw_dat_o <= {32 {1'sb0}};
			lock <= 0;
		end
		else begin
			ack[0] <= wb_cyc_i & wb_stb_i;
			ack[1] <= ack[0];
			raw_dat_o <= {32 {1'sb0}};
			MCR[1] <= 1'b0;
			if (valid)
				case (wb_adr_i[7:2])
					6'd0: begin
						if (wb_we_i)
							MCR <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MCR & data_sel;
						MCR[31-:26] <= {26 {1'sb0}};
					end
					6'd1: begin
						if (~wb_we_i)
							raw_dat_o <= MSR & data_sel;
						MSR[31-:27] <= {27 {1'sb0}};
					end
					6'd2: begin
						if (wb_we_i)
							FSCR <= wb_dat_i & data_sel;
						else
							raw_dat_o <= FSCR & data_sel;
						FSCR[31-:23] <= {23 {1'sb0}};
					end
					6'd3: begin
						if (~wb_we_i)
							raw_dat_o <= FIR & data_sel;
						FIR[31-:21] <= {21 {1'sb0}};
					end
					6'd4: begin
						if (~wb_we_i)
							raw_dat_o <= FIDR & data_sel;
						FIDR[31-:3] <= {3 {1'sb0}};
					end
					6'd5:
						if (~wb_we_i)
							raw_dat_o <= FDLR & data_sel;
					6'd6:
						if (~wb_we_i)
							raw_dat_o <= FDHR & data_sel;
					6'd7: begin
						if (wb_we_i)
							FMER <= wb_dat_i & data_sel;
						else
							raw_dat_o <= FMER & data_sel;
						FMER[31:20] <= {12 {1'sb0}};
					end
					6'd8: begin
						if (wb_we_i)
							filters[0+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[0+:32] & data_sel;
						filters[31] <= 1'b0;
					end
					6'd9: begin
						if (wb_we_i)
							filters[32+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[32+:32] & data_sel;
						filters[63] <= 1'b0;
					end
					6'd10: begin
						if (wb_we_i)
							filters[64+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[64+:32] & data_sel;
						filters[95] <= 1'b0;
					end
					6'd11: begin
						if (wb_we_i)
							filters[96+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[96+:32] & data_sel;
						filters[127] <= 1'b0;
					end
					6'd12: begin
						if (wb_we_i)
							filters[128+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[128+:32] & data_sel;
						filters[159] <= 1'b0;
					end
					6'd13: begin
						if (wb_we_i)
							filters[160+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[160+:32] & data_sel;
						filters[191] <= 1'b0;
					end
					6'd14: begin
						if (wb_we_i)
							filters[192+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[192+:32] & data_sel;
						filters[223] <= 1'b0;
					end
					6'd15: begin
						if (wb_we_i)
							filters[224+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[224+:32] & data_sel;
						filters[255] <= 1'b0;
					end
					6'd16: begin
						if (wb_we_i)
							filters[256+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[256+:32] & data_sel;
						filters[287] <= 1'b0;
					end
					6'd17: begin
						if (wb_we_i)
							filters[288+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[288+:32] & data_sel;
						filters[319] <= 1'b0;
					end
					6'd18: begin
						if (wb_we_i)
							filters[320+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[320+:32] & data_sel;
						filters[351] <= 1'b0;
					end
					6'd19: begin
						if (wb_we_i)
							filters[352+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[352+:32] & data_sel;
						filters[383] <= 1'b0;
					end
					6'd20: begin
						if (wb_we_i)
							filters[384+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[384+:32] & data_sel;
						filters[415] <= 1'b0;
					end
					6'd21: begin
						if (wb_we_i)
							filters[416+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[416+:32] & data_sel;
						filters[447] <= 1'b0;
					end
					6'd22: begin
						if (wb_we_i)
							filters[448+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[448+:32] & data_sel;
						filters[479] <= 1'b0;
					end
					6'd23: begin
						if (wb_we_i)
							filters[480+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[480+:32] & data_sel;
						filters[511] <= 1'b0;
					end
					6'd24: begin
						if (wb_we_i)
							filters[512+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[512+:32] & data_sel;
						filters[543] <= 1'b0;
					end
					6'd25: begin
						if (wb_we_i)
							filters[544+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[544+:32] & data_sel;
						filters[575] <= 1'b0;
					end
					6'd26: begin
						if (wb_we_i)
							filters[576+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[576+:32] & data_sel;
						filters[607] <= 1'b0;
					end
					6'd27: begin
						if (wb_we_i)
							filters[608+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= filters[608+:32] & data_sel;
						filters[639] <= 1'b0;
					end
					6'd28: begin
						if (wb_we_i)
							masks[0+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[0+:32] & data_sel;
						masks[31] <= 1'b0;
					end
					6'd29: begin
						if (wb_we_i)
							masks[32+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[32+:32] & data_sel;
						masks[63] <= 1'b0;
					end
					6'd30: begin
						if (wb_we_i)
							masks[64+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[64+:32] & data_sel;
						masks[95] <= 1'b0;
					end
					6'd31: begin
						if (wb_we_i)
							masks[96+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[96+:32] & data_sel;
						masks[127] <= 1'b0;
					end
					6'd32: begin
						if (wb_we_i)
							masks[128+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[128+:32] & data_sel;
						masks[159] <= 1'b0;
					end
					6'd33: begin
						if (wb_we_i)
							masks[160+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[160+:32] & data_sel;
						masks[191] <= 1'b0;
					end
					6'd34: begin
						if (wb_we_i)
							masks[192+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[192+:32] & data_sel;
						masks[223] <= 1'b0;
					end
					6'd35: begin
						if (wb_we_i)
							masks[224+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[224+:32] & data_sel;
						masks[255] <= 1'b0;
					end
					6'd36: begin
						if (wb_we_i)
							masks[256+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[256+:32] & data_sel;
						masks[287] <= 1'b0;
					end
					6'd37: begin
						if (wb_we_i)
							masks[288+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[288+:32] & data_sel;
						masks[319] <= 1'b0;
					end
					6'd38: begin
						if (wb_we_i)
							masks[320+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[320+:32] & data_sel;
						masks[351] <= 1'b0;
					end
					6'd39: begin
						if (wb_we_i)
							masks[352+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[352+:32] & data_sel;
						masks[383] <= 1'b0;
					end
					6'd40: begin
						if (wb_we_i)
							masks[384+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[384+:32] & data_sel;
						masks[415] <= 1'b0;
					end
					6'd41: begin
						if (wb_we_i)
							masks[416+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[416+:32] & data_sel;
						masks[447] <= 1'b0;
					end
					6'd42: begin
						if (wb_we_i)
							masks[448+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[448+:32] & data_sel;
						masks[479] <= 1'b0;
					end
					6'd43: begin
						if (wb_we_i)
							masks[480+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[480+:32] & data_sel;
						masks[511] <= 1'b0;
					end
					6'd44: begin
						if (wb_we_i)
							masks[512+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[512+:32] & data_sel;
						masks[543] <= 1'b0;
					end
					6'd45: begin
						if (wb_we_i)
							masks[544+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[544+:32] & data_sel;
						masks[575] <= 1'b0;
					end
					6'd46: begin
						if (wb_we_i)
							masks[576+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[576+:32] & data_sel;
						masks[607] <= 1'b0;
					end
					6'd47: begin
						if (wb_we_i)
							masks[608+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= masks[608+:32] & data_sel;
						masks[639] <= 1'b0;
					end
					6'd48: begin
						if (~wb_we_i)
							raw_dat_o <= ESR & data_sel;
						ESR[31-:11] <= {11 {1'sb0}};
					end
					6'd49: begin
						if (wb_we_i)
							TMGR <= wb_dat_i & data_sel;
						else
							raw_dat_o = TMGR & data_sel;
						TMGR[31-:16] <= {16 {1'sb0}};
					end
					6'd50:
						if (wb_we_i)
							MLIDxR[0+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLIDxR[0+:32] & data_sel;
					6'd51:
						if (wb_we_i)
							MLIDxR[32+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLIDxR[32+:32] & data_sel;
					6'd52:
						if (wb_we_i)
							MLIDxR[64+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLIDxR[64+:32] & data_sel;
					6'd53: begin
						if (wb_we_i)
							MLSxR[0+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLSxR[0+:32] & data_sel;
						MLSxR[31-:28] <= {28 {1'sb0}};
					end
					6'd54: begin
						if (wb_we_i)
							MLSxR[32+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLSxR[32+:32] & data_sel;
						MLSxR[63-:28] <= {28 {1'sb0}};
					end
					6'd55: begin
						if (wb_we_i)
							MLSxR[64+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLSxR[64+:32] & data_sel;
						MLSxR[95-:28] <= {28 {1'sb0}};
					end
					6'd56:
						if (wb_we_i)
							MLDLxR[0+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLDLxR[0+:32] & data_sel;
					6'd57:
						if (wb_we_i)
							MLDLxR[32+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLDLxR[32+:32] & data_sel;
					6'd58:
						if (wb_we_i)
							MLDLxR[64+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLDLxR[64+:32] & data_sel;
					6'd59:
						if (wb_we_i)
							MLDHxR[0+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLDHxR[0+:32] & data_sel;
					6'd60:
						if (wb_we_i)
							MLDHxR[32+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLDHxR[32+:32] & data_sel;
					6'd61:
						if (wb_we_i)
							MLDHxR[64+:32] <= wb_dat_i & data_sel;
						else
							raw_dat_o <= MLDHxR[64+:32] & data_sel;
					default: raw_dat_o <= 0;
				endcase
			if (~valid)
				raw_dat_o <= {32 {1'sb0}};
			MCR[1] <= 1'b0;
			FSCR[0] <= 1'b0;
			if (MSR[1-:2] == 0)
				MCR[2] <= 1'b0;
			MSR[2] <= curr_sample;
			MSR[3] <= rx_busy;
			MSR[4] <= tx_busy;
			FSCR[2] <= fifo_overrun;
			FSCR[6-:4] <= fifo_occupancy;
			FSCR[7] <= fifo_full;
			FSCR[8] <= fifo_empty;
			FIR[3-:4] <= fifo_pkt_size;
			FIR[4] <= fifo_RTR;
			FIR[5] <= fifo_EXT;
			FIR[10-:5] <= fifo_fmi;
			FIDR[28-:29] <= fifo_ID;
			ESR[7-:8] <= REC;
			ESR[15-:8] <= TEC;
			ESR[16] <= error_passive;
			ESR[17] <= bus_off;
			ESR[20-:3] <= LEC;
			FDLR <= fifo_data_L;
			FDHR <= fifo_data_H;
			if (fifo_read)
				FSCR[1] <= 1'b0;
			if (tx_done) begin
				MLIDxR[(chosen_mailbox * 32) + 31] <= 0;
				lock <= 0;
			end
			else if (~MCR[4] && tx_arb_loss) begin
				MLIDxR[(chosen_mailbox * 32) + 31] <= 0;
				lock <= 0;
			end
		end
	reg enable_CAN;
	reg next_enable_CAN;
	reg [1:0] next_MSR_mode;
	wire TX_clear;
	always @(posedge wb_clk_i or negedge nRST)
		if (nRST == 0) begin
			enable_CAN <= 1'b0;
			MSR[1-:2] <= {2 {1'sb0}};
		end
		else begin
			enable_CAN <= next_enable_CAN;
			MSR[1-:2] <= next_MSR_mode;
		end
	always @(*) begin
		next_enable_CAN = enable_CAN;
		next_MSR_mode = MSR[1-:2];
		case (MSR[1-:2])
			2'b00:
				if (MCR[0]) begin
					next_MSR_mode = 2'b01;
					next_enable_CAN = 1'b1;
				end
			2'b01:
				if (TX_clear)
					next_MSR_mode = 2'b10;
			2'b10:
				if (MCR[2] && ~tx_busy) begin
					next_MSR_mode = 2'b00;
					next_enable_CAN = 1'b0;
				end
		endcase
	end
	assign CAN_nRST = nRST & ~MCR[1];
	assign tx_enable = MSR[1-:2] == 2;
	wire [10:0] BRP = TMGR[9-:10] + 1;
	reg [10:0] prescaler_count;
	always @(posedge wb_clk_i or negedge nRST)
		if (nRST == 0) begin
			prescaler_count <= {11 {1'sb0}};
			CAN_clk <= 1'b0;
		end
		else if (enable_CAN)
			if (prescaler_count == BRP) begin
				prescaler_count <= 1;
				CAN_clk <= 1;
			end
			else begin
				prescaler_count <= prescaler_count + 1;
				CAN_clk <= 0;
			end
	flex_counter #(.NUM_CNT_BITS(4)) TX_CLEAR(
		.clk(bitstrobe),
		.n_rst(nRST),
		.clear(~curr_sample),
		.count_enable(curr_sample),
		.rollover_val(4'd11),
		.count_out(),
		.rollover_flag(TX_clear)
	);
	assign filter_0 = filters[30-:31];
	assign mask_0 = masks[30-:31];
	assign filter_1 = filters[62-:31];
	assign mask_1 = masks[62-:31];
	assign filter_2 = filters[94-:31];
	assign mask_2 = masks[94-:31];
	assign filter_3 = filters[126-:31];
	assign mask_3 = masks[126-:31];
	assign filter_4 = filters[158-:31];
	assign mask_4 = masks[158-:31];
	assign filter_5 = filters[190-:31];
	assign mask_5 = masks[190-:31];
	assign filter_6 = filters[222-:31];
	assign mask_6 = masks[222-:31];
	assign filter_7 = filters[254-:31];
	assign mask_7 = masks[254-:31];
	assign filter_8 = filters[286-:31];
	assign mask_8 = masks[286-:31];
	assign filter_9 = filters[318-:31];
	assign mask_9 = masks[318-:31];
	assign filter_10 = filters[350-:31];
	assign mask_10 = masks[350-:31];
	assign filter_11 = filters[382-:31];
	assign mask_11 = masks[382-:31];
	assign filter_12 = filters[414-:31];
	assign mask_12 = masks[414-:31];
	assign filter_13 = filters[446-:31];
	assign mask_13 = masks[446-:31];
	assign filter_14 = filters[478-:31];
	assign mask_14 = masks[478-:31];
	assign filter_15 = filters[510-:31];
	assign mask_15 = masks[510-:31];
	assign filter_16 = filters[542-:31];
	assign mask_16 = masks[542-:31];
	assign filter_17 = filters[574-:31];
	assign mask_17 = masks[574-:31];
	assign filter_18 = filters[606-:31];
	assign mask_18 = masks[606-:31];
	assign filter_19 = filters[638-:31];
	assign mask_19 = masks[638-:31];
	assign mask_enable = FMER[19:0];
	always @(posedge wb_clk_i or negedge nRST)
		if (nRST == 0) begin
			tx_pkt_ready <= 1'b0;
			tx_ID <= {29 {1'sb0}};
			tx_pkt_size <= {4 {1'sb0}};
			tx_RTR <= 1'b0;
			tx_EXT <= 1'b0;
			tx_data <= {64 {1'sb0}};
			chosen_mailbox <= {2 {1'sb0}};
		end
		else if (MCR[3] & ~lock) begin
			if (MLIDxR[31]) begin
				tx_pkt_ready <= 1;
				tx_ID <= MLIDxR[28-:29];
				tx_pkt_size <= MLSxR[3-:4];
				tx_RTR <= MLIDxR[29];
				tx_EXT <= MLIDxR[30];
				tx_data <= {MLDHxR[0+:32], MLDLxR[0+:32]};
				chosen_mailbox <= {2 {1'sb0}};
				lock <= 1;
			end
			else if (MLIDxR[63]) begin
				tx_pkt_ready <= 1;
				tx_ID <= MLIDxR[60-:29];
				tx_pkt_size <= MLSxR[35-:4];
				tx_RTR <= MLIDxR[61];
				tx_EXT <= MLIDxR[62];
				tx_data <= {MLDHxR[32+:32], MLDLxR[32+:32]};
				chosen_mailbox <= 1;
				lock <= 1;
			end
			else if (MLIDxR[95]) begin
				tx_pkt_ready <= 1;
				tx_ID <= MLIDxR[92-:29];
				tx_pkt_size <= MLSxR[67-:4];
				tx_RTR <= MLIDxR[93];
				tx_EXT <= MLIDxR[94];
				tx_data <= {MLDHxR[64+:32], MLDLxR[64+:32]};
				chosen_mailbox <= 2;
				lock <= 1;
			end
			else begin
				tx_pkt_ready <= 0;
				chosen_mailbox <= {2 {1'sb0}};
				lock <= 0;
			end
		end
		else if (~lock)
			case ({MLIDxR[95], MLIDxR[63], MLIDxR[31]})
				3'b001: begin
					tx_pkt_ready <= 1;
					tx_ID <= MLIDxR[28-:29];
					tx_pkt_size <= MLSxR[3-:4];
					tx_RTR <= MLIDxR[29];
					tx_EXT <= MLIDxR[30];
					tx_data <= {MLDHxR[0+:32], MLDLxR[0+:32]};
					chosen_mailbox <= {2 {1'sb0}};
					lock <= 1;
				end
				3'b010: begin
					tx_pkt_ready <= 1;
					tx_ID <= MLIDxR[60-:29];
					tx_pkt_size <= MLSxR[35-:4];
					tx_RTR <= MLIDxR[61];
					tx_EXT <= MLIDxR[62];
					tx_data <= {MLDHxR[32+:32], MLDLxR[32+:32]};
					chosen_mailbox <= 1;
					lock <= 1;
				end
				3'b100: begin
					tx_pkt_ready <= 1;
					tx_ID <= MLIDxR[92-:29];
					tx_pkt_size <= MLSxR[67-:4];
					tx_RTR <= MLIDxR[93];
					tx_EXT <= MLIDxR[94];
					tx_data <= {MLDHxR[64+:32], MLDLxR[64+:32]};
					chosen_mailbox <= 2;
					lock <= 1;
				end
				3'b011:
					if (MLIDxR[28-:29] <= MLIDxR[60-:29]) begin
						tx_pkt_ready <= 1;
						tx_ID <= MLIDxR[28-:29];
						tx_pkt_size <= MLSxR[3-:4];
						tx_RTR <= MLIDxR[29];
						tx_EXT <= MLIDxR[30];
						tx_data <= {MLDHxR[0+:32], MLDLxR[0+:32]};
						chosen_mailbox <= {2 {1'sb0}};
						lock <= 1;
					end
					else begin
						tx_pkt_ready <= 1;
						tx_ID <= MLIDxR[60-:29];
						tx_pkt_size <= MLSxR[35-:4];
						tx_RTR <= MLIDxR[61];
						tx_EXT <= MLIDxR[62];
						tx_data <= {MLDHxR[32+:32], MLDLxR[32+:32]};
						chosen_mailbox <= 1;
						lock <= 1;
					end
				3'b101:
					if (MLIDxR[28-:29] <= MLIDxR[92-:29]) begin
						tx_pkt_ready <= 1;
						tx_ID <= MLIDxR[28-:29];
						tx_pkt_size <= MLSxR[3-:4];
						tx_RTR <= MLIDxR[29];
						tx_EXT <= MLIDxR[30];
						tx_data <= {MLDHxR[0+:32], MLDLxR[0+:32]};
						chosen_mailbox <= {2 {1'sb0}};
						lock <= 1;
					end
					else begin
						tx_pkt_ready <= 1;
						tx_ID <= MLIDxR[92-:29];
						tx_pkt_size <= MLSxR[67-:4];
						tx_RTR <= MLIDxR[93];
						tx_EXT <= MLIDxR[94];
						tx_data <= {MLDHxR[64+:32], MLDLxR[64+:32]};
						chosen_mailbox <= 2;
						lock <= 1;
					end
				3'b110:
					if (MLIDxR[60-:29] <= MLIDxR[92-:29]) begin
						tx_pkt_ready <= 1;
						tx_ID <= MLIDxR[60-:29];
						tx_pkt_size <= MLSxR[35-:4];
						tx_RTR <= MLIDxR[61];
						tx_EXT <= MLIDxR[62];
						tx_data <= {MLDHxR[32+:32], MLDLxR[32+:32]};
						chosen_mailbox <= 1;
						lock <= 1;
					end
					else begin
						tx_pkt_ready <= 1;
						tx_ID <= MLIDxR[92-:29];
						tx_pkt_size <= MLSxR[67-:4];
						tx_RTR <= MLIDxR[93];
						tx_EXT <= MLIDxR[94];
						tx_data <= {MLDHxR[64+:32], MLDLxR[64+:32]};
						chosen_mailbox <= 2;
						lock <= 1;
					end
				3'b111:
					if (MLIDxR[28-:29] <= MLIDxR[60-:29]) begin
						if (MLIDxR[28-:29] <= MLIDxR[92-:29]) begin
							tx_pkt_ready <= 1;
							tx_ID <= MLIDxR[28-:29];
							tx_pkt_size <= MLSxR[3-:4];
							tx_RTR <= MLIDxR[29];
							tx_EXT <= MLIDxR[30];
							tx_data <= {MLDHxR[0+:32], MLDLxR[0+:32]};
							chosen_mailbox <= {2 {1'sb0}};
							lock <= 1;
						end
						else begin
							tx_pkt_ready <= 1;
							tx_ID <= MLIDxR[92-:29];
							tx_pkt_size <= MLSxR[67-:4];
							tx_RTR <= MLIDxR[93];
							tx_EXT <= MLIDxR[94];
							tx_data <= {MLDHxR[64+:32], MLDLxR[64+:32]};
							chosen_mailbox <= 2;
							lock <= 1;
						end
					end
					else if (MLIDxR[60-:29] <= MLIDxR[92-:29]) begin
						tx_pkt_ready <= 1;
						tx_ID <= MLIDxR[60-:29];
						tx_pkt_size <= MLSxR[35-:4];
						tx_RTR <= MLIDxR[61];
						tx_EXT <= MLIDxR[62];
						tx_data <= {MLDHxR[32+:32], MLDLxR[32+:32]};
						chosen_mailbox <= 1;
						lock <= 1;
					end
					else begin
						tx_pkt_ready <= 1;
						tx_ID <= MLIDxR[92-:29];
						tx_pkt_size <= MLSxR[67-:4];
						tx_RTR <= MLIDxR[93];
						tx_EXT <= MLIDxR[94];
						tx_data <= {MLDHxR[64+:32], MLDLxR[64+:32]};
						chosen_mailbox <= 2;
						lock <= 1;
					end
				default: begin
					tx_pkt_ready <= 0;
					chosen_mailbox <= {2 {1'sb0}};
					lock <= 0;
				end
			endcase
endmodule
