`timescale 10ns / 1ns

module PCAdder(
        input [31:0]PC,
        output [31:0]addedPC
);
        assign addedPC = PC + 32'b100;
endmodule

module BranchAdder (
        input [31:0]PC,
        input [31:0]immediate32,
        output [31:0]branchPC
);
        assign branchPC = PC + immediate32;
endmodule

module JumpAdder(
        input [31:0]immediate32,
        input [31:0]rdata,
        output [31:0]addedjumpPC
);
        assign addedjumpPC = immediate32 + rdata;
endmodule