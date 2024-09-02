`timescale 10 ns / 1 ns
`define DATA_WIDTH 32

module shifter (
	input  [`DATA_WIDTH - 1:0] A,
	input  [              4:0] B,
	input  [              1:0] Shiftop,
	output [`DATA_WIDTH - 1:0] Result
);
	// TODO: Please add your logic code here
	wire [`DATA_WIDTH-1:0]sll_result,sra_result,srl_result;
	wire [1:0]sel;
	assign sel = Shiftop;
	assign sll_result = A << B;
	assign sra_result = $signed(A) >>> B;
	assign srl_result = A >> B;
	assign Result = ({32{~sel[0] & ~sel[1]}} & sll_result)
			| ({32{sel[0] & sel[1]}} & sra_result)
			| ({32{sel[0] & ~sel[1]}} & srl_result);
endmodule
