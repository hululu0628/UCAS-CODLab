`timescale 10 ns / 1 ns

module dirty_array(
	input clk,
        input rst,
	input [2:0]waddr,
	input [2:0]raddr,
	input wen,
	input wdata,
	output rdata
);

	reg [7:0]array;
	
	always @(posedge clk)
	begin
		if(rst)
                        array <= 8'b0;
                else if(wen)
			array[waddr] <= wdata;
	end

        assign rdata = array[raddr];
endmodule