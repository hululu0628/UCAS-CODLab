`timescale 10ns / 1ns

module IDRegister (
        input clk,
        input rst,
        input valid,
        input ready,
        
        input instr_valid,
        output reg D_instr_valid,

        input [31:0]PC,
        input [31:0]recoverPC,
        output reg [31:0]D_PC,
        output reg [31:0]D_recoverPC,

        input [7:0]instr_type,
        input [2:0]funct3,
        input [6:0]funct7,
        output [7:0]D_instr_type,
        output reg [2:0]D_funct3,
        output reg [6:0]D_funct7,

        input [31:0]immediate32,
        input [4:0]shamt,
        output reg [31:0]D_immediate32,
        output reg [4:0]D_shamt,

        input [4:0]rs1,
        input [4:0]rs2,
        input [4:0]rd,
        output reg [4:0]D_rs1,
        output reg [4:0]D_rs2,
        output reg [4:0]D_rd,

        input BranchTaken,
        output reg D_BranchTaken,

        input islui,
        output reg D_islui
);
        reg [7:0]Instr_Type;
        always @(posedge clk)
        begin
                if(rst)
                begin
                        D_instr_valid   <=      1'b0;
                end
                else if(ready)
                begin
                        D_instr_valid   <=      instr_valid;
                end
                if(valid & ready)
                begin
                        D_PC            <=      PC;
                        D_recoverPC     <=      recoverPC;
                        Instr_Type      <=      instr_type;
                        D_funct3        <=      funct3;
                        D_funct7        <=      funct7;
                        D_immediate32   <=      immediate32;
                        D_shamt         <=      shamt;
                        D_rs1           <=      rs1;
                        D_rs2           <=      rs2;
                        D_rd            <=      rd;
                        D_BranchTaken   <=      BranchTaken;
                        D_islui         <=      islui;
                end
        end
        assign D_instr_type = Instr_Type & {8{D_instr_valid}};
endmodule