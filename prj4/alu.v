`timescale 10 ns / 1 ns
`define DATA_WIDTH 32

module alu(
	input  [`DATA_WIDTH - 1:0]  A,
	input  [`DATA_WIDTH - 1:0]  B,
	input  [              2:0]  ALUop,
	output                      Overflow,
	output                      CarryOut,
	output                      Zero,
	output [`DATA_WIDTH - 1:0]  Result
);
	// TODO: Please add your logic design here
	wire [`DATA_WIDTH-1:0]result_and,result_or,sum,result_comp,result_nor,result_xor;
	wire [`DATA_WIDTH-1:0]complement_B;
	wire issum,isand,isor,isxor,isnor,iscomp;
	wire comp;
	wire cout;
	wire issub;

	assign issub = ~ALUop[2] & (ALUop[1] | ALUop[0]);

	//and operation
	assign result_and = A & B;
	//or operation
	assign result_or = A | B;
	//xor operation
	assign result_xor = A ^ B;
	//nor operation
	assign result_nor = ~(A | B);
	//when the op is sub, get the 1's complement code of B
	assign complement_B = B ^ {32{issub}};
	//add
	assign {cout,sum} = {1'b0,A}+{1'b0,complement_B}+{32'b0,issub};
	//overflow && carryout
	assign Overflow = (~A[31] && ~complement_B[31] && sum[31]) || (A[31] && complement_B[31] && ~sum[31]);
	assign CarryOut = cout^issub;
	//slt
	assign comp = ((sum[31]^Overflow) & ~ALUop[0]) | (CarryOut & ALUop[0]);
	assign result_comp = {31'b0,comp};
	//select the final result，using one-hot encoding 
	assign isand = &ALUop;
	assign isor = ~ALUop[0] & ALUop[1] & ALUop[2];
	assign isxor = ~ALUop[0] & ~ALUop[1] & ALUop[2];
	assign iscomp = ALUop[1] & ~ALUop[2];
	assign issum = ~ALUop[1] & ~ALUop[2];

	assign Result = ({32{isand}} & result_and)
			| ({32{isor}} & result_or)
			| ({32{isxor}} & result_xor)
			| ({32{isnor}} & result_nor)
			| ({32{issum}} & sum)
			| ({32{iscomp}} & result_comp);
	assign Zero = ~(|Result);
endmodule
