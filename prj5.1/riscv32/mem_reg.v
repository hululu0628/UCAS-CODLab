`timescale 10ns / 1ns

module MEMRegister (
        input clk,
        input rst,
        input valid,
        input ready,
        
        input instr_valid,
        output reg M_instr_valid,

        input [31:0]PC,
        output reg [31:0]M_PC,

        input [7:0]instr_type,
        input [2:0]funct3,
        input [6:0]funct7,
        output [7:0]M_instr_type,
        output reg [2:0]M_funct3,
        output reg [6:0]M_funct7,

        input [31:0]EXResult,
        input [31:0]WriteData,
        output reg [31:0]M_EXResult,
        output reg [31:0]M_WriteData,

        input [4:0]rd,
        output reg [4:0]M_rd
);
        reg [7:0]Instr_Type;
        always @(posedge clk)
        begin
                if(rst)
                begin
                        M_instr_valid   <=      1'b0;
                end
                else if(ready)
                begin
                        M_instr_valid   <=      instr_valid;
                end
                if(valid & ready)
                begin
                        M_PC            <=      PC;
                        Instr_Type      <=      instr_type;
                        M_funct3        <=      funct3;
                        M_funct7        <=      funct7;
                        M_EXResult      <=      EXResult;
                        M_WriteData     <=      WriteData;
                        M_rd            <=      rd;
                end
        end
        assign M_instr_type = Instr_Type & {8{M_instr_valid}};
endmodule