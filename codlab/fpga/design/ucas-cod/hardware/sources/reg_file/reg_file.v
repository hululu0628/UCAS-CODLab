`timescale 10 ns / 1 ns

`define DATA_WIDTH 32
`define ADDR_WIDTH 5

module reg_file(
	input                       clk,
	input  [`ADDR_WIDTH - 1:0]  waddr,
	input  [`ADDR_WIDTH - 1:0]  raddr1,
	input  [`ADDR_WIDTH - 1:0]  raddr2,
	input                       wen,
	input  [`DATA_WIDTH - 1:0]  wdata,
	output [`DATA_WIDTH - 1:0]  rdata1,
	output [`DATA_WIDTH - 1:0]  rdata2
);

	// TODO: Please add your logic design here
	reg [`DATA_WIDTH-1:0] rf [`DATA_WIDTH-1:0];
	always @(posedge clk) 
	begin
		if (waddr!=0 && wen==1)
			rf[waddr] <= wdata;
	end
	assign rdata1 = rf[raddr1] & {32{|raddr1}};
	assign rdata2 = rf[raddr2] & {32{|raddr2}};
endmodule
