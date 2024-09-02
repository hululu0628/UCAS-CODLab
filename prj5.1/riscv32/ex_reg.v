`timescale 10ns / 1ns

module EXRegister (
        input clk,
        input rst,
        input valid,
        input ready,
        
        input instr_valid,
        output reg E_instr_valid,

        input [31:0]PC,
        input [31:0]recoverPC,
        output reg [31:0]E_PC,
        output reg [31:0]E_recoverPC,

        input [7:0]instr_type,
        input [2:0]funct3,
        input [6:0]funct7,
        output [7:0]E_instr_type,
        output reg [2:0]E_funct3,
        output reg [6:0]E_funct7,

        input [31:0]immediate32,
        input [4:0]shamt,
        input [31:0]A,
        input [31:0]B,
        output reg [31:0]E_immediate32,
        output reg [4:0]E_shamt,
        output reg [31:0]E_A,
        output reg [31:0]E_B,

        input [4:0]rd,
        output reg [4:0]E_rd,

        input BranchTaken,
        output reg E_BranchTaken,

        input islui,
        output reg E_islui
);
        reg [7:0]Instr_Type;
        always @(posedge clk)
        begin
                if(rst)
                begin
                        E_instr_valid   <=      1'b0;
                end
                else if(ready)
                begin
                        E_instr_valid   <=      instr_valid;
                end
                if(valid & ready)
                begin
                        E_PC            <=      PC;
                        E_recoverPC     <=      recoverPC;
                        Instr_Type      <=      instr_type;
                        E_funct3        <=      funct3;
                        E_funct7        <=      funct7;
                        E_immediate32   <=      immediate32;
                        E_shamt         <=      shamt;
                        E_A             <=      A;
                        E_B             <=      B;
                        E_rd            <=      rd;
                        E_BranchTaken   <=      BranchTaken;
                        E_islui         <=      islui;
                end
        end
        assign E_instr_type = Instr_Type & {8{E_instr_valid}};
endmodule