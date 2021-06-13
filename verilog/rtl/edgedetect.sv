// File name:   edgedetect.sv
// Created:     11/28/2020
// Author:      Zachary Ellis
// Version:     1.2  Only detect negative edges
// Description: edge detector for synchronization of CAN bus

module edgedetect (
    input clk,
    input nRST,
    input CANRX,
    output edgedet
);

    reg [1:0] delay_ff;

    assign edgedet = ~delay_ff[0] & delay_ff[1];

    always_ff @(posedge clk, negedge nRST) begin
        if(nRST == 0)
            delay_ff <= '0;
        else begin
            delay_ff[0] <= CANRX;
            delay_ff[1] <= delay_ff[0];
        end
    end

endmodule