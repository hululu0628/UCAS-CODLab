`timescale 10ns / 1ns
`define Addr_Width 9

//GHR和GC的恢复不够健壮
module Predictor(
        input clk,
        input rst,
        input needpredict,
        input Wrong_Prediction,
        input [31:0]PC,
        output BranchTaken
);
        wire [`Addr_Width - 1:0]addr;
        wire [1:0]add,sub;


        reg [`Addr_Width - 1:0]Global_History_Reg;
        always @(posedge clk)
        begin
                if(rst)
                        Global_History_Reg <= 9'b0;
                else if(needpredict)
                begin
                        Global_History_Reg <= {Global_History_Reg[7:0],BranchTaken};
                end
                else if(Wrong_Prediction)
                begin
                        Global_History_Reg[0] <= ~Global_History_Reg[0];        //不够健壮
                end
                else
                begin
                        Global_History_Reg <= Global_History_Reg;
                end
        end

        assign addr = PC[8:0] ^ Global_History_Reg;
        reg [8:0]addrReg;
        reg [1:0]recoverReg;
        always @(posedge clk)
        begin
                if(needpredict)
                begin
                        addrReg <= addr;                //不够健壮
                        recoverReg <= (add & {2{~BranchTaken}})
                                | (sub & {2{BranchTaken}});
                end
        end

        assign add = ((Gshare_Counts[addr] + 2'b1) | {2{&Gshare_Counts[addr]}});
        assign sub = ((Gshare_Counts[addr] + 2'b11) & {2{|Gshare_Counts[addr]}});

        reg [1:0]Gshare_Counts[511:0];
        integer i;
        always @(posedge clk)
        begin
                if(rst)
                begin
                        for (i=0;i<512;i=i+1)
                        begin
                                Gshare_Counts[i] = 2'b11;
                        end
                end
                else if(needpredict & BranchTaken)
                begin
                        Gshare_Counts[addr] <= add;
                end
                else if(needpredict & ~BranchTaken)
                begin
                        Gshare_Counts[addr] <= sub;
                end
                else if(Wrong_Prediction)
                begin
                        Gshare_Counts[addrReg] <= recoverReg;
                end
        end
        assign BranchTaken = Gshare_Counts[addr][1] & needpredict;
endmodule

module WrongPreSignalRegister(
        input clk,
        input rst,
        input wrong_instr,
        input flushed,
        output reg WrongPreReg,
        output NeedBubble
);
        always @(posedge clk)
        begin
                if(rst)
                        WrongPreReg <= 1'b0;
                else if(wrong_instr)
                        WrongPreReg <= 1'b1;
                else if(flushed)
                        WrongPreReg <= 1'b0;
        end
        assign NeedBubble = (WrongPreReg & ~flushed);
endmodule