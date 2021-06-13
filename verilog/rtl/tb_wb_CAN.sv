// File name:   tb_wb_CAN.sv
// Created:     5/14/2021
// Author:      Zachary Ellis
// Version:     1.0  Initial Design Entry
// Description: testbench for CAN controller top module

/////////////////////////////////////////////////////
// Changes to be made
// - Start work on TX streaming / checking
/////////////////////////////////////////////////////

`timescale 1ns / 10ps

module tb_wb_CAN();

    localparam  CLK_PERIOD    = 10; //100MHz
    localparam  STROBE_PERIOD = 100 * CLK_PERIOD; //1MHz

    // Declare DUT portmap signals

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

    reg tb_CANRX;
    wire tb_CAN_TX;
    
    // Declare test bench signals
    integer tb_test_num;
    string tb_test_case;
    integer tb_stream_test_num;
    string tb_stream_check_tag;

    reg [28:0] msg_msg_id;
    reg [3:0] msg_pkt_size;
    reg [7:0] [7:0] msg_pkt_data;
    reg [14:0] msg_CRC;
    reg [3:0] tb_tx_pkt_size;
    reg [28:0] tb_tx_msg_ID;
    reg [7:0] [7:0] tb_tx_data;
    reg tb_tx_RTR;
    reg tb_tx_EXT;
    reg enable_biterror;
    reg [4:0] form_errors;
    reg ACK_err;
    reg stream_tx;
    reg bitstream [];
    reg CAN_stream;

    integer lag;

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
            while(~tb_wb_ack_o) begin
                @(posedge tb_wb_clk_i);
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

    task monitor_bitstuff;
        inout integer ones;
        inout integer zeros;
        inout integer index;
        inout logic bitstream [];
    begin
        if(bitstream[index - 1]) begin
            ones++;
            zeros = (enable_biterror) ? -100 : 0;
            if(ones == 5) begin
                bitstream[index++] = 1'b0;
                $display("added stuffed bit %d", index - 1);
                ones = 0;
                zeros = 1;
            end
        end
        else begin
            ones = (enable_biterror) ? -100 : 0;
            zeros++;
            if(zeros == 5) begin
                bitstream[index++] = 1'b1;
                $display("added stuffed bit %d", index - 1);
                zeros = 0;
                ones = 1;
            end
        end
    end
    endtask

    task construct_pkt;
        input logic [28:0] msg_id;
        input logic [3:0] pkt_size;
        input logic [7:0] [7:0] pkt_data;
        input logic [14:0] CRC;
        input logic extendedID;
        input logic RTR;
    begin
        integer package_size;
        integer index;
        integer ones;
        integer zeros;

        ones = 0;
        zeros = 1;

        if(enable_biterror) begin
            ones = -100;
            zeros = -100;
        end

        package_size = 48 + (pkt_size * 8 * (1-RTR)) + (extendedID * 20);
        index = 0;

        bitstream = new[package_size];

        bitstream[index++] = 0;

        for(integer i = 0; i < 11; i++) begin //msg id
            bitstream[index++] = msg_id[28-i];
            monitor_bitstuff(ones, zeros, index, bitstream);
        end
        
        bitstream[index++] = extendedID ? 1'b1 : RTR ? 1'b1 : 1'b0; //SRR/RTR bit (need to add RTR support)
        monitor_bitstuff(ones, zeros, index, bitstream);

        bitstream[index++] = extendedID ? 1'b1 : 1'b0; //IDE bit (sign change + add extra logic)
        if(form_errors[0]) bitstream[index - 1] = 1'b1; //test wrong IDE bit in normal length data packet
        monitor_bitstuff(ones, zeros, index, bitstream);
        
        if(extendedID) begin
            for(integer i = 0; i < 18; i++) begin //msg id
                bitstream[index++] = msg_id[17-i];
                monitor_bitstuff(ones, zeros, index, bitstream);
            end

            bitstream[index++] = RTR ? 1'b1 : 1'b0; //RTR bit in extended packets
            monitor_bitstuff(ones, zeros, index, bitstream);

            bitstream[index++] = 1'b0; //reserved bit 1 for extended packets
            monitor_bitstuff(ones, zeros, index, bitstream);
        end
        
        bitstream[index++] = 1'b0; //reserved bit 0
        monitor_bitstuff(ones, zeros, index, bitstream);

        for(integer i = 0; i < 4; i++) begin //pkt_size
            bitstream[index++] = pkt_size[3-i];
            monitor_bitstuff(ones, zeros, index, bitstream);
        end

        if(~RTR) begin
            for(integer i = 0; i < pkt_size; i++) begin //data contained
                for(integer j = 0; j < 8; j++) begin
                    bitstream[index++] = pkt_data[i][7-j];
                    monitor_bitstuff(ones, zeros, index, bitstream);
                end
            end
        end

        for(integer i = 0; i < 15; i++) begin //crc code
            bitstream[index++] = CRC[14-i];
            monitor_bitstuff(ones, zeros, index, bitstream);
        end

        bitstream[index++] = 1'b1;
        if(form_errors[1]) bitstream[index - 1] = 1'b0;
        bitstream[index++] = (stream_tx || (|form_errors)) ? 1'b0 : 1'b1;
        bitstream[index++] = 1'b1;
        if(form_errors[2] || ACK_err) bitstream[index - 1] = 1'b0;

        for(int i = index; i < bitstream.size(); i++)begin //What is this? EOF? Sure
            bitstream[index++] = 1'b1;
            if(form_errors[3] && index < (bitstream.size()-1)) bitstream[index - 1] = 1'b0;
            if(form_errors[4] && index == (bitstream.size()-1)) bitstream[index - 1] = 1'b0;

        end

    end
    endtask

    task tx_stream;
        input logic bitstream [];
        input integer streamlen;
    begin
        integer i;
        @(negedge tb_CAN_TX);
        CAN_stream = bitstream[0];
        for(i = 1; i < streamlen; i++) begin
            #((STROBE_PERIOD) / 2);
            if(tb_CAN_TX != CAN_stream) $error("biterror index %d", i);
            #((STROBE_PERIOD) / 2);
            CAN_stream = bitstream[i];
        end
        #((STROBE_PERIOD) / 2);
        if(tb_CAN_TX != CAN_stream) $error("biterror index %d", i);
    end
    endtask

    task RXstream;
        input logic bitstream [];
        input integer streamlen;
    begin
        #(STROBE_PERIOD * 11);
        @(negedge tb_wb_clk_i);
        CAN_stream = bitstream[0];
        #(STROBE_PERIOD + lag);
        for(integer i = 1; i < streamlen; i++) begin
            CAN_stream = bitstream[i];
            #((STROBE_PERIOD + lag) / 2);
            if(tb_CAN_TX == 0 && CAN_stream == 1 && stream_tx == 0) begin
                CAN_stream = 1'b1;
                #((STROBE_PERIOD + lag) / 2);
                #(STROBE_PERIOD * 14);        
                break;
            end
            #((STROBE_PERIOD + lag) / 2);
        end
        #(STROBE_PERIOD * 11);
    end
    endtask

    task check_out;
        input logic [28:0] real_out;
        input logic [28:0] expected_out;
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

    always_comb begin
        tb_CANRX = tb_CAN_TX & CAN_stream;
    end

    wb_CAN DUT (
        //wishbone interface
        .wb_clk_i(tb_wb_clk_i),
        .wb_rst_i(tb_wb_rst_i),
        .wb_adr_i(tb_wb_adr_i),
        .wb_dat_i(tb_wb_dat_i),
        .wb_sel_i(tb_wb_sel_i),
        .wb_we_i(tb_wb_we_i),
        .wb_cyc_i(tb_wb_cyc_i),
        .wb_stb_i(tb_wb_stb_i),
        .wb_ack_o(tb_wb_ack_o),      
        .wb_dat_o(tb_wb_dat_o),
        //CAN interface
        .CANRX(tb_CANRX),
        .CAN_TX(tb_CAN_TX)
    );

    initial begin
        CAN_stream = 1'b1;
        tb_wb_rst_i = 1'b0;
        tb_wb_adr_i = '0;
        tb_wb_dat_i = '0;
        tb_wb_sel_i = '0;
        tb_wb_we_i = '0;
        tb_wb_cyc_i = '0;
        tb_wb_stb_i = '0;
        
        tb_test_num = 0;               
        tb_test_case = "Test bench initializaton";
        tb_stream_test_num = 0;
        tb_stream_check_tag = "N/A";

        msg_msg_id = '0;
        msg_pkt_size = '0;
        msg_pkt_data = '0;
        msg_CRC = '0;

        tb_tx_pkt_size = 4'b0;
        tb_tx_msg_ID = 29'b0;
        tb_tx_data = '0;
        tb_tx_RTR = 1'b0;
        tb_tx_EXT = 1'b0;

        enable_biterror = 1'b0;
        form_errors = '0;
        ACK_err = 0;

        stream_tx = 0;

        lag = 0;

        // ************************************************************************
        // Test Case 1: write / read to timing register
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "write / read to timing register";

        reset_dut();

        wb_transaction(32'h300000c4, {16'd0, 3'd3, 3'd3, 10'd9}, 4'b1111, 1'b1, "TMGR");
        #(CLK_PERIOD * 10);
        wb_transaction(32'h300000c4, 32'd9, 4'b0001, 1'b0, "BRP");

        // ************************************************************************
        // Test Case 2: initialize CAN
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "initialize CAN";

        //reset_dut();

        wb_transaction(32'h30000000, {26'd0, 6'b110001}, 4'b1111, 1'b1, "MCR");

        // ************************************************************************
        // Test Case 2: Setup filters
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Setup filters";

        //reset_dut();

        wb_transaction(32'h3000001c, {12'd0, 20'b00000000000011111111}, 4'b1111, 1'b1, "FMER");
        wb_transaction(32'h30000020, {3'd0, 11'b10110010110, 18'd0}, 4'b1111, 1'b1, "filters");
        wb_transaction(32'h30000024, {3'd0, 11'b00000010100, 18'd0}, 4'b1111, 1'b1, "filters");
        wb_transaction(32'h30000070, {3'd0, 11'b11111111111, 18'd0}, 4'b1111, 1'b1, "masks");
        wb_transaction(32'h30000074, {3'd0, 11'b11111111111, 18'd0}, 4'b1111, 1'b1, "masks");

        // ************************************************************************
        // Test Case 1: Basic correct bitstream
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Basic correct bitstream";

        //reset_dut();

        msg_msg_id = {11'b10110010110, 18'd0};
        msg_pkt_size = 4'd2;
        msg_pkt_data[0] = 8'b10101100;
        msg_pkt_data[1] = 8'b10101101;
        msg_CRC = 15'b111011111000011; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        /*check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        @(negedge tb_clk);
        tb_readaddr = 4'd0;
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], {3'd0,tb_byte_out}, "data 0");
        tb_readaddr = 4'd1;
        @(posedge tb_clk);
        check_out(msg_pkt_data[1], {3'd0,tb_byte_out}, "data 1");*/


        // ************************************************************************
        // Test Case 2: long bitstream
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream";

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
        msg_CRC = 15'b010111110110010; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        wb_transaction(32'h30000008, 32'd2, 4'b0001, 1'b1, "FSCR");
        /*check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        @(negedge tb_clk);
        tb_readaddr = 4'd0;
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], {3'd0,tb_byte_out}, "data 0");
        tb_readaddr = 4'd1;
        @(posedge tb_clk);
        check_out(msg_pkt_data[1], {3'd0,tb_byte_out}, "data 1");
        tb_readaddr = 4'd2;
        @(posedge tb_clk);
        check_out(msg_pkt_data[2], {3'd0,tb_byte_out}, "data 2");
        tb_readaddr = 4'd3;
        @(posedge tb_clk);
        check_out(msg_pkt_data[3], {3'd0,tb_byte_out}, "data 3");
        tb_readaddr = 4'd4;
        @(posedge tb_clk);
        check_out(msg_pkt_data[4], {3'd0,tb_byte_out}, "data 4");
        tb_readaddr = 4'd5;
        @(posedge tb_clk);
        check_out(msg_pkt_data[5], {3'd0,tb_byte_out}, "data 5");
        tb_readaddr = 4'd6;
        @(posedge tb_clk);
        check_out(msg_pkt_data[6], {3'd0,tb_byte_out}, "data 6");
        tb_readaddr = 4'd7;
        @(posedge tb_clk);
        check_out(msg_pkt_data[7], {3'd0,tb_byte_out}, "data 7");*/

        // ************************************************************************
        // Test Case 3: long bitstream + stuffed bits
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream + stuffed bits";

        //reset_dut();
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
        msg_CRC = 15'b010111110000111; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        /*check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        tb_readaddr = 4'd0;
        @(negedge tb_clk);
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], {3'd0,tb_byte_out}, "data 0");
        tb_readaddr = 4'd1;
        @(posedge tb_clk);
        check_out(msg_pkt_data[1], {3'd0,tb_byte_out}, "data 1");
        tb_readaddr = 4'd2;
        @(posedge tb_clk);
        check_out(msg_pkt_data[2], {3'd0,tb_byte_out}, "data 2");
        tb_readaddr = 4'd3;
        @(posedge tb_clk);
        check_out(msg_pkt_data[3], {3'd0,tb_byte_out}, "data 3");
        tb_readaddr = 4'd4;
        @(posedge tb_clk);
        check_out(msg_pkt_data[4], {3'd0,tb_byte_out}, "data 4");
        tb_readaddr = 4'd5;
        @(posedge tb_clk);
        check_out(msg_pkt_data[5], {3'd0,tb_byte_out}, "data 5");
        tb_readaddr = 4'd6;
        @(posedge tb_clk);
        check_out(msg_pkt_data[6], {3'd0,tb_byte_out}, "data 6");
        tb_readaddr = 4'd7;
        @(posedge tb_clk);
        check_out(msg_pkt_data[7], {3'd0,tb_byte_out}, "data 7");*/

        // ************************************************************************
        // Test Case 4: edge case stuffed bits at the end of a byte
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "edge case stuffed bits at the end of a byte";

        //reset_dut();
        msg_msg_id = {11'b10110010110, 18'd0};
        msg_pkt_size = 4'd3;
        msg_pkt_data[0] = 8'b10111111;
        msg_pkt_data[1] = 8'b01101101;
        msg_pkt_data[2] = 8'b10101010;
        msg_CRC = 15'b010000111100010;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        /*check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        tb_readaddr = 4'd0;
        @(negedge tb_clk);
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], {3'd0,tb_byte_out}, "data 0");
        tb_readaddr = 4'd1;
        @(posedge tb_clk);
        check_out(msg_pkt_data[1], {3'd0,tb_byte_out}, "data 1");
        tb_readaddr = 4'd2;
        @(posedge tb_clk);
        check_out(msg_pkt_data[2], {3'd0,tb_byte_out}, "data 2");*/

        // ************************************************************************
        // Test Case 5: long bitstream + bit error
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream + bit error";

        enable_biterror = 1'b1;

        //reset_dut();
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
        msg_CRC = 15'b000010100100000; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());

        // ************************************************************************
        // Test Case 6: long bitstream + 1.5% slower
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream + 1.5% slower";

        lag = STROBE_PERIOD * 0.015;
        enable_biterror = 1'b0;

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
        msg_CRC = 15'b010111110110010; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        /*check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        tb_readaddr = 4'd0;
        @(negedge tb_clk);
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], {3'd0,tb_byte_out}, "data 0");
        tb_readaddr = 4'd1;
        @(posedge tb_clk);
        check_out(msg_pkt_data[1], {3'd0,tb_byte_out}, "data 1");
        tb_readaddr = 4'd2;
        @(posedge tb_clk);
        check_out(msg_pkt_data[2], {3'd0,tb_byte_out}, "data 2");
        tb_readaddr = 4'd3;
        @(posedge tb_clk);
        check_out(msg_pkt_data[3], {3'd0,tb_byte_out}, "data 3");
        tb_readaddr = 4'd4;
        @(posedge tb_clk);
        check_out(msg_pkt_data[4], {3'd0,tb_byte_out}, "data 4");
        tb_readaddr = 4'd5;
        @(posedge tb_clk);
        check_out(msg_pkt_data[5], {3'd0,tb_byte_out}, "data 5");
        tb_readaddr = 4'd6;
        @(posedge tb_clk);
        check_out(msg_pkt_data[6], {3'd0,tb_byte_out}, "data 6");
        tb_readaddr = 4'd7;
        @(posedge tb_clk);
        check_out(msg_pkt_data[7], {3'd0,tb_byte_out}, "data 7");*/

        // ************************************************************************
        // Test Case 7: long bitstream + 1.5% faster
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream + 1.5% faster";

        lag = STROBE_PERIOD * 0.015;
        lag = -lag;

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
        msg_CRC = 15'b010111110110010; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        /*check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        tb_readaddr = 4'd0;
        @(negedge tb_clk);
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], {3'd0,tb_byte_out}, "data 0");
        tb_readaddr = 4'd1;
        @(posedge tb_clk);
        check_out(msg_pkt_data[1], {3'd0,tb_byte_out}, "data 1");
        tb_readaddr = 4'd2;
        @(posedge tb_clk);
        check_out(msg_pkt_data[2], {3'd0,tb_byte_out}, "data 2");
        tb_readaddr = 4'd3;
        @(posedge tb_clk);
        check_out(msg_pkt_data[3], {3'd0,tb_byte_out}, "data 3");
        tb_readaddr = 4'd4;
        @(posedge tb_clk);
        check_out(msg_pkt_data[4], {3'd0,tb_byte_out}, "data 4");
        tb_readaddr = 4'd5;
        @(posedge tb_clk);
        check_out(msg_pkt_data[5], {3'd0,tb_byte_out}, "data 5");
        tb_readaddr = 4'd6;
        @(posedge tb_clk);
        check_out(msg_pkt_data[6], {3'd0,tb_byte_out}, "data 6");
        tb_readaddr = 4'd7;
        @(posedge tb_clk);
        check_out(msg_pkt_data[7], {3'd0,tb_byte_out}, "data 7");*/

        lag = 0;

        // ************************************************************************
        // Test Case 8: Wikipedia packet
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet";

        //reset_dut();
        msg_msg_id = {11'b00000010100, 18'd0};
        msg_pkt_size = 4'd1;
        msg_pkt_data[0] = 8'b00000001;
        msg_CRC = 15'b111011101010011;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        /*check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        tb_readaddr = 4'd0;
        @(negedge tb_clk);
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], tb_byte_out, "data 0");*/

        // ************************************************************************
        // Test Case 9: Wikipedia packet Extended ID
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet Extended ID";

        //reset_dut();
        msg_msg_id = {11'b00000010100, 18'b101100010101011101};
        msg_pkt_size = 4'd1;
        msg_pkt_data[0] = 8'b00000001;
        msg_CRC = 15'h3743;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 1, 0);
        RXstream(bitstream, bitstream.size());
        /*check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        tb_readaddr = 4'd0;
        @(negedge tb_clk);
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], tb_byte_out, "data 0");*/

        // ************************************************************************
        // Test Case 10: Wikipedia packet RTR
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet RTR";

        //reset_dut();
        msg_msg_id = {11'b00000010100, 18'd0};
        msg_pkt_size = 4'd1;
        msg_CRC = 15'h0276;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 1);
        RXstream(bitstream, bitstream.size());
        //check_out(msg_msg_id, tb_CAN_ID, "CAN ID");

        // ************************************************************************
        // Test Case 11: Wikipedia packet Extended ID + RTR
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet Extended ID + RTR";

        //reset_dut();
        msg_msg_id = {11'b00000010100, 18'b101100010101011101};
        msg_pkt_size = 4'd1;
        msg_CRC = 15'h6ca3;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 1, 1);
        RXstream(bitstream, bitstream.size());
        //check_out(msg_msg_id, tb_CAN_ID, "CAN ID");


        // ************************************************************************
        // Test Case 12: Wikipedia packet TX
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet TX";

        //reset_dut();

        stream_tx = 1;

        tb_tx_RTR = 1'b0;
        tb_tx_EXT = 1'b0;

        tb_tx_msg_ID = {11'b00000010100, 18'd0};
        tb_tx_pkt_size = 4'd1;
        tb_tx_data[0] = 8'b00000001;

        construct_pkt(tb_tx_msg_ID - 1, tb_tx_pkt_size, tb_tx_data, 15'b111011101010011, tb_tx_EXT, tb_tx_RTR);
        //need to write to the mailbox
        wb_transaction(32'h300000d4, 32'd1, 4'b0001, 1'b1, "MLS0R");
        wb_transaction(32'h300000e0, 32'd1, 4'b0001, 1'b1, "MLDL0R");
        wb_transaction(32'h300000c8, {1'b1, tb_tx_RTR, tb_tx_EXT, tb_tx_msg_ID}, 4'b1111, 1'b1, "MLDL0R");
        tx_stream(bitstream, bitstream.size());
        construct_pkt(tb_tx_msg_ID, tb_tx_pkt_size, tb_tx_data, 15'b111011101010011, tb_tx_EXT, tb_tx_RTR);
        tx_stream(bitstream, bitstream.size());

        // ************************************************************************
        // Test Case 13: og packet TX
        // ************************************************************************
        /*tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet TX";

        //reset_dut();

        tb_tx_RTR = 1'b0;
        tb_tx_EXT = 1'b0;

        tb_tx_msg_ID = {11'b10110010110, 18'd0};
        tb_tx_pkt_size = 4'd2;
        tb_tx_data[0] = 8'b10101100;
        tb_tx_data[1] = 8'b10101101;

        construct_pkt(tb_tx_msg_ID, tb_tx_pkt_size, tb_tx_data, 15'b111011111000011, tb_tx_EXT, tb_tx_RTR);
        tx_stream(bitstream, bitstream.size());
        

        // ************************************************************************
        // Test Case 14: RTR packet TX
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "RTR packet TX";

        //reset_dut();

        tb_tx_RTR = 1'b1;
        tb_tx_EXT = 1'b0;

        tb_tx_msg_ID = {11'b00000010100, 18'd0};
        tb_tx_pkt_size = 4'd1;
        //msg_CRC = 15'h0276;

        construct_pkt(tb_tx_msg_ID, tb_tx_pkt_size, tb_tx_data, 15'h0276, tb_tx_EXT, tb_tx_RTR);
        tx_stream(bitstream, bitstream.size());
        
        // ************************************************************************
        // Test Case 15: Wikipedia packet TX + Extended ID
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet TX + Extended ID";

        //reset_dut();

        tb_tx_RTR = 1'b0;
        tb_tx_EXT = 1'b1;

        tb_tx_msg_ID = {11'b00000010100, 18'b101100010101011101};
        tb_tx_pkt_size = 4'd1;
        tb_tx_data[0] = 8'b00000001;
        //msg_CRC = 15'h3743;
               
        construct_pkt(tb_tx_msg_ID, tb_tx_pkt_size, tb_tx_data, 15'h3743, tb_tx_EXT, tb_tx_RTR);
        tx_stream(bitstream, bitstream.size());*/

        // ************************************************************************
        // Test Case 16: Wikipedia packet TX + Extended ID + RTR
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet TX + Extended ID";

        //reset_dut();

        tb_tx_RTR = 1'b1;
        tb_tx_EXT = 1'b1;

        tb_tx_msg_ID = {11'b00000010100, 18'b101100010101011101};
        tb_tx_pkt_size = 4'd1;
        //msg_CRC = 15'h6ca3;
               
        construct_pkt(tb_tx_msg_ID, tb_tx_pkt_size, tb_tx_data, 15'h6ca3, tb_tx_EXT, tb_tx_RTR);
        wb_transaction(32'h300000d4, {28'd0, tb_tx_pkt_size}, 4'b0001, 1'b1, "MLS0R");
        wb_transaction(32'h300000c8, {1'b1, tb_tx_RTR, tb_tx_EXT, tb_tx_msg_ID}, 4'b1111, 1'b1, "MLDL0R");
        tx_stream(bitstream, bitstream.size());

        // ************************************************************************
        // Test Case 17: long bitstream + stuffed bits TX
        // ************************************************************************
        /*tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream + stuffed bits TX";

        //reset_dut();

        tb_tx_RTR = 1'b0;
        tb_tx_EXT = 1'b0;

        tb_tx_msg_ID = {11'b10110010110, 18'd0};
        tb_tx_pkt_size = 4'd8;
        tb_tx_data[0] = 8'b10101111;
        tb_tx_data[1] = 8'b11101101;
        tb_tx_data[2] = 8'b10101000;
        tb_tx_data[3] = 8'b00001101;
        tb_tx_data[4] = 8'b10100101;
        tb_tx_data[5] = 8'b10101111;
        tb_tx_data[6] = 8'b10111101;
        tb_tx_data[7] = 8'b11101101;

        construct_pkt(tb_tx_msg_ID, tb_tx_pkt_size, tb_tx_data, 15'b010111110000111, tb_tx_EXT, tb_tx_RTR);
        tx_stream(bitstream, bitstream.size());*/

        stream_tx = 0;

        // ************************************************************************
        // Test Case 18: form error cases
        // ************************************************************************

        tb_test_num = tb_test_num + 1;
        tb_test_case = "form error cases";

        //reset_dut();

        wb_transaction(32'h30000008, 32'd2, 4'b0001, 1'b1, "FSCR");

        msg_msg_id = {11'b00000010100, 18'd0};
        msg_pkt_size = 4'd1;
        msg_pkt_data[0] = 8'b00000001;
        msg_CRC = 15'b111011101010011;
        form_errors = 5'b00001;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        form_errors = 5'b00010;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        form_errors = 5'b00100;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        form_errors = 5'b01000;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        form_errors = 5'b10000;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        form_errors = 5'd0;

        // ************************************************************************
        // Test Case 19: Wikipedia packet CRC error
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet CRC error";

        //reset_dut();
        msg_msg_id = {11'b00000010100, 18'd0};
        msg_pkt_size = 4'd1;
        msg_pkt_data[0] = 8'b00000001;
        msg_CRC = 15'b111011101010111;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        RXstream(bitstream, bitstream.size());
        // ************************************************************************
        // Test Case 19: Wikipedia packet ACK error RX
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Wikipedia packet ACK error RX";

        //reset_dut();
        msg_msg_id = {11'b00000010100, 18'd0};
        msg_pkt_size = 4'd1;
        msg_pkt_data[0] = 8'b00000001;
        msg_CRC = 15'b111011101010111;
        ACK_err = 1;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC, 0, 0);
        ACK_err = 0;
        RXstream(bitstream, bitstream.size());
        

    end

endmodule