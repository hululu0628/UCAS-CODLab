`timescale 10ns / 1ns

module WBRegister (
        input clk,
        input rst,
        input valid,
        input ready,
        
        input instr_valid,
        output reg W_instr_valid,

        input [31:0]PC,
        output reg [31:0]W_PC,

        input [7:0]instr_type,
        input [2:0]funct3,
        input [6:0]funct7,
        output [7:0]W_instr_type,
        output reg [2:0]W_funct3,
        output reg [6:0]W_funct7,

        input [31:0]EXResult,
        input [31:0]MEMResult,
        output reg [31:0]W_EXResult,
        output reg [31:0]W_MEMResult,

        input [4:0]rd,
        output reg [4:0]W_rd
);
        reg [7:0]Instr_Type;
        always @(posedge clk)
        begin
                if(rst)
                begin
                        W_instr_valid   <=      1'b0;
                end
                else if(ready)
                begin
                        W_instr_valid   <=      instr_valid;
                end
                if(valid & ready)
                begin
                        W_PC            <=      PC;
                        Instr_Type      <=      instr_type;
                        W_funct3        <=      funct3;
                        W_funct7        <=      funct7;
                        W_EXResult      <=      EXResult;
                        W_MEMResult     <=      MEMResult;
                        W_rd            <=      rd;
                end
        end
        assign W_instr_type = Instr_Type & {8{W_instr_valid}};
endmodule