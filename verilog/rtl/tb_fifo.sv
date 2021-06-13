// File name:   tb_fifo.sv
// Created:     5/27/2021
// Author:      Zachary Ellis
// Version:     1.0  Initial Design Entry
// Description: testbench for CAN controller top module

`timescale 1ns / 10ps

module tb_fifo();

    localparam  CLK_PERIOD    = 100;
    localparam  STROBE_PERIOD = 10 * CLK_PERIOD;

    // Declare DUT portmap signals
    reg tb_clk;
    reg tb_nRST;
    reg [28:0] tb_ID;
    reg [7:0] tb_data;
    reg [3:0] tb_data_index;
    reg tb_load_data;
    reg [3:0] tb_pkt_size;
    reg tb_RTR;
    reg tb_EXT;
    reg tb_pkt_done;
    reg tb_enable_overrun;
    reg tb_new_ID;
    reg [19:0] tb_mask_enable;
    reg [19:0] [30:0] tb_filters;
    reg [19:0] [30:0] tb_masks;
    reg tb_read_fifo;
    wire [3:0] tb_occupancy;
    wire tb_full;
    wire tb_empty;
    wire tb_overrun;
    wire [31:0] tb_data_L;
    wire [31:0] tb_data_H;
    wire [28:0] tb_ID_out;
    wire [3:0] tb_pkt_size_out;
    wire tb_RTR_out;
    wire tb_EXT_out;
    wire [4:0] tb_fmi_out;
    wire tb_fifo_read;
    
    
    // Declare test bench signals
    integer tb_test_num;
    string tb_test_case;
    integer tb_stream_test_num;
    string tb_stream_check_tag;

    reg [28:0] msg_msg_id;
    reg msg_RTR;
    reg msg_EXT;
    reg [3:0] msg_pkt_size;
    reg [7:0] [7:0] msg_pkt_data;

    // Task for standard DUT reset procedure
    task reset_dut;
    begin
        // Activate the reset
        tb_nRST = 1'b0;

        // Maintain the reset for more than one cycle
        @(posedge tb_clk);
        @(posedge tb_clk);

        // Wait until safely away from rising edge of the clock before releasing
        @(negedge tb_clk);
        tb_nRST = 1'b1;

        // Leave out of reset for a couple cycles before allowing other stimulus
        // Wait for negative clock edges, 
        // since inputs to DUT should normally be applied away from rising clock edges
        @(negedge tb_clk);
        @(negedge tb_clk);
        #(STROBE_PERIOD * 11);
    end
    endtask

    task load_fifo;
        input [28:0] ID;
        input RTR;
        input EXT;
        input [3:0] pkt_size;
        input [7:0] [7:0] data_in;
    begin
        tb_ID = ID;
        tb_RTR = RTR;
        tb_EXT = EXT;
        tb_pkt_size = pkt_size;
        #(STROBE_PERIOD * 3);
        @(posedge tb_clk);
        tb_new_ID = 1;
        @(posedge tb_clk);
        tb_new_ID = 0;
        #(STROBE_PERIOD * 3);
        for(integer i = 0; i < pkt_size; i++) begin
            @(posedge tb_clk);
            tb_data = data_in[i];
            tb_data_index = i;
            tb_load_data = 1;
            @(posedge tb_clk);
            tb_load_data = 0;
            #(STROBE_PERIOD * 8);
        end
        #(STROBE_PERIOD * 8);
        @(posedge tb_clk);
        tb_pkt_done = 1;
        @(posedge tb_clk);
        tb_pkt_done = 0;
        #(STROBE_PERIOD * 3);
    end
    endtask

    always
    begin
        // Start with clock low to avoid false rising edge events at t=0
        tb_clk = 1'b0;
        // Wait half of the clock period before toggling clock value (maintain 50% duty cycle)
        #(CLK_PERIOD/2.0);
        tb_clk = 1'b1;
        // Wait half of the clock period before toggling clock value via rerunning the block (maintain 50% duty cycle)
        #(CLK_PERIOD/2.0);
    end

    fifo DUT (
        .clk(tb_clk),
        .nRST(tb_nRST),
        .ID(tb_ID),
        .data(tb_data),
        .data_index(tb_data_index),
        .load_data(tb_load_data),
        .pkt_size(tb_pkt_size),
        .RTR(tb_RTR),
        .EXT(tb_EXT),
        .pkt_done(tb_pkt_done),
        .enable_overrun(tb_enable_overrun),
        .new_ID(tb_new_ID),
        .mask_enable(tb_mask_enable),
        .filter_0(tb_filters[0]),
        .mask_0(tb_masks[0]),
        .filter_1(tb_filters[1]),
        .mask_1(tb_masks[1]),
        .filter_2(tb_filters[2]),
        .mask_2(tb_masks[2]),
        .filter_3(tb_filters[3]),
        .mask_3(tb_masks[3]),
        .filter_4(tb_filters[4]),
        .mask_4(tb_masks[4]),
        .filter_5(tb_filters[5]),
        .mask_5(tb_masks[5]),
        .filter_6(tb_filters[6]),
        .mask_6(tb_masks[6]),
        .filter_7(tb_filters[7]),
        .mask_7(tb_masks[7]),
        .filter_8(tb_filters[8]),
        .mask_8(tb_masks[8]),
        .filter_9(tb_filters[9]),
        .mask_9(tb_masks[9]),
        .filter_10(tb_filters[10]),
        .mask_10(tb_masks[10]),
        .filter_11(tb_filters[11]),
        .mask_11(tb_masks[11]),
        .filter_12(tb_filters[12]),
        .mask_12(tb_masks[12]),
        .filter_13(tb_filters[13]),
        .mask_13(tb_masks[13]),
        .filter_14(tb_filters[14]),
        .mask_14(tb_masks[14]),
        .filter_15(tb_filters[15]),
        .mask_15(tb_masks[15]),
        .filter_16(tb_filters[16]),
        .mask_16(tb_masks[16]),
        .filter_17(tb_filters[17]),
        .mask_17(tb_masks[17]),
        .filter_18(tb_filters[18]),
        .mask_18(tb_masks[18]),
        .filter_19(tb_filters[19]),
        .mask_19(tb_masks[19]),
        .read_fifo(tb_read_fifo),
        .occupancy(tb_occupancy),
        .full(tb_full),
        .empty(tb_empty),
        .overrun(tb_overrun),
        .data_L(tb_data_L),
        .data_H(tb_data_H),
        .ID_out(tb_ID_out),
        .pkt_size_out(tb_pkt_size_out),
        .RTR_out(tb_RTR_out),
        .EXT_out(tb_EXT_out),
        .fmi_out(tb_fmi_out),
        .fifo_read(tb_fifo_read)
    );

    initial begin
        tb_ID = '0;
        tb_data = '0;
        tb_data_index = '0;
        tb_load_data = 1'b0;
        tb_pkt_size = '0;
        tb_RTR = 1'b0;
        tb_EXT = 1'b0;
        tb_pkt_done = 1'b0;
        tb_enable_overrun = 1'b1;
        tb_new_ID = 1'b0;
        tb_mask_enable = '0;
        tb_filters = '0;
        tb_masks = '0;
        tb_read_fifo = 1'b0;

        //Setup basic filters
        tb_mask_enable = 20'b00000000000011111111;
        tb_filters[0] = {2'd0, 11'b10110010110, 18'd0};
        tb_masks[0] = {2'd0, 11'b11111111111, 18'd0};
        tb_filters[1] = {2'd0, 11'b00000010100, 18'd0};
        tb_masks[1] = {2'd0, 11'b11111111111, 18'd0};
        tb_filters[2] = {2'd0, 11'b00000000000, 18'd0};
        tb_masks[2] = {2'd0, 11'b11111111111, 18'd0};
        tb_filters[3] = {2'd0, 11'b00000000000, 18'd0};
        tb_masks[3] = {2'd0, 11'b11111111111, 18'd0};
        tb_filters[4] = {2'd0, 11'b00000000000, 18'd0};
        tb_masks[4] = {2'd0, 11'b11111111111, 18'd0};
        tb_filters[5] = {2'd0, 11'b00000000000, 18'd0};
        tb_masks[5] = {2'd0, 11'b11111111111, 18'd0};
        tb_filters[6] = {2'd0, 11'b00000000000, 18'd0};
        tb_masks[6] = {2'd0, 11'b11111111111, 18'd0};
        tb_filters[7] = {2'd0, 11'b00000000000, 18'd0};
        tb_masks[7] = {2'd0, 11'b11111111111, 18'd0};

        // ************************************************************************
        // Test Case 1: Basic load fifo
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Basic load fifo";

        reset_dut();

        msg_msg_id = {11'b10110010110, 18'd0};
        msg_RTR = 0;
        msg_EXT = 0;
        msg_pkt_size = 4'd2;
        msg_pkt_data[0] = 8'b10101100;
        msg_pkt_data[1] = 8'b10101101;

        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        // ************************************************************************
        // Test Case 2: fill fifo
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "fill fifo";

        //reset_dut();

        msg_msg_id = {11'b10110010110, 18'd0};
        msg_pkt_size = 4'd8;
        msg_pkt_data[0] = 8'b10101100;
        msg_pkt_data[1] = 8'b10101101;
        msg_pkt_data[2] = 8'b10101001;
        msg_pkt_data[3] = 8'b10001101;
        msg_pkt_data[4] = 8'b10100101;
        msg_pkt_data[5] = 8'b10101111;
        msg_pkt_data[6] = 8'b00111101;
        msg_pkt_data[7] = 8'b11101101;

        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        msg_msg_id = {11'b10110010110, 18'd0};
        msg_RTR = 0;
        msg_EXT = 0;
        msg_pkt_size = 4'd2;
        msg_pkt_data[0] = 8'b10101100;
        msg_pkt_data[1] = 8'b10101101;

        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        msg_msg_id = {11'b10110010110, 18'd0};
        msg_pkt_size = 4'd8;
        msg_pkt_data[0] = 8'b10101111;
        msg_pkt_data[1] = 8'b11101101;
        msg_pkt_data[2] = 8'b10101000;
        msg_pkt_data[3] = 8'b00001101;
        msg_pkt_data[4] = 8'b10100101;
        msg_pkt_data[5] = 8'b10101111;
        msg_pkt_data[6] = 8'b10111101;
        msg_pkt_data[7] = 8'b11101101;

        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        msg_msg_id = {11'b10110010110, 18'd0};
        msg_pkt_size = 4'd3;
        msg_pkt_data[0] = 8'b10111111;
        msg_pkt_data[1] = 8'b01101101;
        msg_pkt_data[2] = 8'b10101010;
        
        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        msg_msg_id = {11'b10110010110, 18'd0};
        msg_pkt_size = 4'd8;
        msg_pkt_data[0] = 8'b10101111;
        msg_pkt_data[1] = 8'b11101101;
        msg_pkt_data[2] = 8'b10101000;
        msg_pkt_data[3] = 8'b00001101;
        msg_pkt_data[4] = 8'b10100101;
        msg_pkt_data[5] = 8'b10101111;
        msg_pkt_data[6] = 8'b10111101;
        msg_pkt_data[7] = 8'b11101101;

        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        msg_msg_id = {11'b00000010100, 18'd0};
        msg_pkt_size = 4'd1;
        msg_pkt_data[0] = 8'b00000001;

        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        msg_msg_id = {11'b00000010100, 18'b101100010101011101};
        msg_EXT = 1;
        msg_pkt_size = 4'd1;
        msg_pkt_data[0] = 8'b00000001;

        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        msg_EXT = 0;

        // ************************************************************************
        // Test Case 2: read fifo
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "read fifo";

        //reset_dut();

        #(STROBE_PERIOD);
        @(posedge tb_clk);
        tb_read_fifo = 1;
        @(posedge tb_clk);
        tb_read_fifo = 0;

        // ************************************************************************
        // Test Case 3: overrun
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "overrun";

        //reset_dut();


        msg_msg_id = {11'b00000010100, 18'b101100010101011101};
        msg_EXT = 1;
        msg_pkt_size = 4'd1;
        msg_pkt_data[0] = 8'b00000001;

        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);
        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        msg_EXT = 0;

        // ************************************************************************
        // Test Case 4: fail filter match
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "fail filter match";

        //reset_dut();

        #(STROBE_PERIOD);   //read first so it isn't full anymore
        @(posedge tb_clk);
        tb_read_fifo = 1;
        @(posedge tb_clk);
        tb_read_fifo = 0;

        msg_msg_id = {11'b00110010100, 18'b101100010101011101};
        msg_EXT = 1;
        msg_pkt_size = 4'd1;
        msg_pkt_data[0] = 8'b00000001;

        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);
        load_fifo(msg_msg_id, msg_RTR, msg_EXT, msg_pkt_size, msg_pkt_data);

        msg_EXT = 0;
    end

endmodule