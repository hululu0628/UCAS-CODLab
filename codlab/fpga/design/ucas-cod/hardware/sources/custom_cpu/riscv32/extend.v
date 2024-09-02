`timescale 10ns / 1ns

module Extend(
        input [31:0]inst,
        input [2:0]Extype,
        output [31:0]immediate32
);
        wire [31:0]immI,immU,immB,immS,immJ;
        wire isIimm,isSimm,isBimm,isUimm,isJimm;
        
        assign immI = {{21{inst[31]}},inst[30:25],inst[24:21],inst[20]};
        assign immS = {{21{inst[31]}},inst[30:25],inst[11:8],inst[7]};
        assign immB = {{19{inst[31]}},{2{inst[7]}},inst[30:25],inst[11:8],1'b0};
        assign immU = {inst[31],inst[30:20],inst[19:12],12'b0};
        assign immJ = {{12{inst[31]}},inst[19:12],inst[20],inst[30:25],inst[24:21],1'b0};
        
        assign isIimm = ~(|Extype);
        assign isSimm = ~Extype[1] & Extype[0];
        assign isBimm = Extype[1] & ~Extype[0];
        assign isUimm = Extype[2] & ~Extype[0];
        assign isJimm = Extype[1] & Extype[0];

        assign immediate32 = (immI & {32{isIimm}})
                           | (immS & {32{isSimm}})
                           | (immB & {32{isBimm}})
                           | (immU & {32{isUimm}})
                           | (immJ & {32{isJimm}});
endmodule