// File name:   tb_CAN_receiver.sv
// Created:     12/1/2020
// Author:      Zachary Ellis
// Version:     1.0  Initial Design Entry
// Description: testbench cor CAN receiver top module

`timescale 1ns / 10ps

module tb_CAN_receiver();

    localparam  CLK_PERIOD    = 100;
    localparam  STROBE_PERIOD = 10 * CLK_PERIOD;

    // Declare DUT portmap signals
    
    reg tb_clk;
    reg tb_nRST;
    reg tb_CANRX;
    reg [3:0] tb_readaddr;
    wire tb_ACK;
    wire [7:0] tb_byte_out;
    wire tb_busy;
    wire tb_bitstuff_error;
    wire [10:0] tb_CAN_ID;
    wire tb_CRC_Error;
    
    // Declare test bench signals
    integer tb_test_num;
    string tb_test_case;
    integer tb_stream_test_num;
    string tb_stream_check_tag;

    reg [10:0] msg_msg_id;
    reg [3:0] msg_pkt_size;
    reg [7:0] [7:0] msg_pkt_data;
    reg [14:0] msg_CRC;
    reg enable_biterror;
    reg bitstream [];

    integer lag;

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

    task construct_pkt;
        input logic [10:0] msg_id;
        input logic [3:0] pkt_size;
        input logic [7:0] [7:0] pkt_data;
        input logic [14:0] CRC;
    begin
        integer package_size;
        integer index;
        integer ones;
        integer zeros;

        ones = 1;
        zeros = 0;

        if(enable_biterror) begin
            ones = -100;
            zeros = -100;
        end

        package_size = 50 + (pkt_size * 8);
        index = 0;

        bitstream = new[package_size];

        bitstream[index++] = 1;

        for(integer i = 0; i < 11; i++) begin //msg id
            bitstream[index++] = msg_id[10-i];
            if(bitstream[index - 1]) begin
                ones++;
                zeros = (enable_biterror) ? -100 : 0;
                if(ones == 5) begin
                    bitstream[index++] = 1'b0;
                    $display("added stuffed bit");
                    ones = 0;
                end
            end
            else begin
                ones = (enable_biterror) ? -100: 0;
                zeros++;
                if(zeros == 5) begin
                    bitstream[index++] = 1'b1;
                    $display("added stuffed bit");
                    zeros = 0;
                end
            end
        end
        
        bitstream[index++] = 1'b1; //RTR bit
        if(bitstream[index - 1]) begin
            ones++;
            zeros = (enable_biterror) ? -100 : 0;
            if(ones == 5) begin
                bitstream[index++] = 1'b0;
                $display("added stuffed bit");
                ones = 0;
            end
        end
        else begin
            ones = (enable_biterror) ? -100 : 0;
            zeros++;
            if(zeros == 5) begin
                bitstream[index++] = 1'b1;
                $display("added stuffed bit");
                zeros = 0;
            end
        end
        bitstream[index++] = 1'b1; //IDE bit
        if(bitstream[index - 1]) begin
            ones++;
            zeros = (enable_biterror) ? -100 : 0;
            if(ones == 5) begin
                bitstream[index++] = 1'b0;
                $display("added stuffed bit");
                ones = 0;
            end
        end
        else begin
            ones = (enable_biterror) ? -100 : 0;
            zeros++;
            if(zeros == 5) begin
                bitstream[index++] = 1'b1;
                $display("added stuffed bit");
                zeros = 0;
            end
        end
        bitstream[index++] = 1'b0; //reserved bit
        zeros++;

        for(integer i = 0; i < 4; i++) begin //pkt_size
            bitstream[index++] = pkt_size[3-i];
            if(bitstream[index - 1]) begin
                ones++;
                zeros = (enable_biterror) ? -100 : 0;
                if(ones == 5) begin
                    bitstream[index++] = 1'b0;
                    $display("added stuffed bit");
                    ones = 0;
                end
            end
            else begin
                ones = (enable_biterror) ? -100 : 0;
                zeros++;
                if(zeros == 5) begin
                    bitstream[index++] = 1'b1;
                    $display("added stuffed bit");
                    zeros = 0;
                end
            end
        end

        for(integer i = 0; i < pkt_size; i++) begin //data contained
            for(integer j = 0; j < 8; j++) begin
                bitstream[index++] = pkt_data[i][7-j];
                if(bitstream[index - 1]) begin
                    ones++;
                    zeros = (enable_biterror) ? -100 : 0;
                    if(ones == 5) begin
                        bitstream[index++] = 1'b0;
                        $display("added stuffed bit");
                        ones = 0;
                    end
                end
                else begin
                    ones = (enable_biterror) ? -100 : 0;
                    zeros++;
                    if(zeros == 5) begin
                        bitstream[index++] = 1'b1;
                        $display("added stuffed bit");
                        zeros = 0;
                    end
                end
            end
        end

        for(integer i = 0; i < 15; i++) begin //crc code
            bitstream[index++] = CRC[14-i];
            if(bitstream[index - 1]) begin
                ones++;
                zeros = (enable_biterror) ? -100 : 0;
                if(ones == 5) begin
                    bitstream[index++] = 1'b0;
                    $display("added stuffed bit");
                    ones = 0;
                end
            end
            else begin
                ones = (enable_biterror) ? -100 : 0;
                zeros++;
                if(zeros == 5) begin
                    bitstream[index++] = 1'b1;
                    $display("added stuffed bit");
                    zeros = 0;
                end
            end
        end

        bitstream[index++] = 1'b0;
        bitstream[index++] = 1'b0;
        bitstream[index++] = 1'b0;

        for(int i = index; i < bitstream.size(); i++)begin
            bitstream[index++] = 1'b0;
        end

    end
    endtask

    task RXstream;
        input logic bitstream [];
        input integer streamlen;
    begin
        tb_CANRX = bitstream[0];

        for(integer i = 1; i < streamlen; i++) begin
            #(STROBE_PERIOD + lag);
            tb_CANRX = bitstream[i];
        end
    end
    endtask

    task check_out;
        input logic [10:0] real_out;
        input logic [10:0] expected_out;
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
        tb_clk = 1'b0;
        // Wait half of the clock period before toggling clock value (maintain 50% duty cycle)
        #(CLK_PERIOD/2.0);
        tb_clk = 1'b1;
        // Wait half of the clock period before toggling clock value via rerunning the block (maintain 50% duty cycle)
        #(CLK_PERIOD/2.0);
    end

    CAN_receiver DUT (
        .clk(tb_clk),
        .nRST(tb_nRST),
        .CANRX(tb_CANRX),
        .readaddr(tb_readaddr),
        .ACK(tb_ACK),
        .byte_out(tb_byte_out),
        .busy(tb_busy),
        .bitstuff_error(tb_bitstuff_error),
        .CAN_ID(tb_CAN_ID),
        .CRC_Error(tb_CRC_Error)
    );

    initial begin
        tb_nRST = 1'b1;
        tb_CANRX = 1'b0;
        tb_readaddr = 1'b0;
        
        tb_test_num = 0;               
        tb_test_case = "Test bench initializaton";
        tb_stream_test_num = 0;
        tb_stream_check_tag = "N/A";

        msg_msg_id = '0;
        msg_pkt_size = '0;
        msg_pkt_data = '0;
        msg_CRC = '0;

        enable_biterror = 1'b0;

        lag = 0;

        // ************************************************************************
        // Test Case 1: Basic correct bitstream
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "Basic correct bitstream";

        reset_dut();
        msg_msg_id = 11'b10110010110;
        msg_pkt_size = 4'd2;
        msg_pkt_data[0] = 8'b10101100;
        msg_pkt_data[1] = 8'b10101101;
        msg_CRC = 15'b111001110100010; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC);
        RXstream(bitstream, bitstream.size());
        check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        tb_readaddr = 4'd0;
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], {3'd0,tb_byte_out}, "data 0");
        tb_readaddr = 4'd1;
        @(posedge tb_clk);
        check_out(msg_pkt_data[1], {3'd0,tb_byte_out}, "data 1");

        #(STROBE_PERIOD * 11);

        // ************************************************************************
        // Test Case 2: long bitstream
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream";

        reset_dut();
        msg_msg_id = 11'b10110010110;
        msg_pkt_size = 4'd8;
        msg_pkt_data[0] = 8'b10101100;
        msg_pkt_data[1] = 8'b10101101;
        msg_pkt_data[2] = 8'b10101001;
        msg_pkt_data[3] = 8'b10001101;
        msg_pkt_data[4] = 8'b10100101;
        msg_pkt_data[5] = 8'b10101111;
        msg_pkt_data[6] = 8'b00111101;
        msg_pkt_data[7] = 8'b11101101;
        msg_CRC = 15'b001100110011111; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC);
        RXstream(bitstream, bitstream.size());
        check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
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
        check_out(msg_pkt_data[7], {3'd0,tb_byte_out}, "data 7");

        #(STROBE_PERIOD * 11);

        // ************************************************************************
        // Test Case 3: long bitstream + stuffed bits
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream + stuffed bits";

        reset_dut();
        msg_msg_id = 11'b10110010110;
        msg_pkt_size = 4'd8;
        msg_pkt_data[0] = 8'b10101111;
        msg_pkt_data[1] = 8'b11101101;
        msg_pkt_data[2] = 8'b10101000;
        msg_pkt_data[3] = 8'b00001101;
        msg_pkt_data[4] = 8'b10100101;
        msg_pkt_data[5] = 8'b10101111;
        msg_pkt_data[6] = 8'b10111101;
        msg_pkt_data[7] = 8'b11101101;
        msg_CRC = 15'b001100110101010; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC);
        RXstream(bitstream, bitstream.size());
        check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
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
        check_out(msg_pkt_data[7], {3'd0,tb_byte_out}, "data 7");

        #(STROBE_PERIOD * 11);

        // ************************************************************************
        // Test Case 3: edge case stuffed bits at the end of a byte
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "edge case stuffed bits at the end of a byte";

        reset_dut();
        msg_msg_id = 11'b10110010110;
        msg_pkt_size = 4'd3;
        msg_pkt_data[0] = 8'b10111111;
        msg_pkt_data[1] = 8'b01101101;
        msg_pkt_data[2] = 8'b10101010;
        msg_CRC = 15'b011010011100101;
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC);
        RXstream(bitstream, bitstream.size());
        check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
        tb_readaddr = 4'd0;
        @(posedge tb_clk);
        check_out(msg_pkt_data[0], {3'd0,tb_byte_out}, "data 0");
        tb_readaddr = 4'd1;
        @(posedge tb_clk);
        check_out(msg_pkt_data[1], {3'd0,tb_byte_out}, "data 1");
        tb_readaddr = 4'd2;
        @(posedge tb_clk);
        check_out(msg_pkt_data[2], {3'd0,tb_byte_out}, "data 2");

        #(STROBE_PERIOD * 11);

        // ************************************************************************
        // Test Case 4: long bitstream + bit error
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream + bit error";

        enable_biterror = 1'b1;

        reset_dut();
        msg_msg_id = 11'b10110010110;
        msg_pkt_size = 4'd8;
        msg_pkt_data[0] = 8'b10101111;
        msg_pkt_data[1] = 8'b11101101;
        msg_pkt_data[2] = 8'b10101000;
        msg_pkt_data[3] = 8'b00001101;
        msg_pkt_data[4] = 8'b10100101;
        msg_pkt_data[5] = 8'b10101111;
        msg_pkt_data[6] = 8'b10111101;
        msg_pkt_data[7] = 8'b11101101;
        msg_CRC = 15'b001100110101010; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC);
        RXstream(bitstream, bitstream.size());
        check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
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
        check_out(msg_pkt_data[7], {3'd0,tb_byte_out}, "data 7");

        #(STROBE_PERIOD * 11);

        // ************************************************************************
        // Test Case 5: long bitstream + 1.5% slower
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream + 1.5% slower";

        lag = STROBE_PERIOD * 0.015;

        reset_dut();
        msg_msg_id = 11'b10110010110;
        msg_pkt_size = 4'd8;
        msg_pkt_data[0] = 8'b10101100;
        msg_pkt_data[1] = 8'b10101101;
        msg_pkt_data[2] = 8'b10101001;
        msg_pkt_data[3] = 8'b10001101;
        msg_pkt_data[4] = 8'b10100101;
        msg_pkt_data[5] = 8'b10101111;
        msg_pkt_data[6] = 8'b00111101;
        msg_pkt_data[7] = 8'b11101101;
        msg_CRC = 15'b001100110011111; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC);
        RXstream(bitstream, bitstream.size());
        check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
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
        check_out(msg_pkt_data[7], {3'd0,tb_byte_out}, "data 7");

        #(STROBE_PERIOD * 11);

        // ************************************************************************
        // Test Case 6: long bitstream + 1.5% faster
        // ************************************************************************
        tb_test_num = tb_test_num + 1;
        tb_test_case = "long bitstream + 1.5% faster";

        lag = STROBE_PERIOD * 0.015;
        lag = -lag;

        reset_dut();
        msg_msg_id = 11'b10110010110;
        msg_pkt_size = 4'd8;
        msg_pkt_data[0] = 8'b10101100;
        msg_pkt_data[1] = 8'b10101101;
        msg_pkt_data[2] = 8'b10101001;
        msg_pkt_data[3] = 8'b10001101;
        msg_pkt_data[4] = 8'b10100101;
        msg_pkt_data[5] = 8'b10101111;
        msg_pkt_data[6] = 8'b00111101;
        msg_pkt_data[7] = 8'b11101101;
        msg_CRC = 15'b001100110011111; 
        construct_pkt(msg_msg_id, msg_pkt_size, msg_pkt_data, msg_CRC);
        RXstream(bitstream, bitstream.size());
        check_out(msg_msg_id, tb_CAN_ID, "CAN ID");
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
        check_out(msg_pkt_data[7], {3'd0,tb_byte_out}, "data 7");

        #(STROBE_PERIOD * 11);

    end

endmodule