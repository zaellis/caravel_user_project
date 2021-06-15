module wb_CAN (
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
	CANRX,
	CAN_TX
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
	input CANRX;
	output CAN_TX;
	wire tx_strobe;
	wire tx_bitstuff;
	wire tx_end_data;
	wire tx_byte_complete;
	wire [3:0] tx_byte_num;
	wire curr_sample;
	wire form_error;
	wire [1:0] rx_err_code;
	wire [1:0] tx_err_code;
	wire start_err_tx;
	wire bitstrobe;
	wire [1:0] error_state;
	wire CAN_out;
	wire bit_error;
	wire ack_error;
	wire bitstuff_error;
	wire CRC_Error;
	wire tx_enable;
	wire [8:0] REC;
	wire [8:0] TEC;
	wire [3:0] TS1;
	wire [3:0] TS2;
	wire [2:0] LEC;
	wire [3:0] occupancy;
	wire full;
	wire empty;
	wire overrun;
	wire [31:0] data_L;
	wire [31:0] data_H;
	wire [28:0] ID_out;
	wire [3:0] pkt_size_out;
	wire read_fifo;
	wire tx_arb_loss;
	wire tx_done;
	wire rx_busy;
	wire tx_busy;
	wire ACK;
	wire CAN_clk;
	wire CAN_nRST;
	wire RTR_out;
	wire EXT_out;
	wire [4:0] fmi_out;
	wire fifo_read;
	wire fifo_clear;
	wire overrun_enable;
	wire [19:0] mask_enable;
	wire tx_pkt_ready;
	wire [28:0] tx_ID;
	wire [3:0] tx_pkt_size;
	wire tx_EXT;
	wire tx_RTR;
	wire [63:0] tx_data;
	wire tx_dataphase;
	wire bitstrobe_shift;
	reg [30:0] filters [19:0];
	reg [30:0] masks [19:0];
	assign CAN_TX = (error_state[1] ? CAN_out : CAN_out & ACK);
	wb_slave U1(
		.wb_clk_i(wb_clk_i),
		.wb_rst_i(wb_rst_i),
		.wb_adr_i(wb_adr_i),
		.wb_dat_i(wb_dat_i),
		.wb_sel_i(wb_sel_i),
		.wb_we_i(wb_we_i),
		.wb_cyc_i(wb_cyc_i),
		.wb_stb_i(wb_stb_i),
		.wb_ack_o(wb_ack_o),
		.wb_dat_o(wb_dat_o),
		.bitstrobe(bitstrobe),
		.curr_sample(curr_sample),
		.rx_busy(rx_busy),
		.tx_busy(tx_busy),
		.CAN_clk(CAN_clk),
		.CAN_nRST(CAN_nRST),
		.tx_enable(tx_enable),
		.TS1(TS1),
		.TS2(TS2),
		.REC(REC[7:0]),
		.TEC(TEC[7:0]),
		.error_passive(error_state[0]),
		.bus_off(error_state[1]),
		.LEC(LEC),
		.fifo_occupancy(occupancy),
		.fifo_full(full),
		.fifo_empty(empty),
		.fifo_overrun(overrun),
		.fifo_data_L(data_L),
		.fifo_data_H(data_H),
		.fifo_ID(ID_out),
		.fifo_pkt_size(pkt_size_out),
		.fifo_RTR(RTR_out),
		.fifo_EXT(EXT_out),
		.fifo_fmi(fmi_out),
		.fifo_read(fifo_read),
		.fifo_clear(fifo_clear),
		.overrun_enable(overrun_enable),
		.mask_enable(mask_enable),
		.filter_0(filters[0]),
		.mask_0(masks[0]),
		.filter_1(filters[1]),
		.mask_1(masks[1]),
		.filter_2(filters[2]),
		.mask_2(masks[2]),
		.filter_3(filters[3]),
		.mask_3(masks[3]),
		.filter_4(filters[4]),
		.mask_4(masks[4]),
		.filter_5(filters[5]),
		.mask_5(masks[5]),
		.filter_6(filters[6]),
		.mask_6(masks[6]),
		.filter_7(filters[7]),
		.mask_7(masks[7]),
		.filter_8(filters[8]),
		.mask_8(masks[8]),
		.filter_9(filters[9]),
		.mask_9(masks[9]),
		.filter_10(filters[10]),
		.mask_10(masks[10]),
		.filter_11(filters[11]),
		.mask_11(masks[11]),
		.filter_12(filters[12]),
		.mask_12(masks[12]),
		.filter_13(filters[13]),
		.mask_13(masks[13]),
		.filter_14(filters[14]),
		.mask_14(masks[14]),
		.filter_15(filters[15]),
		.mask_15(masks[15]),
		.filter_16(filters[16]),
		.mask_16(masks[16]),
		.filter_17(filters[17]),
		.mask_17(masks[17]),
		.filter_18(filters[18]),
		.mask_18(masks[18]),
		.filter_19(filters[19]),
		.mask_19(masks[19]),
		.read_fifo(read_fifo),
		.tx_done(tx_done),
		.tx_arb_loss(tx_arb_loss),
		.tx_pkt_ready(tx_pkt_ready),
		.tx_ID(tx_ID),
		.tx_pkt_size(tx_pkt_size),
		.tx_RTR(tx_RTR),
		.tx_EXT(tx_EXT),
		.tx_data(tx_data)
	);
	CAN_receiver U2(
		.clk(CAN_clk),
		.nRST(CAN_nRST),
		.TS1(TS1),
		.TS2(TS2),
		.CANRX(CANRX),
		.tx_busy(tx_busy),
		.error_state(error_state),
		.fifo_clear(fifo_clear),
		.enable_overrun(overrun_enable),
		.mask_enable(mask_enable),
		.filter_0(filters[0]),
		.mask_0(masks[0]),
		.filter_1(filters[1]),
		.mask_1(masks[1]),
		.filter_2(filters[2]),
		.mask_2(masks[2]),
		.filter_3(filters[3]),
		.mask_3(masks[3]),
		.filter_4(filters[4]),
		.mask_4(masks[4]),
		.filter_5(filters[5]),
		.mask_5(masks[5]),
		.filter_6(filters[6]),
		.mask_6(masks[6]),
		.filter_7(filters[7]),
		.mask_7(masks[7]),
		.filter_8(filters[8]),
		.mask_8(masks[8]),
		.filter_9(filters[9]),
		.mask_9(masks[9]),
		.filter_10(filters[10]),
		.mask_10(masks[10]),
		.filter_11(filters[11]),
		.mask_11(masks[11]),
		.filter_12(filters[12]),
		.mask_12(masks[12]),
		.filter_13(filters[13]),
		.mask_13(masks[13]),
		.filter_14(filters[14]),
		.mask_14(masks[14]),
		.filter_15(filters[15]),
		.mask_15(masks[15]),
		.filter_16(filters[16]),
		.mask_16(masks[16]),
		.filter_17(filters[17]),
		.mask_17(masks[17]),
		.filter_18(filters[18]),
		.mask_18(masks[18]),
		.filter_19(filters[19]),
		.mask_19(masks[19]),
		.read_fifo(read_fifo),
		.ACK(ACK),
		.busy(rx_busy),
		.bitstuff_error(bitstuff_error),
		.form_error(form_error),
		.rx_err_code(rx_err_code),
		.CRC_Error(CRC_Error),
		.bitstrobe(bitstrobe),
		.tx_strobe(tx_strobe),
		.curr_sample(curr_sample),
		.occupancy(occupancy),
		.full(full),
		.empty(empty),
		.overrun(overrun),
		.data_L(data_L),
		.data_H(data_H),
		.ID_out(ID_out),
		.pkt_size_out(pkt_size_out),
		.RTR_out(RTR_out),
		.EXT_out(EXT_out),
		.fmi_out(fmi_out),
		.fifo_read(fifo_read)
	);
	TCU U3(
		.clk(wb_clk_i),
		.tx_strobe(tx_strobe),
		.bitstrobe(bitstrobe),
		.nRST(CAN_nRST),
		.pkt_ready(tx_pkt_ready),
		.tx_enable(tx_enable),
		.rx_busy(rx_busy),
		.byte_num(tx_byte_num),
		.byte_complete(tx_byte_complete),
		.enddata(tx_end_data),
		.pkt_size(tx_pkt_size),
		.msg_id(tx_ID),
		.data(tx_data),
		.RTR(tx_RTR),
		.EXT(tx_EXT),
		.curr_sample(curr_sample),
		.start_err_tx(start_err_tx),
		.error_state(error_state),
		.busy(tx_busy),
		.Dataphase(tx_dataphase),
		.bitstuff(tx_bitstuff),
		.CANTX(CAN_out),
		.bit_error(bit_error),
		.ack_error(ack_error),
		.tx_err_code(tx_err_code),
		.tx_arb_loss(tx_arb_loss),
		.tx_done(tx_done)
	);
	tx_timer U4(
		.nRST(CAN_nRST),
		.tx_strobe(tx_strobe),
		.dataphase(tx_dataphase),
		.bitstuff(tx_bitstuff),
		.pkt_size(tx_pkt_size),
		.byte_complete(tx_byte_complete),
		.byte_num(tx_byte_num),
		.end_data(tx_end_data)
	);
	ECU U5(
		.bitstrobe(bitstrobe),
		.tx_strobe(tx_strobe),
		.nRST(CAN_nRST),
		.curr_sample(curr_sample),
		.rx_bitstuff_error(bitstuff_error),
		.rx_form_error(form_error),
		.rx_crc_error(CRC_Error),
		.tx_bit_error(bit_error),
		.tx_ack_error(ack_error),
		.rx_code(rx_err_code),
		.tx_code(tx_err_code),
		.start_err_tx(start_err_tx),
		.TEC(TEC),
		.REC(REC),
		.error_state(error_state),
		.LEC(LEC)
	);
endmodule
