`timescale 10 ns / 1 ns

`define TARRAY_DATA_WIDTH 24
`define TARRAY_ADDR_WIDTH 3

module tag_array(
	input                             clk,
        input                             rst,
	input  [`TARRAY_ADDR_WIDTH - 1:0] waddr,
	input  [`TARRAY_ADDR_WIDTH - 1:0] raddr,
	input                             wen,
	input  [`TARRAY_DATA_WIDTH - 1:0] wdata,
	output [`TARRAY_DATA_WIDTH - 1:0] rdata,
        output                            vsignal
);

	reg [`TARRAY_DATA_WIDTH-1:0] array[ (1 << `TARRAY_ADDR_WIDTH) - 1 : 0];
	reg [ (1 << `TARRAY_ADDR_WIDTH) - 1 : 0]varray;

	always @(posedge clk)
	begin
		if(wen)
                begin
			array[waddr] <= wdata;
                end
	end
        always @(posedge clk)
        begin
                if(rst)
                        varray <= 8'b0;
                else if(wen)
                        varray[waddr] <= 1'b1;
        end

        assign rdata = array[raddr];
        assign vsignal = varray[raddr];

endmodule
