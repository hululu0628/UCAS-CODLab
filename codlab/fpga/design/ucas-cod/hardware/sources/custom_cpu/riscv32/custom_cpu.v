`timescale 10ns / 1ns

module custom_cpu(
	input         clk,
	input         rst,

	//Instruction request channel
	output [31:0] PC,
	output        Inst_Req_Valid,
	input         Inst_Req_Ready,

	//Instruction response channel
	input  [31:0] Instruction,
	input         Inst_Valid,
	output        Inst_Ready,

	//Memory request channel
	output [31:0] Address,
	output        MemWrite,
	output [31:0] Write_data,
	output [ 3:0] Write_strb,
	output        MemRead,
	input         Mem_Req_Ready,

	//Memory data response channel
	input  [31:0] Read_data,
	input         Read_data_Valid,
	output        Read_data_Ready,

	input         intr,

	output [31:0] cpu_perf_cnt_0,
	output [31:0] cpu_perf_cnt_1,
	output [31:0] cpu_perf_cnt_2,
	output [31:0] cpu_perf_cnt_3,
	output [31:0] cpu_perf_cnt_4,
	output [31:0] cpu_perf_cnt_5,
	output [31:0] cpu_perf_cnt_6,
	output [31:0] cpu_perf_cnt_7,
	output [31:0] cpu_perf_cnt_8,
	output [31:0] cpu_perf_cnt_9,
	output [31:0] cpu_perf_cnt_10,
	output [31:0] cpu_perf_cnt_11,
	output [31:0] cpu_perf_cnt_12,
	output [31:0] cpu_perf_cnt_13,
	output [31:0] cpu_perf_cnt_14,
	output [31:0] cpu_perf_cnt_15,

	output [69:0] inst_retire
);

//debug, should be removed
/*
reg [31:0]debugcnt;
always @(posedge clk) begin
        if(rst)
                debugcnt <= 32'b0;
        else
                debugcnt <= debugcnt + 1;
        if(debugcnt > 32'd100000)
                $finish;
end*/

/* The following signal is leveraged for behavioral simulation, 
* which is delivered to testbench.
*
* STUDENTS MUST CONTROL LOGICAL BEHAVIORS of THIS SIGNAL.
*
* inst_retired (70-bit): detailed information of the retired instruction,
* mainly including (in order) 
* { 
*   reg_file write-back enable  (69:69,  1-bit),
*   reg_file write-back address (68:64,  5-bit), 
*   reg_file write-back data    (63:32, 32-bit),  
*   retired PC                  (31: 0, 32-bit)
* }
*
*/

  	//wire [69:0] inst_retire;

// TODO: Please add your custom CPU code here
	wire			RF_wen;
	wire [4:0]		RF_waddr;
	wire [31:0]		RF_wdata;

        //控制信号
        wire iw_PipelineBlock,m_PipelineBlock;
        wire w_RegWrite;
        wire m_MemRead,m_MemWrite;
        wire m_MemtoReg,w_MemtoReg;
        wire e_ALUsrcA,e_ALUsrcB,e_Shiftsrc;
        wire [2:0]e_ALUop;
        wire [2:0]iw_Extype;

        //PC更新
        wire [31:0]addedPC,recoverPC,D_recoverPC,E_recoverPC,jumps1,jumpPC,branchPC,selectedPC;
        wire needjump,needpredict;
        wire PCchange,PCselect;

        //控制相应的阶段是否产生阻塞
	wire iwblock,idblock,exblock,mblock,wblock;
        //控制相应的阶段是否生成气泡
        //处理方法为使该阶段的instr_valid为零
        wire idbubble,exbubble,mbubble,wbubble;
        wire idbubble_branch;
        wire id_bubble;
        //握手
        wire f_valid,d_valid,e_valid,m_valid;
        wire f_ready,d_ready,e_ready,m_ready;
        wire f_instr_valid,d_instr_valid,e_instr_valid,m_instr_valid;
        wire D_instr_valid,E_instr_valid,M_instr_valid,W_instr_valid;
        //分支预测相关
        wire BranchTaken,D_BranchTaken,E_BranchTaken;
        wire isbeq,isbne,isbge,isbgeu,isblt,isbltu;
        wire Wrong_Prediction;
        wire WrongPreReg;
        //各阶段译码
        wire [6:0]opcode;
        wire [4:0]rd,D_rd,E_rd,M_rd,W_rd,rs1,D_rs1,rs2,D_rs2;
        wire [4:0]shamt,D_shamt,E_shamt;
        wire [2:0]funct3,D_funct3,E_funct3,M_funct3,W_funct3;
        wire [6:0]funct7,D_funct7,E_funct7,M_funct7,W_funct7;
        wire isRtype,isItype_C,isItype_J,isItype_L,isUtype,isJtype,isBtype,isStype;
        wire [7:0]instr_type,D_instr_type,E_instr_type,M_instr_type,W_instr_type;
        wire islui,D_islui,E_islui;
        //各阶段立即数
        wire [31:0]immediate32,D_immediate32,E_immediate32;
        //数据传递
        wire [31:0]d_A,d_B,E_A,E_B,e_EXResult,e_WriteData,M_EXResult,M_WriteData,m_MEMResult,W_EXResult,W_MEMResult;
        //各阶段PC
        wire [31:0]D_PC,E_PC,M_PC,W_PC;

        //寄存器存取数据
        wire [4:0]raddr1,raddr2;
        wire [31:0]rdata1,rdata2;

        //数据冒险判断
        wire Mdata_risk_s1,Mdata_risk_s2,Wdata_risk_s1,Wdata_risk_s2;
        wire data_risk_s1,data_risk_s2;


        //Excution阶段生成
        wire e_isShift,e_isjal,e_isjalr;
        wire [1:0]e_Shiftop;
        wire [31:0]e_shifterA;
        wire [4:0]e_shifterB;
        wire [31:0]e_shiftResult;
        wire [31:0]e_A,e_B,e_aluResult;
        wire CarryOut,Overflow,Zero;

        //WriteBack阶段生成
        wire [31:0]memdatawrite,exwrite,w_Result;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        assign inst_retire = {RF_wen,RF_waddr,RF_wdata,W_PC};
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /*Control Unit*/
        //无性能计数器
	//assign if_PipelineBlock = ~Inst_Req_Ready;
        assign iw_PipelineBlock = ~Inst_Valid;
        //assign sl_PipelineBlock = ~Mem_Req_Ready & (SL_instr_type[7] | SL_instr_type[3]);
        assign m_PipelineBlock = ((~Read_data_Valid & M_instr_type[3]) | (~Mem_Req_Ready & M_instr_type[7]));
	assign w_RegWrite 	= |W_instr_type[5:0];
	assign m_MemWrite 	= M_instr_type[7];
	assign m_MemtoReg 	= M_instr_type[3];
        assign w_MemtoReg       = W_instr_type[3];
	assign e_ALUsrcA 	= (|E_instr_type[3:0]) | E_instr_type[6] | E_instr_type[7];
	assign e_ALUsrcB 	= E_instr_type[0] | E_instr_type[6];
	assign e_Shiftsrc 	= E_instr_type[1];
        assign e_ALUop          = (E_funct3 & {3{(E_instr_type[0] | E_instr_type[1])}})
                                | ({2'b0,(E_instr_type[0] & E_funct7[5])})
                                | ({~E_funct3[2],E_funct3[2],E_funct3[1]} & {3{E_instr_type[6]}});
        assign iw_Extype        = {instr_type[4],instr_type[6],instr_type[7]} | {3{instr_type[5]}};


	assign Read_data_Ready  = 1'b1;

        reg regMemRead,mrstatus;
        always @(posedge clk)
        begin
                if(rst)
                        regMemRead <= 1'b0;
                else if(Mem_Req_Ready & M_instr_type[3])
                        regMemRead <= 1'b0;
                else if(~mblock & E_instr_type[3])
                        regMemRead <= 1'b1;
        end
        assign m_MemRead = regMemRead;

        reg regInst_Ready;
        always @(posedge clk)
        begin
                if(rst)
                        regInst_Ready <= 1'b1;
                else if(Inst_Valid)
                        regInst_Ready <= 1'b0;
                else if(Inst_Req_Ready)
                        regInst_Ready <= 1'b1;
        end
        assign Inst_Ready = regInst_Ready;
        /*框架直接访问内存的逻辑是队列空且有valid信号，但ddr发来的ready信号有延迟，
          导致PC更新比Ready信号更早，实际上是没有握手就接收了数据，导致分支预测的PC无法撤回，
          cache时改回来*/
        reg Irv;
        reg [9:0]req_again_cnt;
        always @(posedge clk)
        begin
                if(rst)
                        req_again_cnt <= 10'b0;
                else if(~Irv)
                        req_again_cnt <= req_again_cnt + 1;
                else if(Irv)
                        req_again_cnt <= 10'b1;
        end
        always @(posedge clk)
        begin
                if(rst)
                        Irv <= 1'b1;
                else if(&req_again_cnt)
                        Irv <= 1'b1;
                else if(Inst_Valid)
                        Irv <= 1'b1;
                else if(Inst_Req_Ready)
                        Irv <= 1'b0;
        end
        assign Inst_Req_Valid = Irv & ~rst;
        /*reg Irv;
        reg irvstatus;
        always @(posedge clk)
        begin
                if(rst)
                begin
                        Irv <= 1'b1;
                        irvstatus <= 1'b0;
                end
                else
                begin
                        if(Inst_Req_Ready & ~Wrong_Prediction)
                                Irv <= 1'b0;
                        if(needpredict)
                        begin
                                Irv <= 1'b0;
                                irvstatus <= 1'b1;
                        end
                        if(irvstatus)
                        begin
                                Irv <= 1'b1;
                                irvstatus <= 1'b0;
                        end
                        if(Inst_Valid & ~needpredict)
                                Irv <= 1'b1;
                end
                
        end
        assign Inst_Req_Valid = (Irv & ~Wrong_Prediction) & ~rst;*/
        
        
        //block
        //assign ifblock = if_PipelineBlock | iw_PipelineBlock | sl_PipelineBlock | rdw_PipelineBlock;
        //应注意到在先执行的指令处于MEM阶段时，处于IF(+IW)阶段的指令若在阻塞结束之前收到内存的数据，则不会接收
        //目前的处理方案为抛弃本次发来的数据，等待下一次数据，同时也不会更新PC值
        assign iwblock = iw_PipelineBlock | m_PipelineBlock;
        assign idblock = m_PipelineBlock;
        assign exblock = m_PipelineBlock;
        assign mblock = m_PipelineBlock;
        assign wblock = 1'b0;

        //bubble, 使用reg传递bubble信号，因为采用七级流水，IF阶段无法插入bubble，需要用寄存器传递到IW阶段
        //用于分支预测和jump指令
        //若取消的指令仍为branch，则需要根据bubble或instr_type认为其并不能作为跳转地址
        //assign iwbubble = if_PipelineBlock & Wrong_Prediction;
        assign idbubble = iw_PipelineBlock;
        assign exbubble = Wrong_Prediction;
        assign mbubble = 1'b0;
        assign wbubble = m_PipelineBlock;

        WrongPreSignalRegister SignalReg(clk,rst,Wrong_Prediction,Inst_Valid,WrongPreReg,idbubble_branch);

        assign id_bubble = idbubble | idbubble_branch;

        assign f_valid = ~id_bubble & ~rst & ~WrongPreReg;
        assign d_valid = ~exbubble & ~rst;
        assign e_valid = ~mbubble & ~rst;
        assign m_valid = ~wbubble & ~rst;

        assign f_ready = ~idblock & ~rst & ~WrongPreReg;
        assign d_ready = ~exblock & ~rst;
        assign e_ready = ~mblock & ~rst;
        assign m_ready = ~wblock & ~rst;

        assign f_instr_valid = ~id_bubble & ~WrongPreReg;
        assign d_instr_valid = D_instr_valid & ~exbubble;
        assign e_instr_valid = E_instr_valid & ~mbubble;
        assign m_instr_valid = M_instr_valid & ~wbubble;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //PredictedPC
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///*Instruction Fetch*///
	/*  register*/
        ///not finished, require pc prediction and risk handling
        //assign PC = selectedPC;
	assign PCchange = (Inst_Valid & ~iwblock & ~WrongPreReg);
	//assign PCchangeCond = PCWriteCond & PCselect;
        PCAdder PCadder1(PC,addedPC);
        BranchAdder BranchAdder(PC,immediate32,branchPC);

        assign jumps1 = (d_A & {32{D_instr_type[2]}}) | (D_PC & {32{D_instr_type[5]}});
        JumpAdder JumpAdder(D_immediate32,jumps1,jumpPC);

        assign needjump = D_instr_type[5] | D_instr_type[2];
        assign needpredict = instr_type[6] & ~Wrong_Prediction;         //???握手机制
        Predictor Predictor(clk,rst,needpredict,Wrong_Prediction,PC,BranchTaken);
        
        assign recoverPC = (branchPC & {32{~BranchTaken}}) | (addedPC & {32{BranchTaken}});

	PC pc(clk,rst,PCchange,BranchTaken,needjump,Wrong_Prediction,addedPC,E_recoverPC,branchPC,jumpPC,PC);
        
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ///*Instruction Wait*///

        assign opcode = Instruction[6:0];
        assign rd = Instruction[11:7];
        assign rs1 = Instruction[19:15];
        assign rs2 = Instruction[24:20];
        assign shamt = rs2;
        assign funct3 = Instruction[14:12];
        assign funct7 = Instruction[31:25];

        assign isRtype = opcode[5] & opcode[4] & ~opcode[2];
	assign isItype_C = ~opcode[5] & opcode[4] & ~opcode[2];
        assign isItype_J = opcode[6] & ~opcode[3] & opcode[2];
        assign isItype_L = ~opcode[5] & ~opcode[4] & opcode[0];         //否则instr_type在无指令时会被认为是Load
        assign isUtype = ~opcode[6] & opcode[2];
        assign isJtype = opcode[3];
        assign isBtype = (opcode == 7'b1100011) & Inst_Valid;
        assign isStype = ~opcode[6] & opcode[5] & ~opcode[4];

        assign islui = ~opcode[6] & opcode[5] & opcode[2];

        assign instr_type = {isStype,isBtype,isJtype,isUtype,isItype_L,isItype_J,isItype_C,isRtype};

        Extend extend(Instruction,iw_Extype,immediate32);
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        IDRegister IDReg(
                .clk(clk),
                .rst(rst),
                .valid(f_valid),
                .ready(f_ready),
        
                .instr_valid(f_instr_valid),
                .D_instr_valid(D_instr_valid),

                .PC(PC),
                .recoverPC(recoverPC),
                .D_PC(D_PC),
                .D_recoverPC(D_recoverPC),

                .instr_type(instr_type),
                .funct3(funct3),
                .funct7(funct7),
                .D_instr_type(D_instr_type),
                .D_funct3(D_funct3),
                .D_funct7(D_funct7),

                .immediate32(immediate32),
                .shamt(shamt),
                .D_immediate32(D_immediate32),
                .D_shamt(D_shamt),

                .rs1(rs1),
                .rs2(rs2),
                .rd(rd),
                .D_rs1(D_rs1),
                .D_rs2(D_rs2),
                .D_rd(D_rd),

                .BranchTaken(BranchTaken),
                .D_BranchTaken(D_BranchTaken),

                .islui(islui),
                .D_islui(D_islui)
        );
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///*Decode*///

	/*Register File*/
	assign raddr1 = D_rs1;			//in load and store, rs is base 
	assign raddr2 = D_rs2;
	//WriteBack
	assign RF_waddr = W_rd;
	assign RF_wdata = w_Result;
	assign RF_wen = w_RegWrite;

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

        //真实内存访问情况下的数据冒险似乎不可能在ID和EX阶段时发生
        assign Wdata_risk_s1 = ~|(W_rd ^ D_rs1) & (|W_rd) & |W_instr_type[5:0];
        assign Wdata_risk_s2 = ~|(W_rd ^ D_rs2) & (|W_rd)
                             & |W_instr_type[5:0] & (D_instr_type[7] | D_instr_type[6] | D_instr_type[0]);

        assign Mdata_risk_s1 = ~|(M_rd ^ D_rs1) & (|M_rd)
                             & |M_instr_type[5:0] & ~M_instr_type[3] & (D_instr_type[7] | D_instr_type[6] | D_instr_type[0]);
        assign Mdata_risk_s2 = ~|(M_rd ^ D_rs2) & (|M_rd)
                             & |M_instr_type[5:0] & ~M_instr_type[3] & (D_instr_type[7] | D_instr_type[6] | D_instr_type[0]);


        assign data_risk_s1 = Wdata_risk_s1 | Mdata_risk_s1;
        assign data_risk_s2 = Wdata_risk_s2 | Mdata_risk_s2;

        assign d_A = (rdata1 & {32{~data_risk_s1}})
                   | (m_MEMResult & {32{Mdata_risk_s1 & m_MemtoReg}})
                   | (M_EXResult & {32{Mdata_risk_s1 & ~m_MemtoReg}})
                   | (w_Result & {32{Wdata_risk_s1 & ~Mdata_risk_s1}});
        assign d_B = (rdata2 & {32{~data_risk_s2}})
                   | (m_MEMResult & {32{Mdata_risk_s2 & m_MemtoReg}})
                   | (M_EXResult & {32{Mdata_risk_s2 & ~m_MemtoReg}})
                   | (w_Result & {32{Wdata_risk_s2 & ~Mdata_risk_s2}});
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        EXRegister EXReg(
                .clk(clk),
                .rst(rst),
                .valid(d_valid),
                .ready(d_ready),
        
                .instr_valid(d_instr_valid),
                .E_instr_valid(E_instr_valid),

                .PC(D_PC),
                .recoverPC(D_recoverPC),
                .E_PC(E_PC),
                .E_recoverPC(E_recoverPC),

                .instr_type(D_instr_type),
                .funct3(D_funct3),
                .funct7(D_funct7),
                .E_instr_type(E_instr_type),
                .E_funct3(E_funct3),
                .E_funct7(E_funct7),

                .immediate32(D_immediate32),
                .shamt(D_shamt),
                .A(d_A),
                .B(d_B),
                .E_immediate32(E_immediate32),
                .E_shamt(E_shamt),
                .E_A(E_A),
                .E_B(E_B),

                .rd(D_rd),
                .E_rd(E_rd),

                .BranchTaken(D_BranchTaken),
                .E_BranchTaken(E_BranchTaken),

                .islui(D_islui),
                .E_islui(E_islui)
        );
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	///*Excution*///
        assign e_WriteData = E_B;

	assign e_isShift = ~E_funct3[1] & E_funct3[0] & (E_instr_type[0] | E_instr_type[1]);
        assign e_isjal = E_instr_type[5];
        assign e_isjalr = E_instr_type[2];
        
	/*Shifter*/
	assign e_Shiftop = {E_funct7[5],E_funct3[2]};         //00 is sll,01 is srl,11 is sra
	assign e_shifterA = E_A;
	assign e_shifterB = (E_B[4:0] & {5{~e_Shiftsrc}}) | (E_shamt & {5{e_Shiftsrc}});
	shifter Shifter(.A(e_shifterA),.B(e_shifterB),.Shiftop(e_Shiftop),.Result(e_shiftResult));

	/*ALU*/
	//the following two parts are completed in Decoder
	assign e_A = (E_A & {32{e_ALUsrcA}}) | (E_PC & {32{~e_ALUsrcA}});		
	assign e_B = (E_B & {32{e_ALUsrcB}}) | (E_immediate32 & {32{~e_ALUsrcB}});

	//select a proper operation
	
	alu ALU(.A(e_A),.B(e_B),.ALUop(e_ALUop),.CarryOut(CarryOut),.Overflow(Overflow),.Zero(Zero),.Result(e_aluResult));

	assign e_EXResult = (e_aluResult & {32{~E_islui & ~e_isShift & ~e_isjalr & ~e_isjal}}) 
		                | (e_shiftResult & {32{e_isShift}})
                                | (E_immediate32 & {32{E_islui}})
                                | ((E_PC + 32'b100) & {32{e_isjal | e_isjalr}});

	assign isbge = E_funct3[2] & ~E_funct3[1] & E_funct3[0];
        assign isbgeu = E_funct3[2] & E_funct3[1] & E_funct3[0];
        assign isbltu = E_funct3[2] & E_funct3[1] & ~E_funct3[0];
        assign isblt = E_funct3[2] & ~E_funct3[1] & ~E_funct3[0];
        assign isbeq = ~E_funct3[2] & ~E_funct3[1] & ~E_funct3[0];
        assign isbne = ~E_funct3[2] & ~E_funct3[1] & E_funct3[0];

	assign PCselect = ((isbeq | isbge | isbgeu) & Zero) | ((isbne | isblt | isbltu) & ~Zero);

        assign Wrong_Prediction = (E_BranchTaken ^ PCselect) & E_instr_type[6];

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        MEMRegister MEMReg(
                .clk(clk),
                .rst(rst),
                .valid(e_valid),
                .ready(e_ready),
        
                .instr_valid(e_instr_valid),
                .M_instr_valid(M_instr_valid),

                .PC(E_PC),
                .M_PC(M_PC),

                .instr_type(E_instr_type),
                .funct3(E_funct3),
                .funct7(E_funct7),
                .M_instr_type(M_instr_type),
                .M_funct3(M_funct3),
                .M_funct7(M_funct7),

                .EXResult(e_EXResult),
                .WriteData(e_WriteData),
                .M_EXResult(M_EXResult),
                .M_WriteData(M_WriteData),

                .rd(E_rd),
                .M_rd(M_rd)
        );
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ///*MEM*///
        assign Address = {M_EXResult[31:2],2'b0};
        assign MemRead = m_MemRead;
        assign MemWrite = m_MemWrite;

	storeData store(.offset(M_EXResult[1:0]),.funct3(M_funct3),.rtdata(M_WriteData),.Write_data(Write_data),.Write_strb(Write_strb));

	loadData load(.offset(M_EXResult[1:0]),.funct3(M_funct3),.Read_data(Read_data),.Load_data(m_MEMResult));

        
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //数据选择在WB完成？否则为WB增加寄存器没有意义
        WBRegister WBReg(
                .clk(clk),
                .rst(rst),
                .valid(m_valid),
                .ready(m_ready),
        
                .instr_valid(m_instr_valid),
                .W_instr_valid(W_instr_valid),

                .PC(M_PC),
                .W_PC(W_PC),

                .instr_type(M_instr_type),
                .funct3(M_funct3),
                .funct7(M_funct7),
                .W_instr_type(W_instr_type),
                .W_funct3(W_funct3),
                .W_funct7(W_funct7),

                .EXResult(M_EXResult),
                .MEMResult(m_MEMResult),
                .W_EXResult(W_EXResult),
                .W_MEMResult(W_MEMResult),

                .rd(M_rd),
                .W_rd(W_rd)
        );
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ///*WB*///
        assign memdatawrite = W_MEMResult & {32{w_MemtoReg}};
	assign exwrite = W_EXResult & {32{~w_MemtoReg}};
        assign w_Result = memdatawrite | exwrite;
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

        ///*Performance Counter*///
	//Runtime cycle count
	reg [31:0] cycle_cnt;
        always @(posedge clk)
        begin
                if(rst)
                        cycle_cnt <= 32'b0;
                else
                        cycle_cnt <= cycle_cnt + 32'b1;
        end
        assign cpu_perf_cnt_0 = cycle_cnt;
	//Instruction count
	reg [31:0] instr_cnt;
	always @(posedge clk)
	begin
		if(rst)
			instr_cnt <= 32'b0;
		else if(f_ready & f_valid)
			instr_cnt <= instr_cnt + 32'b1;
		else
			instr_cnt <= instr_cnt;
	end
	assign cpu_perf_cnt_1 = instr_cnt;
	//Instruction request cycle count
	reg [31:0] instr_req_cnt;
	always @(posedge clk)
	begin
		if(rst)
			instr_req_cnt <= 32'b0;
		else if(f_instr_valid)
			instr_req_cnt <= instr_req_cnt + 32'b1;
		else
			instr_req_cnt <= instr_req_cnt;
	end
	assign cpu_perf_cnt_2 = instr_req_cnt;
	//Instruction valid cycle count
	reg [31:0] instr_valid_cnt;
	always @(posedge clk)
	begin
		if(rst)
			instr_valid_cnt <= 32'b0;
		else if(f_instr_valid)
			instr_valid_cnt <= instr_valid_cnt + 32'b1;
		else
			instr_valid_cnt <= instr_valid_cnt;
	end
	assign cpu_perf_cnt_3 = instr_valid_cnt;
	//Memory request cycle count(store)
	reg [31:0] mems_req_cnt;
	always @(posedge clk)
	begin
		if(rst)
			mems_req_cnt <= 32'b0;
		else if(M_instr_type[7])
			mems_req_cnt <= mems_req_cnt + 32'b1;
		else
			mems_req_cnt <= mems_req_cnt;
	end
	assign cpu_perf_cnt_4 = mems_req_cnt;
	//Memory request cycle count(load)
	reg [31:0] meml_req_cnt;
	always @(posedge clk)
	begin
		if(rst)
			meml_req_cnt <= 32'b0;
		else if(M_instr_type[3])
			meml_req_cnt <= meml_req_cnt + 32'b1;
		else
			meml_req_cnt <= meml_req_cnt;
	end
	assign cpu_perf_cnt_5 = meml_req_cnt;
	//Memory valid cycle count
	reg [31:0] mem_valid_cnt;
	always @(posedge clk)
	begin
		if(rst)
			mem_valid_cnt <= 32'b0;
		else if(M_instr_type[3])
			mem_valid_cnt <= mem_valid_cnt + 32'b1;
		else
			mem_valid_cnt <= mem_valid_cnt;
	end
	assign cpu_perf_cnt_6 = mem_valid_cnt;
	//Jump count(J-type)
	reg [31:0] jump_cnt;
	always @(posedge clk)
	begin
		if(rst)
			jump_cnt <= 32'b0;
		else if(E_instr_type[2] | E_instr_type[5])
			jump_cnt <= jump_cnt + 32'b1;
		else
			jump_cnt <= jump_cnt;
	end
	assign cpu_perf_cnt_7 = jump_cnt;
	//Branch count
	reg [31:0] branch_cnt;
	always @(posedge clk)
	begin
		if(rst)
			branch_cnt <= 32'b0;
		else if(M_instr_type[6])
			branch_cnt <= branch_cnt + 32'b1;
		else
			branch_cnt <= branch_cnt;
	end
	assign cpu_perf_cnt_8 = branch_cnt;
        //Branch count(Falied)
        reg [31:0] wrongbranch_cnt;
        always @(posedge clk)
        begin
                if(rst)
                        wrongbranch_cnt <= 32'b0;
                else if(Wrong_Prediction & E_instr_type[6])
                        wrongbranch_cnt <= wrongbranch_cnt + 32'b1;
        end
        assign cpu_perf_cnt_9 = wrongbranch_cnt;

endmodule

module PC (
	input clk,
	input rst,
	input PCchange,
        input BranchTaken,
        input needjump,
        input Wrong_Prediction,
	input [31:0]addedPC,
        input [31:0]recoverPC,
        input [31:0]branchPC,
        input [31:0]jumpPC,
	output [31:0]PC
);
        reg [31:0]nextpc;
	always @(posedge clk)
	begin
		if(rst == 1'b1)
		begin
			nextpc <= 32'b0;
		end
                else if(needjump)
                begin
                        nextpc <= jumpPC;
                end
                else if(Wrong_Prediction)
                begin
                        nextpc <= recoverPC;
                end
		else if(PCchange & ~BranchTaken)
		begin
			nextpc <= addedPC;
		end
                else if(PCchange & BranchTaken)
                begin
                        nextpc <= branchPC;
                end
		else
			nextpc <= nextpc;
	end
        assign PC = (nextpc & {32{~needjump}}) | (jumpPC & {32{needjump & ~rst}});
endmodule