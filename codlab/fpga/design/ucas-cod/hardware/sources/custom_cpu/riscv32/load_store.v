`timescale 10ns / 1ns

module loadData(
        input [1:0]offset,
	input [2:0]funct3,
	input [31:0]Read_data,
	output [31:0]Load_data
);
	wire [31:0]lb,lh,lw,lbu,lhu;

	//set lb,lh,lw...
        assign lb = {{24{(Read_data[7] & ~offset[1] & ~offset[0]) | (Read_data[15] & ~offset[1] & offset[0])
                        |(Read_data[23] & offset[1] & ~offset[0]) | (Read_data[31] & offset[1] & offset[0])}},
                     ((Read_data[7:0] & {8{~offset[1] & ~offset[0]}}) | (Read_data[15:8] & {8{~offset[1] & offset[0]}})
                     |(Read_data[23:16] & {8{offset[1] & ~offset[0]}}) | (Read_data[31:24] & {8{offset[1] & offset[0]}}))};
        assign lbu = {24'b0,
                      ((Read_data[7:0] & {8{~offset[1] & ~offset[0]}}) | (Read_data[15:8] & {8{~offset[1] & offset[0]}})
                     |(Read_data[23:16] & {8{offset[1] & ~offset[0]}}) | (Read_data[31:24] & {8{offset[1] & offset[0]}}))};
        assign lh = {({16{(Read_data[15] & ~offset[1]) | (Read_data[31] & offset[1])}}),
                     ((Read_data[15:0] & {16{~offset[1]}}) | (Read_data[31:16] & {16{offset[1]}}))};
        assign lhu = {16'b0,((Read_data[15:0] & {16{~offset[1]}}) | (Read_data[31:16] & {16{offset[1]}}))};
        assign lw = Read_data;
	//select the result
        assign Load_data = (lb & {32{~funct3[2] & ~funct3[1] & ~funct3[0]}})
                         | (lbu & {32{funct3[2] & ~funct3[0]}})
                         | (lh & {32{~funct3[2] & funct3[0]}})
                         | (lhu & {32{funct3[2] & funct3[0]}})
                         | (lw & {32{funct3[1]}});
endmodule

module storeData (
        input [1:0]offset,
	input [2:0]funct3,
	input [31:0]rtdata,
	output [31:0]Write_data,
	output [3:0]Write_strb
);
	wire sb,sh,sw;
        wire [31:0]sdata;


        assign sb = ~funct3[1] & ~funct3[0];
        assign sh = funct3[0];
        assign sw = funct3[1];

        assign Write_data = {((rtdata[31:24] & {8{sw}}) | (rtdata[15:8] & {8{sh}}) | (rtdata[7:0] & {8{sb}})),
                             ((rtdata[23:16] & {8{sw}}) | (rtdata[7:0] & {8{sb | sh}})),
                             ((rtdata[15:8] & {8{sw | sh}}) | (rtdata[7:0] & {8{sb}})),
                             (rtdata[7:0])};
        assign Write_strb = {(sw | (sh & offset[1]) | (sb & offset[1] & offset[0])),
                             (sw | (sh & offset[1]) | (sb & offset[1] & ~offset[0])),
                             (sw | (sh & ~offset[1]) | (sb & ~offset[1] & offset[0])),
                             (sw | (sh & ~offset[1]) | (sb & ~offset[1] & ~offset[0]))};

endmodule