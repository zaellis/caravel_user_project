// File name:   tb_wb_slave.sv
// Created:     6/3/2021
// Author:      Zachary Ellis
// Version:     1.0 Initial design entry
// Description: wishbone slave testbench

`timescale 1ns / 10ps

module tb_wb_slave();

    localparam  CLK_PERIOD = 10; //100MHz

    reg tb_wb_clk_i;
    reg tb_wb_rst_i;

    reg [31:0] tb_wb_adr_i;
    reg [31:0] tb_wb_dat_i;
    reg [3:0]  tb_wb_sel_i;
    reg tb_wb_we_i;
    reg tb_wb_cyc_i;
    reg tb_wb_stb_i;

    wire tb_wb_ack_o;
    wire [31:0] tb_wb_dat_o;

    reg tb_bitstrobe;
    reg tb_curr_sample;
    reg tb_rx_busy;
    reg tb_tx_busy;
    //general outputs
    wire tb_CAN_clk;
    wire tb_CAN_nRST;
    wire tb_tx_enable;
    //timing stuff
    wire [3:0] tb_TS1; //need to add this to timer
    wire [3:0] tb_TS2; //need to add this to timer
    //error stuff
    reg [7:0] tb_REC;
    reg [7:0] tb_TEC;
    reg tb_error_passive;
    reg tb_bus_off;
    reg [2:0] tb_LEC; //need to add this to ECU
    //fifo stuff
    reg [3:0] tb_fifo_occupancy;
    reg tb_fifo_full;
    reg tb_fifo_empty;
    reg tb_fifo_overrun;
    reg [31:0] tb_fifo_data_L;
    reg [31:0] tb_fifo_data_H;
    reg [28:0] tb_fifo_ID;
    reg [3:0] tb_fifo_pkt_size;
    reg tb_fifo_RTR;
    reg tb_fifo_EXT;
    reg [4:0] tb_fifo_fmi;
    reg tb_fifo_read;
    wire tb_fifo_clear;
    wire tb_overrun_enable;
    wire [19:0] tb_mask_enable;
    reg [19:0] [30:0] tb_filters;
    reg [19:0] [30:0] tb_masks;
    wire tb_read_fifo;
    //tx mailbox output to TCU
    reg tb_tx_done;    //add to TCU
    reg tb_tx_arb_loss;//add to TCU
    wire tb_tx_pkt_ready;
    wire [28:0] tb_tx_ID;
    wire [3:0] tb_tx_pkt_size;
    wire tb_tx_RTR;
    wire tb_tx_EXT;
    wire [63:0] tb_tx_data;

    integer tb_test_num;
    string tb_test_case;
    integer tb_stream_test_num;
    string tb_stream_check_tag;

    // Task for standard DUT reset procedure
    task reset_dut;
    begin
        // Activate the reset
        tb_wb_rst_i = 1'b1;

        // Maintain the reset for more than one cycle
        @(posedge tb_wb_clk_i);
        @(posedge tb_wb_clk_i);

        // Wait until safely away from rising edge of the clock before releasing
        @(negedge tb_wb_clk_i);
        tb_wb_rst_i = 1'b0;

        // Leave out of reset for a couple cycles before allowing other stimulus
        // Wait for negative clock edges, 
        // since inputs to DUT should normally be applied away from rising clock edges
        @(negedge tb_wb_clk_i);
        @(negedge tb_wb_clk_i);
    end
    endtask   

    task wb_transaction;
        input [31:0] wb_addr;
        input [31:0] wb_dat;
        input [3:0] wb_sel;
        input wb_we;
        input string signal_name;
    begin
        @(posedge tb_wb_clk_i);
        tb_wb_adr_i = wb_addr;
        tb_wb_sel_i = wb_sel;
        tb_wb_we_i = wb_we;
        tb_wb_cyc_i = 1'b1;
        tb_wb_stb_i = 1'b1;
        if(wb_we) tb_wb_dat_i = wb_dat;
        else begin
            tb_wb_dat_i = 0;
            #(CLK_PERIOD / 10);
            if(wb_dat == tb_wb_dat_o) begin // Check passed
            $info("Correct %s output during %s test case", signal_name, tb_test_case);
            end
            else begin // Check failed
            $error("Incorrect %s output during %s test case", signal_name, tb_test_case);
            end
        end
        @(posedge tb_wb_clk_i);
        tb_wb_cyc_i = 1'b0;
        tb_wb_stb_i = 1'b0;
    end
    endtask

    task check_out;
        input logic [30:0] real_out;
        input logic [30:0] expected_out;
        input string signal_name;
    begin
        if(expected_out == real_out) begin // Check passed
        $info("Correct %s output during %s test case", signal_name, tb_test_case);
        end
        else begin // Check failed
        $error("Incorrect %s output during %s test case", signal_name, tb_test_case);
        end
    end
    endtask

    always
    begin
        // Start with clock low to avoid false rising edge events at t=0
        tb_wb_clk_i = 1'b0;
        // Wait half of the clock period before toggling clock value (maintain 50% duty cycle)
        #(CLK_PERIOD/2.0);
        tb_wb_clk_i = 1'b1;
        // Wait half of the clock period before toggling clock value via rerunning the block (maintain 50% duty cycle)
        #(CLK_PERIOD/2.0);
    end

    wb_slave DUT (
        //wb_interface
        .wb_clk_i(tb_wb_clk_i),
        .wb_rst_i(tb_wb_rst_i),
        .wb_adr_i(tb_wb_adr_i),
        .wb_dat_i(tb_wb_dat_i),
        .wb_sel_i(tb_wb_sel_i),
        .wb_we_i(tb_wb_we_i),
        .wb_cyc_i(tb_wb_cyc_i),
        .wb_stb_i(tb_wb_stb_i),
        .wb_ack_o(tb_wb_ack_o),      
        .wb_dat_o(tb_wb_dat_o), //these are registered which adds a wait state but it's ok
        //connection to the rest of the peripheral
        //general inputs
        .bitstrobe(tb_bitstrobe),
        .curr_sample(tb_curr_sample),
        .rx_busy(tb_rx_busy),
        .tx_busy(tb_tx_busy),
        //general outputs
        .CAN_clk(tb_CAN_clk),
        .CAN_nRST(tb_CAN_nRST),
        .tx_enable(tb_tx_enable),
        //timing stuff
        .TS1(tb_TS1), //need to add this to timer
        .TS2(tb_TS2), //need to add this to timer
        //error stuff
        .REC(tb_REC),
        .TEC(tb_TEC),
        .error_passive(tb_error_passive),
        .bus_off(tb_bus_off),
        .LEC(tb_LEC), //need to add this to ECU
        //fifo stuff
        .fifo_occupancy(tb_fifo_occupancy),
        .fifo_full(tb_fifo_full),
        .fifo_empty(tb_fifo_empty),
        .fifo_overrun(tb_fifo_overrun),
        .fifo_data_L(tb_fifo_data_L),
        .fifo_data_H(tb_fifo_data_H),
        .fifo_ID(tb_fifo_ID),
        .fifo_pkt_size(tb_fifo_pkt_size),
        .fifo_RTR(tb_fifo_RTR),
        .fifo_EXT(tb_fifo_EXT),
        .fifo_fmi(tb_fifo_fmi),
        .fifo_read(tb_fifo_read),
        .fifo_clear(tb_fifo_clear),
        .overrun_enable(tb_overrun_enable),
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
        //tx mailbox output to TCU
        .tx_done(tb_tx_done),    //add to TCU
        .tx_arb_loss(tb_tx_arb_loss),//add to TCU
        .tx_pkt_ready(tb_tx_pkt_ready),
        .tx_ID(tb_tx_ID),
        .tx_pkt_size(tb_tx_pkt_size),
        .tx_RTR(tb_tx_RTR),
        .tx_EXT(tb_tx_EXT),
        .tx_data(tb_tx_data)
    );

    initial begin
        tb_wb_rst_i = 1'b0;
        tb_wb_adr_i = '0;
        tb_wb_dat_i = '0;
        tb_wb_sel_i = '0;
        tb_wb_we_i = '0;
        tb_wb_cyc_i = '0;
        tb_wb_stb_i = '0;
        
        tb_bitstrobe = 0;
        tb_curr_sample = '0;
        tb_rx_busy = '0;
        tb_tx_busy = '0;

        tb_REC = '0;
        tb_TEC = '0;
        tb_error_passive = '0;
        tb_bus_off = '0;
        tb_LEC = '0;

        tb_fifo_occupancy = '0;
        tb_fifo_full = '0;
        tb_fifo_empty = '0;
        tb_fifo_overrun = '0;
        tb_fifo_data_L = '0;
        tb_fifo_data_H = '0;
        tb_fifo_ID = '0;
        tb_fifo_pkt_size = '0;
        tb_fifo_RTR = '0;
        tb_fifo_EXT = '0;
        tb_fifo_fmi = '0;
        tb_fifo_read = '0;

        tb_filters = '0;
        tb_masks = '0;

        tb_tx_done = '0;
        tb_tx_arb_loss = '0;

        tb_test_num = 0;               
        tb_test_case = "Test bench initializaton";
        tb_stream_test_num = 0;
        tb_stream_check_tag = "N/A";

        // ************************************************************************
        // Test Case 1: write / read to timing register
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "write / read to timing register";

        reset_dut();

        wb_transaction(32'h300000c4, {16'd0, 3'd3, 3'd3, 10'd9}, 4'b1111, 1'b1, "TMGR");
        #(CLK_PERIOD * 10);
        wb_transaction(32'h300000c4, 32'd9, 4'b0001, 1'b0, "BRP");

        check_out(tb_TS1, 4'd4, "TS1");
        check_out(tb_TS1, 4'd4, "TS2");

        // ************************************************************************
        // Test Case 2: initialize CAN
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "initialize CAN";

        //reset_dut();

        wb_transaction(32'h30000000, 32'd1, 4'b1111, 1'b1, "MCR");

        // ************************************************************************
        // Test Case 2: test filter write / read
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "test filter write / read";

        //reset_dut();

        for(integer i = 0; i < 20; i++) begin
            wb_transaction((i*4) + 32, i + 1, 4'b1111, 1'b1, "filters");
            wb_transaction((i*4) + 32, i + 1, 4'b1111, 1'b0, "filters");
            check_out(tb_filters[i], i + 1, "filters");
        end

        // ************************************************************************
        // Test Case 2: test mask write / read
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "test mask write / read";

        //reset_dut();

        for(integer i = 0; i < 20; i++) begin
            wb_transaction((i*4) + 112, i + 1, 4'b1111, 1'b1, "masks");
            wb_transaction((i*4) + 112, i + 1, 4'b1111, 1'b0, "masks");
            check_out(tb_masks[i], i + 1, "masks");
        end

        // ************************************************************************
        // Test Case 1: FMER
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "FMER";

        //reset_dut();

        wb_transaction(32'h3000001c, 32'b10110001010101110101101011000101, 4'b1111, 1'b1, "FMER");
        wb_transaction(32'h3000001c, 32'b00000000000001110101101011000101, 4'b1111, 1'b0, "FMER");

        // ************************************************************************
        // Test Case 1: Mailbox check
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Mailbox check";

        //reset_dut();

        wb_transaction(32'h300000c8, 32'b10111001010101110101101011000101, 4'b1111, 1'b1, "Mail 1");
        wb_transaction(32'h300000c8, 32'b10111001010101110101101011000101, 4'b1111, 1'b0, "Mail 1");
        check_out(tb_tx_ID, 29'b11001010101110101101011000101, "tx_ID");

        wb_transaction(32'h300000d0, 32'b10000011010101110101101011000101, 4'b1111, 1'b1, "Mail 3");
        wb_transaction(32'h300000d0, 32'b10000011010101110101101011000101, 4'b1111, 1'b0, "Mail 3");
        check_out(tb_tx_ID, 29'b00011010101110101101011000101, "tx_ID");

        wb_transaction(32'h300000cc, 32'b10000001010101110101101011000101, 4'b1111, 1'b1, "Mail 2");
        wb_transaction(32'h300000cc, 32'b10000001010101110101101011000101, 4'b1111, 1'b0, "Mail 2");

        check_out(tb_tx_ID, 29'b00001010101110101101011000101, "tx_ID");

        wb_transaction(32'h30000000, {28'd0, 4'b1001}, 4'b1111, 1'b1, "MCR");
        @(posedge tb_wb_clk_i);
        check_out(tb_tx_ID, 29'b11001010101110101101011000101, "tx_ID");
        
        @(posedge tb_wb_clk_i); //clear mailboxes
        tb_tx_done = 1;
        @(posedge tb_wb_clk_i);
        tb_tx_done = 0;
        @(posedge tb_wb_clk_i);
        tb_tx_done = 1;
        @(posedge tb_wb_clk_i);
        tb_tx_done = 0;
        @(posedge tb_wb_clk_i);
        tb_tx_done = 1;
        @(posedge tb_wb_clk_i);
        tb_tx_done = 0;

        wb_transaction(32'h300000d0, 32'b10000011010101110101101011000101, 4'b1111, 1'b1, "Mail 3");
        wb_transaction(32'h300000d0, 32'b10000011010101110101101011000101, 4'b1111, 1'b0, "Mail 3");
        check_out(tb_tx_ID, 29'b00011010101110101101011000101, "tx_ID");

        @(posedge tb_wb_clk_i);
        tb_tx_arb_loss = 1;
        @(posedge tb_wb_clk_i);
        tb_tx_arb_loss = 0;



    end

endmodule