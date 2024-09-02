`timescale 10ns / 1ns
//`include "cod-lab/fpga/design/ucas-cod/hardware/sources/reg_file/reg_file.v"
//`include "cod-lab/fpga/design/ucas-cod/hardware/sources/alu/alu.v"
//`include "cod-lab/fpga/design/ucas-cod/hardware/sources/shifter/shifter.v"


module simple_cpu(
	input             clk,
	input             rst,

	output [31:0]     PC,
	input  [31:0]     Instruction,

	output [31:0]     Address,
	output            MemWrite,
	output [31:0]     Write_data,
	output [ 3:0]     Write_strb,

	input  [31:0]     Read_data,
	output            MemRead
);

	// THESE THREE SIGNALS ARE USED IN OUR TESTBENCH
	// PLEASE DO NOT MODIFY SIGNAL NAMES
	// AND PLEASE USE THEM TO CONNECT PORTS
	// OF YOUR INSTANTIATION OF THE REGISTER FILE MODULE
	wire			RF_wen;
	wire [4:0]		RF_waddr;
	wire [31:0]		RF_wdata;

	// TODO: PLEASE ADD YOUR CODE BELOW

	//divide the instruction into some parts
	wire [5:0]opcode,func;
	wire [4:0]rs,rt,rd,shamt,REG;
	wire [15:0]immediate;
	wire [25:0]taddr;
	//determine the type of the instruction
	wire isRtype,isRshift,isRjump,isRmov,isREGIMM,isJump,isIbranch,isIload,isIstore,isIcalculate;
	//change the PC register
	wire PCchange;
	//change the PC register conditionally
	wire PCchangeCond;
	//CU signal
	//without MemWrite and MemRead
	wire RegWrite,MemtoReg,RegDst,IRWrite,PCWrite,PCWriteCond,ALUsrcA,IorD;
	wire [2:0]ALUOp,ALUsrcB;
	wire [1:0]PCsrc,Shiftersrc;
	//when the inst is RMOV and the current state is EXUCTION,the ALU input is different from other Rtype 
	wire isEXCUTION;
	
	//some detailed instruction
	wire isNOP;
	wire isblez,isbgtz,isbeq,isbne;
	wire ismovz,ismovn;
	wire isjalr;
	wire isjal;
	wire islui;
	//wires using for load instruction
	wire [31:0]W_LoadData,m_MemData;
	//addr_not_aligned = addr_aligned + Addr_offset
	wire [1:0]Addr_offset;
	//wire of register file
	wire [31:0]rdata1,rdata2;
	wire [4:0]raddr1,raddr2;
	//judge if rdata2 = 0
	//should be modified in pipeline
	wire rd1_eq_Zero,rd2_eq_Zero;
	//write_data are selected from these three
	wire [31:0]exwrite,memdatawrite;
	//pc relevant
	wire [31:0]addedpc,nextpc;
	wire [31:0]offset;
	wire PCselect;
	//when aluR or aluI is 1, ALUop should be set by funct or opcode
	wire isAddSub,isLogicalOp,isComp,isAddSubi,isLogicalOpi,isCompi;

	//store the data fetched from register
	wire [31:0]E_regA,E_regB;

	//the meaning of ALUOp
	wire aluADD,aluSUB,aluCOMP,aluR,aluI;
	//the result comes from PC or register file
	wire [31:0]A,B;
	//input of ALU
	//the alu source should be additionally discussed when the inst is RMOV or jalr 
	wire [31:0]aluA,aluB;
	//ALU input and output
	wire [2:0]ALUopcode;
	wire [31:0]aluResult;
	wire Overflow,CarryOut,Zero;

	wire [31:0]MW_ExcutionResult,e_ExcutionResult;
	wire W_regZero;

	//decide which op shoule the shifter do
	wire [1:0]Shiftop;
	//shifter input and output
	wire [31:0]shifterA;
	wire [4:0]shifterB;
	wire [31:0]de_shifterResult;
	//extend output
	wire [31:0]immediate32S,immediate32U,immediate32;

	///*PC Fetch*///
	/*PC register*/
	assign PCchange = PCWrite | PCchangeCond;
	assign PCchangeCond = PCWriteCond & PCselect;
	PC pcregister(clk,rst,PCchange,nextpc,PC);


	///*Decode*///
	/*Instruction Register*/
	InstructionRegister IR(clk,IRWrite,Instruction,isNOP,opcode,rs,rt,rd,shamt,REG,func,immediate,taddr);


	assign isRtype = ~(|opcode);
	assign isRshift = ~(|func[5:3]) & isRtype;
	assign isRjump = isRtype & ~func[5] & ~func[4] & func[3] & ~func[1];
	assign isRmov = isRtype & ~func[5] & ~func[4] & func[3] & func[1];
	assign isREGIMM = ~(|opcode[5:1]) & opcode[0];
	assign isIbranch = ~(|opcode[5:3]) & opcode[2];
	assign isJump = ~(|opcode[5:2]) & opcode[1];
	assign isIcalculate = ~opcode[5] & ~opcode[4] & opcode[3];
	assign isIload = opcode[5] & ~opcode[3];
	assign isIstore = opcode[5] & opcode[3];
	
	//instruction
	assign isbeq = isIbranch & ~opcode[0] & ~opcode[1];
	assign isbne = isIbranch & opcode[0] & ~opcode[1];
	assign isblez = isIbranch & ~opcode[0] & opcode[1];
	assign isbgtz = isIbranch & opcode[0] & opcode[1];
	assign ismovz = isRmov & ~func[0];
	assign ismovn = isRmov & func[0];
	assign isjalr = isRjump & func[0];
	assign isjal = ~(|opcode[5:2]) & opcode[1] & opcode[0];
	assign islui = ~opcode[5] & opcode[3] & opcode[2] & opcode[1] & opcode[0];

	/*Control Unit*/
	ControlUnit control(
		clk,
		rst,
		opcode,
		isNOP,
		isRtype,
		isREGIMM,
		isJump,
		isIbranch,
		isIcalculate,
		isIload,
		isIstore,
		RegDst,
		RegWrite,
		MemRead,
		MemWrite,
		MemtoReg,
		IRWrite,
		PCWrite,
		PCWriteCond,
		IorD,
		ALUOp,
		ALUsrcA,
		ALUsrcB,
		Shiftersrc,
		PCsrc
	);
	assign isEXCUTION = PCsrc[1] & PCsrc[0];

	/*Register File*/
	assign raddr1 = rs;			//in load and store, rs is base 
	assign raddr2 = rt;
	//WriteBack
	assign RF_waddr = (((rd & {5{RegDst}}) | (rt & {5{~RegDst}})) & {5{~isjal}}) | (5'b11111 & {5{isjal}});
	assign memdatawrite = W_LoadData & {32{MemtoReg}};
	assign exwrite = MW_ExcutionResult & {32{~MemtoReg}};
	assign RF_wdata = memdatawrite | exwrite;
	assign RF_wen = (RegWrite & ~isRmov) | ((RegWrite & ismovn & ~rd2_eq_Zero) | (RegWrite & ismovz & rd2_eq_Zero));

	reg_file register(
		.clk(clk),
		.waddr(RF_waddr),
		.raddr1(raddr1),
		.raddr2(raddr2),
		.wen(RF_wen),
		.wdata(RF_wdata),
		.rdata1(rdata1),
		.rdata2(rdata2)
	);
	assign rd1_eq_Zero = ~(|rdata1);
	assign rd2_eq_Zero = ~(|rdata2);
	RegisterA registerA(clk,rdata1,E_regA);
	RegisterB registerB(clk,rdata2,E_regB);

	///*Excution*///
	/*sign extend*/
	Extend extend(immediate,immediate32S,immediate32U);
	assign immediate32 = (immediate32U & {32{isLogicalOpi}}) | (immediate32S & {32{~isLogicalOpi}});
	/*Shifter*/
	assign Shiftop = (func[1:0] & {2{Shiftersrc[0]}})
		       | (2'b00 & {2{~Shiftersrc[0]}});
	assign shifterA = (E_regB & {32{Shiftersrc[0]}}) | (immediate32S & {32{~Shiftersrc[0]}});
	assign shifterB = ((E_regA[4:0] | shamt) & {5{Shiftersrc[0]}})
			| (5'b10 & {5{~Shiftersrc[1] & ~Shiftersrc[0]}}) 
			| (5'b10000 & {5{Shiftersrc[1] & ~Shiftersrc[0]}});
	shifter Shifter(.A(shifterA),.B(shifterB),.Shiftop(Shiftop),.Result(de_shifterResult));


	/*ALU*/
	//the following two parts are completed in Decoder
	assign A = (E_regA & {32{ALUsrcA}}) | (PC & {32{~ALUsrcA}});		//if the instruction is movz or movn, then A = 0;
	assign B = (E_regB & {32{~(|ALUsrcB)}}) 
		 | (immediate32 & {32{ALUsrcB[2]}})
		 | (offset & {32{~ALUsrcB[1] & ALUsrcB[0]}})
		 | (32'b100 & {32{ALUsrcB[1] & ~ALUsrcB[0]}})
		 | (32'b0 & {32{ALUsrcB[1] & ALUsrcB[0]}});

	assign aluADD = ~(|ALUOp);
	assign aluSUB = ~ALUOp[2] & ~ALUOp[1] & ALUOp[0];			//no instruction needs sub contorled by CU
	assign aluCOMP = ALUOp[1];
	assign aluR = ALUOp[2] & ~ALUOp[0];
	assign aluI = ALUOp[2] & ALUOp[0];

	assign isAddSub = ~func[3] & ~func[2] & aluR;
	assign isLogicalOp = ~func[3] & func[2] & aluR;
	assign isComp = func[3] & ~func[2] & aluR;
	assign isAddSubi = ~opcode[2] & ~opcode[1] & aluI;
	assign isLogicalOpi = opcode[2] & aluI;
	assign isCompi = ~opcode[2] & opcode[1] & aluI;
	//select a proper operation
	assign ALUopcode = ({func[1],2'b10} & {3{isAddSub}})
			| ({func[1],1'b0,func[0]} & {3{isLogicalOp}})
			| ({~func[0],2'b11} & {3{isComp & ~isjalr}})
			| ({opcode[1],2'b10} & {3{isAddSubi}})
			| ({opcode[1],1'b0,opcode[0]} & {3{isLogicalOpi}})
			| ({~opcode[0],2'b11} & {3{isCompi}})
			| (3'b010 & {3{isjalr}})
			| (3'b111 & {3{aluCOMP & ~(isbeq | isbne)}})
			| (3'b110 & {3{aluCOMP & (isbeq | isbne)}})
			| (3'b010 & {3{aluADD}});

	assign aluA = (A & {32{~(isRmov & isEXCUTION) & ~isjalr}}) | (32'b0 & {32{(isRmov & isEXCUTION)}}) | (PC & {32{isjalr}});
	assign aluB = (B & {32{~isjalr}}) | (32'b100 & {32{isjalr}});
	
	alu ALU(.A(aluA),.B(aluB),.ALUop(ALUopcode),.CarryOut(CarryOut),.Overflow(Overflow),.Zero(Zero),.Result(aluResult));

	assign e_ExcutionResult =  (aluResult & {32{~(isRshift | islui) & ~(isRmov & isEXCUTION)}}) 
		       | (de_shifterResult & {32{isRshift | islui}})
		       | (E_regA & {32{(isRmov & isEXCUTION)}});
	RegisterALUout aluout(clk,e_ExcutionResult,MW_ExcutionResult);

	//not used
	RegisterZero zero(clk,Zero,W_regZero);
	
	

	///*MEM*///
	assign Address = ({MW_ExcutionResult[31:2],2'b0} & {32{IorD}}) | (PC & {32{~IorD}});
	assign Addr_offset = MW_ExcutionResult[1:0];
	/*Memory Load*/
	loadData load(.opcode(opcode),.Read_data(Read_data),.rtdata(rdata2),.offset(Addr_offset),.Load_data(m_MemData));
	/*Data Save*/
	storeData store(.opcode(opcode),.offset(Addr_offset),.rtdata(rdata2),.Write_data(Write_data),.Write_strb(Write_strb));
	/*MemRegister*/
	RegisterMemData MDR(clk,m_MemData,W_LoadData);



	///*PCupdata*///
	assign addedpc = aluResult;
	assign offset = de_shifterResult;
	//PCsrc & PCWriteCond
	assign PCselect = 0 | 
			((isbeq & Zero) | (isbne & ~Zero) | (isbgtz & ~rd1_eq_Zero & Zero) | (isblez & (rd1_eq_Zero | ~Zero))
			| (isREGIMM & REG[0] & Zero) | (isREGIMM & ~REG[0] & ~Zero) | isRjump);
	assign nextpc = (E_regA & {32{PCsrc[1] & PCsrc[0]}})
		      | ({PC[31:28],taddr,2'b0} & {32{PCsrc[1] & ~PCsrc[0]}})
		      | (MW_ExcutionResult & {32{~PCsrc[1] & PCsrc[0]}})
		      | (addedpc & {32{~PCsrc[1] & ~PCsrc[0]}});

	
endmodule

module PC (
	input clk,
	input rst,
	input PCchange,
	input [31:0]newAddr,
	output reg[31:0]pc
);
	always @(posedge clk)
	begin
		if(rst == 1'b1)
		begin
			pc <= 32'b0;
		end
		else if(PCchange == 1'b1)
		begin
			pc <= newAddr;
		end
		else
			pc <= pc;
	end
endmodule

module Extend(
	input [15:0]imm16,
	output [31:0]imm32,
	output [31:0]imm32U
);
	assign imm32 = {{16{imm16[15]}},imm16};
	assign imm32U = {16'b0,imm16};
endmodule

module loadData(
	input [5:0]opcode,
	input [31:0]Read_data,
	input [31:0]rtdata,
	input [1:0]offset,
	output [31:0]Load_data
);
	wire [31:0]lb,lh,lw,lbu,lhu,lwl,lwr;
	wire offset_0,offset_1,offset_2,offset_3;
	

	assign offset_0 = ~offset[1] & ~offset[0];
	assign offset_1 = ~offset[1] & offset[0];
	assign offset_2 = offset[1] & ~offset[0];
	assign offset_3 = offset[1] & offset[0];

	//set lb,lh,lw...
	assign lb = 	({{24{Read_data[7]}},Read_data[7:0]} & {32{offset_0}})
			| ({{24{Read_data[15]}},Read_data[15:8]} & {32{offset_1}})
			| ({{24{Read_data[23]}},Read_data[23:16]} & {32{offset_2}})
			| ({{24{Read_data[31]}},Read_data[31:24]} & {32{offset_3}});

	assign lh = 	({{16{Read_data[15]}},Read_data[15:0]} & {32{offset_0}})
		        | ({{16{Read_data[31]}},Read_data[31:16]} & {32{offset_2}});

	assign lw = Read_data;

	assign lbu = 	({{24'b0},Read_data[7:0]} & {32{offset_0}})
			| ({{24'b0},Read_data[15:8]} & {32{offset_1}})
			| ({{24'b0},Read_data[23:16]} & {32{offset_2}})
			| ({{24'b0},Read_data[31:24]} & {32{offset_3}});
		   
	assign lhu = 	({{16'b0},Read_data[15:0]} & {32{offset_0}})
		        | ({{16'b0},Read_data[31:16]} & {32{offset_2}});
	
	assign lwl = 	({Read_data[7:0],rtdata[23:0]} & {32{offset_0}}) |
			({Read_data[15:0],rtdata[15:0]} & {32{offset_1}}) |
			({Read_data[23:0],rtdata[7:0]} & {32{offset_2}}) |
			(Read_data & {32{offset_3}});
	assign lwr = 	({rtdata[31:8],Read_data[31:24]} & {32{offset_3}}) |
			({rtdata[31:16],Read_data[31:16]} & {32{offset_2}}) |
			({rtdata[31:24],Read_data[31:8]} & {32{offset_1}}) |
			(Read_data & {32{offset_0}});

	//select the result
	assign Load_data = (lb & {32{~opcode[2] & ~opcode[1] & ~opcode[0]}}) |
			   (lh & {32{~opcode[2] & ~opcode[1] & opcode[0]}}) |
			   (lw & {32{~opcode[2] & opcode[1] & opcode[0]}}) | 
			   (lbu & {32{opcode[2] & ~opcode[1] & ~opcode[0]}}) |
			   (lhu & {32{opcode[2] & ~opcode[1] & opcode[0]}}) |
			   (lwl & {32{~opcode[2] & opcode[1] & ~opcode[0]}}) |
			   (lwr & {32{opcode[2] & opcode[1] & ~opcode[0]}});
endmodule

module storeData (
	input [1:0]offset,
	input [5:0]opcode,
	input [31:0]rtdata,
	output [31:0]Write_data,
	output [3:0]Write_strb
);
	wire sb,sh,sw,swl,swr;
	wire offset_0,offset_1,offset_2,offset_3;
	wire is0001,is0010,is0100,is0011,is0111,is1111,is1110,is1100,is1000;
	wire issb1,issb2,issb3,issb4,isshhigh,isshlow;
	wire swleft1,swleft2,swleft3,swleft4,swright1,swright2,swright3,swright4;

	assign sb = ~opcode[2] & ~opcode[1] & ~opcode[0];
	assign sh = ~opcode[2] & ~opcode[1] & opcode[0];
	assign sw = ~opcode[2] & opcode[1] & opcode[0];
	assign swl = ~opcode[2] & opcode[1] & ~opcode[0];
	assign swr = opcode[2] & opcode[1] & ~opcode[0];

	assign offset_0 = ~offset[1] & ~offset[0];
	assign offset_1 = ~offset[1] & offset[0];
	assign offset_2 = offset[1] & ~offset[0];
	assign offset_3 = offset[1] & offset[0];

	//store the left/right n bytes of rtdata
	assign swleft1 = swl & offset_0;
	assign swleft2 = swl & offset_1;
	assign swleft3 = swl & offset_2;
	assign swleft4 = swl & offset_3;
	assign swright4 = swr & offset_0;
	assign swright3 = swr & offset_1;
	assign swright2 = swr & offset_2;
	assign swright1 = swr & offset_3;

	//store n-th byte of rtdata
	assign issb1 = sb & offset_0;
	assign issb2 = sb & offset_1;
	assign issb3 = sb & offset_2;
	assign issb4 = sb & offset_3;

	assign isshlow = sh & offset_0;			//store lower 2 bytes
	assign isshhigh = sh & offset_2;		//store higher 2 bytes

	//set Write_strb
	assign is0001 = issb1 | swleft1;
	assign is0010 = issb2;
	assign is0100 = issb3;
	assign is0011 = isshlow | swleft2;
	assign is0111 = swleft3;
	assign is1111 = sw | swleft4 | swright4;
	assign is1110 = swright3;
	assign is1100 = swright2 | isshhigh;
	assign is1000 = swright1 | issb4;

	assign Write_data = ({24'b0,rtdata[31:24]} & {32{swleft1}})
			  | ({16'b0,rtdata[31:16]} & {32{swleft2}})
			  | ({8'b0,rtdata[31:8]} & {32{swleft3}})
			  | (rtdata & {32{swleft4 | swright4 | issb1 | isshlow | sw}})
			  | ({rtdata[23:0],8'b0} & {32{swright3 | issb2}})
			  | ({rtdata[15:0],16'b0} & {32{swright2 | issb3 | isshhigh}})
			  | ({rtdata[7:0],24'b0} & {32{swright1 | issb4}});
	assign Write_strb = (4'b0001 & {4{is0001}})
			  | (4'b0010 & {4{is0010}})
			  | (4'b0100 & {4{is0100}})
			  | (4'b0011 & {4{is0011}})
			  | (4'b0111 & {4{is0111}})
			  | (4'b1111 & {4{is1111}})
			  | (4'b1110 & {4{is1110}})
			  | (4'b1100 & {4{is1100}})
			  | (4'b1000 & {4{is1000}});
endmodule


module ControlUnit (
	input clk,
	input rst,
	input [5:0]opcode,
	input isNOP,
	input isRtype,
	input isREGIMM,
	input isJump,
	input isIbranch,
	input isIcalculate,
	input isIload,
	input isIstore,
	output RegDst,
	output RegWrite,
	output MemRead,
	output MemWrite,
	output MemtoReg,
	output IRWrite,
	output PCWrite,
	output PCWriteCond,
	output IorD,
	output [2:0]ALUOp,
	output ALUsrcA,
	output [2:0]ALUsrcB,
	output [1:0]Shiftersrc,
	output [1:0]PCsrc
);
<<<<<<< HEAD
	localparam INIT 		= 13'b0000000000001,    //0
		   DECODE_REGFETCH 	= 13'b0000000000010,    //1
		   EXCUTION 		= 13'b0000000000100,    //2
		   REGCOMPLETION 	= 13'b0000000001000,    //3
		   JUMP 		= 13'b0000000010000,    //4
		   BRANCHCOPMLETION 	= 13'b0000000100000,    //5
		   ICALCULATE 		= 13'b0000001000000,    //6
		   LOAD_STORE 		= 13'b0000010000000,    //7
		   REGWRITE 		= 13'b0000100000000,    //8
		   ICOMPLETION    	= 13'b0001000000000,    //9
		   MEMREAD 		= 13'b0010000000000,    //10
		   MEMWRITE 		= 13'b0100000000000,    //11
		   LOADCOMPLETION 	= 13'b1000000000000;    //12
=======
	localparam INIT 		= 5'b00001,
		   DECODE	 	= 5'b00010,
		   EXCUTION 		= 5'b00100,
		   MEM		 	= 5'b01000,
		   WRITEBACK 		= 5'b10000;
>>>>>>> codlab/master
	
	reg [4:0]current_state,next_state;

	always @(posedge clk)
	begin
		if(rst)
		begin
			current_state <= INIT;
		end
		else
		begin
			current_state <= next_state;
		end
	end

	/*
	case(1'b1)
		current_state[0]:
		...
		...
		...
		default:
			...
	*/

	always @(*)
	begin
		case (current_state)
			INIT:
			begin
				next_state = DECODE;
			end
			DECODE:
			begin
				if(isNOP)
					next_state = INIT;
				else
					next_state = EXCUTION;
			end
			EXCUTION:
			begin
				if(isRtype | isIcalculate | (isJump & opcode[0]))
					next_state = WRITEBACK;
				else if(isIbranch | isREGIMM | (isJump & ~opcode[0]))
					next_state = INIT;
				else if(isIstore | isIload)
					next_state = MEM;
				else
					next_state = INIT;
			end
			MEM:
			begin
				if(isIload)
					next_state = WRITEBACK;
				else
					next_state = INIT;
			end
			WRITEBACK:
			begin
				next_state = INIT;
			end
			default: 
				next_state = INIT;
		endcase
	end
	
	assign RegDst 		= current_state[4] & (isRtype | isJump);
	assign IorD 		= current_state[3] & (isIload | isIstore);
	assign RegWrite 	= current_state[4] & (isRtype | isIload | isIcalculate | isJump);
	assign MemRead 		= current_state[3] & isIload;
	assign MemWrite 	= current_state[3] & isIstore;
	assign MemtoReg 	= current_state[4] & isIload;
	assign IRWrite 		= current_state[0];
	assign PCWrite 		= (current_state[2] & isJump) | current_state[0];
	assign PCWriteCond 	= current_state[2] & (isRtype | isREGIMM | isIbranch);
	assign ALUsrcA 		= current_state[2] & ~isJump;
	assign ALUsrcB 		= (3'b010 & {3{current_state[0] | (current_state[2] & isJump)}})
		       		| (3'b001 & {3{current_state[1]}})
			        | (3'b011 & {3{current_state[2] & isREGIMM}})
		       		| (3'b100 & {3{current_state[2] &(isIcalculate | isIload | isIstore)}})
		       		| 3'b000;
	assign ALUOp 		= (3'b100 & {3{current_state[2] & isRtype}})
		     		| (3'b101 & {3{current_state[2] & isIcalculate}})
		     		| (3'b010 & {3{current_state[2] & (isREGIMM | isIbranch)}});
	assign Shiftersrc 	= (2'b00 & {2{current_state[1]}})
			  	| (2'b10 & {2{current_state[2] & isIcalculate}})
			  	| (2'b01 & {2{~current_state[1] & ~(current_state[2] & isIcalculate)}});
	assign PCsrc 		= (2'b11 & {2{current_state[2] & isRtype}})
		     		| (2'b01 & {2{current_state[2] & (isREGIMM | isIbranch)}})
		     		| (2'b10 & {2{current_state[2] & isJump}});
	
	/*
	always @(posedge clk)
	begin
		if(current_state == REGWRITE || current_state == LOADCOMPLETION)
			RegDst = 1;
		else
			RegDst = 0;
	end
	always @(posedge clk)
	begin
		if(current_state == MEMREAD || current_state == MEMWRITE)
			IorD = 1;
		else
			IorD = 0;
	end
	always @(posedge clk)
	begin
		if(current_state == REGWRITE || current_state == ICOMPLETION || current_state == LOADCOMPLETION)
			RegWrite = 1;
		else
			RegWrite = 0;
	end
	always @(posedge clk) 
	begin
		if(current_state == MEMREAD || current_state == INIT)
			MemRead = 1;
		else
			MemRead = 0;	
	end
	always @(posedge clk)
	begin
		if(current_state == MEMWRITE)
			MemWrite = 1;
		else
			MemWrite = 0;	
	end
	always @(posedge clk) 
	begin
		if(current_state == LOADCOMPLETION)
			MemtoReg = 1;
		else
			MemtoReg = 0;	
	end
	always @(posedge clk) 
	begin
		if(current_state == INIT)
			IRWrite = 1;
		else
			IRWrite = 0;	
	end
	always @(posedge clk) 
	begin
		if(current_state == JUMP || current_state == INIT)
			PCWrite = 1;
		else
			PCWrite = 0;
	end
	always @(posedge clk)
	begin
		if(current_state == EXCUTION || current_state == REGCOMPLETION || current_state == BRANCHCOPMLETION)
			PCWriteCond = 1;
		else
			PCWriteCond = 0;	
	end
	always @(posedge clk)
	begin
		if(current_state == EXCUTION || current_state == REGCOMPLETION || 
		   current_state == ICALCULATE || current_state == LOAD_STORE)
		   	ALUsrcA = 1;
		else
			ALUsrcA = 0;
	end
	always @(posedge clk)
	begin
		case(current_state)
			INIT:	
			begin
				ALUsrcB = 3'b010;
			end
			DECODE_REGFETCH:
			begin
				ALUsrcB = 3'b001;
			end
			REGCOMPLETION:
			begin
				ALUsrcB = 3'b011;
			end
			JUMP:
			begin
				ALUsrcB = 3'b010;
			end
			BRANCHCOPMLETION:
			begin
				ALUsrcB = 3'b001;
			end
			ICALCULATE:
			begin
				ALUsrcB = 3'b100;
			end
			LOAD_STORE:
			begin
				ALUsrcB = 3'b100;
			end
			default:
				ALUsrcB = 3'b000;
		endcase	
	end
	always @(posedge clk )
	begin
		case (current_state)
			EXCUTION:
			begin
				ALUOp = 3'b100;
			end
			REGCOMPLETION:
			begin
				ALUOp = 3'b010;
			end
			BRANCHCOPMLETION:
			begin
				ALUOp = 3'b010;
			end
			ICALCULATE:
			begin
				ALUOp = 3'b101;
			end
			LOAD_STORE:
			begin
				ALUOp = 3'b010;
			end 
			default: 
				ALUOp = 3'b000;
		endcase	
	end
	always @(posedge clk)
	begin
		if(current_state == DECODE_REGFETCH)
			Shiftersrc = 2'b0;
		else if(current_state == ICALCULATE)
			Shiftersrc = 2'b10;	
		else
			Shiftersrc = 2'b1;
	end
	always @(posedge clk)
	begin
		case(current_state)
			EXCUTION:
			begin
				PCsrc = 2'b11;
			end
			REGCOMPLETION:
			begin
				PCsrc = 2'b01;
			end
			JUMP:
			begin
				PCsrc = 2'b10;
			end
			BRANCHCOPMLETION:
			begin
				PCsrc = 2'b01;
			end
			default:
				PCsrc = 2'b00;
		endcase	
	end
	*/


endmodule

module InstructionRegister (
	input clk,
	input IRWrite,
	input [31:0]nextInstruction,
	output isNOP,
	output [5:0]opcode,
	output [4:0]rs,
	output [4:0]rt,
	output [4:0]rd,
	output [4:0]shamt,
	output [4:0]REG,
	output [5:0]func,
	output [15:0]immediate,
	output [25:0]taddr
);
	reg [31:0]Instruction;
	always @(posedge clk) begin
		if(IRWrite==1'b1)
			Instruction <= nextInstruction;
		else
			Instruction <= Instruction;
	end

	assign isNOP = ~(|Instruction);
	assign opcode = Instruction[31:26];
	assign rs = Instruction[25:21];
	assign rt = Instruction[20:16];
	assign rd = Instruction[15:11];
	assign shamt = Instruction[10:6];
	assign REG = Instruction[20:16];
	assign func = Instruction[5:0];
	assign immediate = Instruction[15:0];
	assign taddr = Instruction[25:0];
endmodule

module RegisterA (
	input clk,
	input [31:0]rdata1,
	output reg [31:0]E_regA
);
	always @(posedge clk)
	begin
		E_regA <= rdata1;	
	end
	
endmodule

module RegisterB (
	input clk,
	input [31:0]rdata2,
	output reg [31:0]E_regB
);
	always @(posedge clk)
	begin
		E_regB <= rdata2;	
	end
	
endmodule

module RegisterALUout (
	input clk,
	input [31:0]e_ExcutionResult,
	output reg [31:0]MW_ExcutionResult
);
	always @(posedge clk)
	begin
		MW_ExcutionResult <= e_ExcutionResult;	
	end
endmodule

module RegisterZero (
	input clk,
	input [31:0]Zero,
	output reg [31:0]W_regZero
);
	always @(posedge clk)
	begin
		W_regZero <= Zero;	
	end
endmodule


module RegisterMemData (
	input clk,
	input [31:0]m_MemData,
	output reg [31:0]W_LoadData
);
	always @(posedge clk)
	begin
		W_LoadData <= m_MemData;	
	end
endmodule


