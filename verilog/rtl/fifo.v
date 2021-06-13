module fifo (
	clk,
	nRST,
	clear,
	ID,
	data,
	data_index,
	load_data,
	pkt_size,
	RTR,
	EXT,
	pkt_done,
	enable_overrun,
	new_ID,
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
	occupancy,
	full,
	empty,
	overrun,
	data_L,
	data_H,
	ID_out,
	pkt_size_out,
	RTR_out,
	EXT_out,
	fmi_out,
	fifo_read
);
	input clk;
	input nRST;
	input clear;
	input [28:0] ID;
	input [7:0] data;
	input [3:0] data_index;
	input load_data;
	input [3:0] pkt_size;
	input RTR;
	input EXT;
	input pkt_done;
	input enable_overrun;
	input new_ID;
	input [19:0] mask_enable;
	input [30:0] filter_0;
	input [30:0] mask_0;
	input [30:0] filter_1;
	input [30:0] mask_1;
	input [30:0] filter_2;
	input [30:0] mask_2;
	input [30:0] filter_3;
	input [30:0] mask_3;
	input [30:0] filter_4;
	input [30:0] mask_4;
	input [30:0] filter_5;
	input [30:0] mask_5;
	input [30:0] filter_6;
	input [30:0] mask_6;
	input [30:0] filter_7;
	input [30:0] mask_7;
	input [30:0] filter_8;
	input [30:0] mask_8;
	input [30:0] filter_9;
	input [30:0] mask_9;
	input [30:0] filter_10;
	input [30:0] mask_10;
	input [30:0] filter_11;
	input [30:0] mask_11;
	input [30:0] filter_12;
	input [30:0] mask_12;
	input [30:0] filter_13;
	input [30:0] mask_13;
	input [30:0] filter_14;
	input [30:0] mask_14;
	input [30:0] filter_15;
	input [30:0] mask_15;
	input [30:0] filter_16;
	input [30:0] mask_16;
	input [30:0] filter_17;
	input [30:0] mask_17;
	input [30:0] filter_18;
	input [30:0] mask_18;
	input [30:0] filter_19;
	input [30:0] mask_19;
	input read_fifo;
	output reg [3:0] occupancy;
	output full;
	output empty;
	output reg overrun;
	output reg [31:0] data_L;
	output reg [31:0] data_H;
	output reg [28:0] ID_out;
	output reg [3:0] pkt_size_out;
	output reg RTR_out;
	output reg EXT_out;
	output reg [4:0] fmi_out;
	output reg fifo_read;
	wire [30:0] filters [19:0];
	wire [30:0] masks [19:0];
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
	reg [63:0] pkt_buffer;
	reg [4:0] filter_index;
	reg [4:0] fmi;
	reg filter_match;
	always @(posedge clk or negedge nRST)
		if (nRST == 0) begin
			filter_index <= {5 {1'sb0}};
			fmi <= {5 {1'sb0}};
			filter_match <= 1'b0;
		end
		else if (new_ID || |filter_index)
			if (mask_enable[filter_index] && (({RTR, EXT, ID} & masks[filter_index]) == (filters[filter_index] & masks[filter_index]))) begin
				fmi <= filter_index;
				filter_index <= {5 {1'sb0}};
				filter_match <= 1;
			end
			else begin
				if (filter_index == 5'd19)
					filter_index <= 0;
				else
					filter_index <= filter_index + 1;
				filter_match <= 0;
			end
	wire pkt_done_edge;
	always @(posedge clk or negedge nRST)
		if (nRST == 0)
			pkt_buffer <= {64 {1'sb0}};
		else begin
			if (load_data)
				pkt_buffer[data_index * 8+:8] <= data;
			if (pkt_done_edge)
				pkt_buffer <= {64 {1'sb0}};
		end
	reg [831:0] pkt_fifo;
	reg [2:0] start_fifo;
	reg [2:0] end_fifo;
	assign full = occupancy == 4'd8;
	assign empty = occupancy == 4'd0;
	reg [1:0] delay_ff;
	assign pkt_done_edge = ~delay_ff[0] & delay_ff[1];
	always @(posedge clk or negedge nRST)
		if (nRST == 0)
			delay_ff <= {2 {1'sb0}};
		else begin
			delay_ff[0] <= pkt_done;
			delay_ff[1] <= delay_ff[0];
		end
	always @(posedge clk or negedge nRST)
		if (nRST == 0) begin
			pkt_fifo <= {832 {1'sb0}};
			start_fifo <= {3 {1'sb0}};
			end_fifo <= {3 {1'sb0}};
			fifo_read <= 0;
			occupancy <= {4 {1'sb0}};
			data_L <= {32 {1'sb0}};
			data_H <= {32 {1'sb0}};
			ID_out <= {29 {1'sb0}};
			pkt_size_out <= {4 {1'sb0}};
			RTR_out <= 1'b0;
			EXT_out <= 1'b0;
			fmi_out <= {5 {1'sb0}};
			overrun <= 1'b0;
		end
		else begin
			data_L <= pkt_fifo[(start_fifo * 104) + 7+:32];
			data_H <= pkt_fifo[(start_fifo * 104) + 39+:32];
			ID_out <= pkt_fifo[(start_fifo * 104) + 103-:29];
			pkt_size_out <= pkt_fifo[(start_fifo * 104) + 74-:4];
			RTR_out <= pkt_fifo[(start_fifo * 104) + 6];
			EXT_out <= pkt_fifo[(start_fifo * 104) + 5];
			fmi_out <= pkt_fifo[(start_fifo * 104) + 4-:5];
			if (clear) begin
				pkt_fifo <= {832 {1'sb0}};
				start_fifo <= {3 {1'sb0}};
				end_fifo <= {3 {1'sb0}};
				fifo_read <= 0;
				occupancy <= {4 {1'sb0}};
				overrun <= 1'b0;
			end
			else if (pkt_done_edge & filter_match) begin
				if (~full || (full & enable_overrun)) begin
					pkt_fifo[(end_fifo * 104) + 70-:64] <= pkt_buffer;
					pkt_fifo[(end_fifo * 104) + 74-:4] <= pkt_size;
					pkt_fifo[(end_fifo * 104) + 103-:29] <= ID;
					pkt_fifo[(end_fifo * 104) + 6] <= RTR;
					pkt_fifo[(end_fifo * 104) + 5] <= EXT;
					pkt_fifo[(end_fifo * 104) + 4-:5] <= fmi;
					end_fifo <= end_fifo + 1;
					if (full) begin
						overrun <= 1;
						start_fifo <= start_fifo + 1;
					end
					else begin
						overrun <= 0;
						occupancy <= occupancy + 1;
					end
				end
			end
			else if (read_fifo) begin
				fifo_read <= 1;
				overrun <= 0;
				if (empty == 0) begin
					pkt_fifo[start_fifo * 104+:104] <= {104 {1'sb0}};
					occupancy <= occupancy - 1;
					start_fifo <= start_fifo + 1;
				end
			end
			else
				fifo_read <= 0;
		end
endmodule
