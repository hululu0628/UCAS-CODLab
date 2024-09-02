`timescale 10ns / 1ns

`define CACHE_SET	8
`define CACHE_WAY	4
`define TAG_LEN		24
`define LINE_LEN	256

module icache_top (
	input	      clk,
	input	      rst,
	
	//CPU interface
	/** CPU instruction fetch request to Cache: valid signal */
	input         from_cpu_inst_req_valid,
	/** CPU instruction fetch request to Cache: address (4 byte alignment) */
	input  [31:0] from_cpu_inst_req_addr,
	/** Acknowledgement from Cache: ready to receive CPU instruction fetch request */
	output        to_cpu_inst_req_ready,
	
	/** Cache responses to CPU: valid signal */
	output        to_cpu_cache_rsp_valid,
	/** Cache responses to CPU: 32-bit Instruction value */
	output [31:0] to_cpu_cache_rsp_data,
	/** Acknowledgement from CPU: Ready to receive Instruction */
	input	      from_cpu_cache_rsp_ready,

	//Memory interface (32 byte aligned address)
	/** Cache sending memory read request: valid signal */
	output        to_mem_rd_req_valid,
	/** Cache sending memory read request: address (32 byte alignment) */
	output [31:0] to_mem_rd_req_addr,
	/** Acknowledgement from memory: ready to receive memory read request */
	input         from_mem_rd_req_ready,

	/** Memory return read data: valid signal of one data beat */
	input         from_mem_rd_rsp_valid,
	/** Memory return read data: 32-bit one data beat */
	input  [31:0] from_mem_rd_rsp_data,
	/** Memory return read data: if current data beat is the last in this burst data transmission */
	input         from_mem_rd_rsp_last,
	/** Acknowledgement from cache: ready to receive current data beat */
	output        to_mem_rd_rsp_ready
);

//TODO: Please add your I-Cache code here
        localparam      WAIT            = 8'b00000001,  //0
                        TAG_RD          = 8'b00000010,  //1
                        CACHE_RD        = 8'b00000100,  //2
                        EVICT           = 8'b00001000,  //3
                        MEM_RD          = 8'b00010000,  //4
                        RECV            = 8'b00100000,  //5
                        REFILL          = 8'b01000000,  //6
                        RESP            = 8'b10000000;  //7

        wire [23:0]tag;
        wire [2:0]index;
        wire [4:0]offset;

        wire [3:0]ways;
        wire hit;

        wire [23:0]tag_w1,tag_w2,tag_w3,tag_w4;
        wire [255:0]data_w1,data_w2,data_w3,data_w4;

        wire tag_wen_w1,tag_wen_w2,tag_wen_w3,tag_wen_w4;
        wire data_wen_w1,data_wen_w2,data_wen_w3,data_wen_w4;
        wire valid_w1,valid_w2,valid_w3,valid_w4;

        reg [31:0]Address;
        always @(posedge clk)
        begin
                if(rst)
                        Address <= 32'b0;
                else if(from_cpu_inst_req_valid & to_cpu_inst_req_ready)
                        Address <= from_cpu_inst_req_addr;
        end
        assign tag = Address[31:8];
        assign index = Address[7:5];
        assign offset = Address[4:0];


        reg [7:0]current_state;
        always @(posedge clk)
        begin
                if(rst == 1'b1)
                        current_state <= WAIT;
                else
                        current_state <= next_state;
        end
        reg [7:0]next_state;
        always @(*)
        begin
                case (current_state)
                        WAIT:
                        begin
                                if(from_cpu_inst_req_valid & to_cpu_inst_req_ready)
                                        next_state = TAG_RD;
                                else
                                        next_state = WAIT;
                        end
                        TAG_RD:
                        begin
                                if(hit)
                                        next_state = CACHE_RD;
                                else
                                        next_state = EVICT;
                        end
                        CACHE_RD:
                        begin
                                next_state = RESP;
                        end
                        EVICT:
                        begin
                                next_state = MEM_RD;
                        end
                        MEM_RD:
                        begin
                                if(from_mem_rd_req_ready)
                                        next_state = RECV;
                                else
                                        next_state = MEM_RD;
                        end
                        RECV:
                        begin
                                if(from_mem_rd_rsp_valid & from_mem_rd_rsp_last)
                                        next_state = REFILL;
                                else
                                        next_state = RECV;
                        end
                        REFILL:
                        begin
                                next_state = RESP;
                        end
                        RESP:
                        begin
                                if(from_cpu_cache_rsp_ready)
                                        next_state = WAIT;
                                else
                                        next_state = RESP;
                        end
                        default:
                        begin
                                next_state = WAIT;
                        end
                endcase
        end

        assign to_cpu_inst_req_ready = current_state[0] & ~rst;
        assign to_mem_rd_req_valid = current_state[4];
        assign to_mem_rd_rsp_ready = current_state[5];
        assign to_cpu_cache_rsp_valid = current_state[7];


        tag_array Tag_w1(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(tag_wen_w1),.wdata(tag),.rdata(tag_w1),.vsignal(valid_w1));
        tag_array Tag_w2(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(tag_wen_w2),.wdata(tag),.rdata(tag_w2),.vsignal(valid_w2));
        tag_array Tag_w3(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(tag_wen_w3),.wdata(tag),.rdata(tag_w3),.vsignal(valid_w3));
        tag_array Tag_w4(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(tag_wen_w4),.wdata(tag),.rdata(tag_w4),.vsignal(valid_w4));

        data_array Data_w1(.clk(clk),.waddr(index),.raddr(index),.wen(data_wen_w1),.wdata(to_cpu_datablock),.rdata(data_w1));
        data_array Data_w2(.clk(clk),.waddr(index),.raddr(index),.wen(data_wen_w2),.wdata(to_cpu_datablock),.rdata(data_w2));
        data_array Data_w3(.clk(clk),.waddr(index),.raddr(index),.wen(data_wen_w3),.wdata(to_cpu_datablock),.rdata(data_w3));
        data_array Data_w4(.clk(clk),.waddr(index),.raddr(index),.wen(data_wen_w4),.wdata(to_cpu_datablock),.rdata(data_w4));

        assign ways = {(~|(tag ^ tag_w4) & valid_w4),(~|(tag ^ tag_w3) & valid_w3),(~|(tag ^ tag_w2) & valid_w2),(~|(tag ^ tag_w1) & valid_w1)};
        assign hit = |ways;


        reg [3:0]Freq_array_s0[3:0];
        reg [3:0]Freq_array_s1[3:0];
        reg [3:0]Freq_array_s2[3:0];
        reg [3:0]Freq_array_s3[3:0];
        reg [3:0]Freq_array_s4[3:0];
        reg [3:0]Freq_array_s5[3:0];
        reg [3:0]Freq_array_s6[3:0];
        reg [3:0]Freq_array_s7[3:0];
        integer j;
        always @(posedge clk)
        begin
                if(rst)
                begin
                        for(j=0;j<4;j=j+1)
                        begin
                                Freq_array_s0[j] <= 4'b0;
                        end
                end
                else if(current_state[2] | current_state[3])
                begin
                        if(index==3'b0)
                        begin
                                Freq_array_s0[rank] <= 4'b1111;
                                for(j=0;j<4;j=j+1)
                                begin
                                        Freq_array_s0[j][rank] <= 1'b0;
                                end
                        end
                end
        end
        always @(posedge clk)
        begin
                if(rst)
                begin
                        for(j=0;j<4;j=j+1)
                        begin
                                Freq_array_s1[j] <= 4'b0;
                        end
                end
                else if(current_state[2] | current_state[3])
                begin
                        if(index==3'b1)
                        begin
                                Freq_array_s1[rank] <= 4'b1111;
                                for(j=0;j<4;j=j+1)
                                begin
                                        Freq_array_s1[j][rank] <= 1'b0;
                                end
                        end
                end
        end
        always @(posedge clk)
        begin
                if(rst)
                begin
                        for(j=0;j<4;j=j+1)
                        begin
                                Freq_array_s2[j] <= 4'b0;
                        end
                end
                else if(current_state[2] | current_state[3])
                begin
                        if(index==3'b10)
                        begin
                                Freq_array_s2[rank] <= 4'b1111;
                                for(j=0;j<4;j=j+1)
                                begin
                                        Freq_array_s2[j][rank] <= 1'b0;
                                end
                        end
                end
        end
        always @(posedge clk)
        begin
                if(rst)
                begin
                        for(j=0;j<4;j=j+1)
                        begin
                                Freq_array_s3[j] <= 4'b0;
                        end
                end
                else if(current_state[2] | current_state[3])
                begin
                        if(index==3'b11)
                        begin
                                Freq_array_s3[rank] <= 4'b1111;
                                for(j=0;j<4;j=j+1)
                                begin
                                        Freq_array_s3[j][rank] <= 1'b0;
                                end
                        end
                end
        end
        always @(posedge clk)
        begin
                if(rst)
                begin
                        for(j=0;j<4;j=j+1)
                        begin
                                Freq_array_s4[j] <= 4'b0;
                        end
                end
                else if(current_state[2] | current_state[3])
                begin
                        if(index==3'b100)
                        begin
                                Freq_array_s4[rank] <= 4'b1111;
                                for(j=0;j<4;j=j+1)
                                begin
                                        Freq_array_s4[j][rank] <= 1'b0;
                                end
                        end
                end
        end
        always @(posedge clk)
        begin
                if(rst)
                begin
                        for(j=0;j<4;j=j+1)
                        begin
                                Freq_array_s5[j] <= 4'b0;
                        end
                end
                else if(current_state[2] | current_state[3])
                begin
                        if(index==3'b101)
                        begin
                                Freq_array_s5[rank] <= 4'b1111;
                                for(j=0;j<4;j=j+1)
                                begin
                                        Freq_array_s5[j][rank] <= 1'b0;
                                end
                        end
                end
        end
        always @(posedge clk)
        begin
                if(rst)
                begin
                        for(j=0;j<4;j=j+1)
                        begin
                                Freq_array_s6[j] <= 4'b0;
                        end
                end
                else if(current_state[2] | current_state[3])
                begin
                        if(index==3'b110)
                        begin
                                Freq_array_s6[rank] <= 4'b1111;
                                for(j=0;j<4;j=j+1)
                                begin
                                        Freq_array_s6[j][rank] <= 1'b0;
                                end
                        end
                end
        end
        always @(posedge clk)
        begin
                if(rst)
                begin
                        for(j=0;j<4;j=j+1)
                        begin
                                Freq_array_s7[j] <= 4'b0;
                        end
                end
                else if(current_state[2] | current_state[3])
                begin
                        if(index==3'b111)
                        begin
                                Freq_array_s7[rank] <= 4'b1111;
                                for(j=0;j<4;j=j+1)
                                begin
                                        Freq_array_s7[j][rank] <= 1'b0;
                                end
                        end
                end
        end


        reg [1:0]rank;
        always @(posedge clk)
        begin
                if(current_state[1] & hit)
                begin
                        case(ways)
                                4'b1:
                                begin
                                        rank <= 2'b0;
                                end
                                4'b10:
                                begin
                                        rank <= 2'b1;
                                end
                                4'b100:
                                begin
                                        rank <= 2'b10;
                                end
                                4'b1000:
                                begin
                                        rank <= 2'b11;
                                end
                                default:
                                begin
                                        rank <= rank;
                                end
                        endcase
                end
                else if(current_state[1] & ~hit)
                begin
                        case(index)
                                3'b0:
                                begin
                                        if(Freq_array_s0[0]==4'b0)
                                                rank <= 2'b0;
                                        else if(Freq_array_s0[1]==4'b0)
                                                rank <= 2'b1;
                                        else if(Freq_array_s0[2]==4'b0)
                                                rank <= 2'b10;
                                        else if(Freq_array_s0[3]==4'b0)
                                                rank <= 2'b11;
                                end
                                3'b1:
                                begin
                                        if(Freq_array_s1[0]==4'b0)
                                                rank <= 2'b0;
                                        else if(Freq_array_s1[1]==4'b0)
                                                rank <= 2'b1;
                                        else if(Freq_array_s1[2]==4'b0)
                                                rank <= 2'b10;
                                        else if(Freq_array_s1[3]==4'b0)
                                                rank <= 2'b11;
                                end
                                3'b10:
                                begin
                                        if(Freq_array_s2[0]==4'b0)
                                                rank <= 2'b0;
                                        else if(Freq_array_s2[1]==4'b0)
                                                rank <= 2'b1;
                                        else if(Freq_array_s2[2]==4'b0)
                                                rank <= 2'b10;
                                        else if(Freq_array_s2[3]==4'b0)
                                                rank <= 2'b11;
                                end
                                3'b11:
                                begin
                                        if(Freq_array_s3[0]==4'b0)
                                                rank <= 2'b0;
                                        else if(Freq_array_s3[1]==4'b0)
                                                rank <= 2'b1;
                                        else if(Freq_array_s3[2]==4'b0)
                                                rank <= 2'b10;
                                        else if(Freq_array_s3[3]==4'b0)
                                                rank <= 2'b11;
                                end
                                3'b100:
                                begin
                                        if(Freq_array_s4[0]==4'b0)
                                                rank <= 2'b0;
                                        else if(Freq_array_s4[1]==4'b0)
                                                rank <= 2'b1;
                                        else if(Freq_array_s4[2]==4'b0)
                                                rank <= 2'b10;
                                        else if(Freq_array_s4[3]==4'b0)
                                                rank <= 2'b11;
                                end
                                3'b101:
                                begin
                                        if(Freq_array_s5[0]==4'b0)
                                                rank <= 2'b0;
                                        else if(Freq_array_s5[1]==4'b0)
                                                rank <= 2'b1;
                                        else if(Freq_array_s5[2]==4'b0)
                                                rank <= 2'b10;
                                        else if(Freq_array_s5[3]==4'b0)
                                                rank <= 2'b11;
                                end
                                3'b110:
                                begin
                                        if(Freq_array_s6[0]==4'b0)
                                                rank <= 2'b0;
                                        else if(Freq_array_s6[1]==4'b0)
                                                rank <= 2'b1;
                                        else if(Freq_array_s6[2]==4'b0)
                                                rank <= 2'b10;
                                        else if(Freq_array_s6[3]==4'b0)
                                                rank <= 2'b11;
                                end
                                3'b111:
                                begin
                                        if(Freq_array_s7[0]==4'b0)
                                                rank <= 2'b0;
                                        else if(Freq_array_s7[1]==4'b0)
                                                rank <= 2'b1;
                                        else if(Freq_array_s7[2]==4'b0)
                                                rank <= 2'b10;
                                        else if(Freq_array_s7[3]==4'b0)
                                                rank <= 2'b11;
                                end
                                default:
                                begin
                                rank <= rank; 
                                end
                        endcase
                end
        end



        assign to_mem_rd_req_addr = {Address[31:5],5'b0};
        assign to_mem_rd_req_valid = current_state[4];
        assign to_mem_rd_rsp_ready = current_state[5];


        reg [`LINE_LEN-1:0]to_cpu_datablock;
        always @(posedge clk)
        begin
                if(current_state[2])
                begin
                        case(ways)
                                4'b1:
                                begin
                                        to_cpu_datablock <= data_w1;
                                end
                                4'b10:
                                begin
                                        to_cpu_datablock <= data_w2;
                                end
                                4'b100:
                                begin
                                        to_cpu_datablock <= data_w3;
                                end
                                4'b1000:
                                begin
                                        to_cpu_datablock <= data_w4;
                                end
                                default:
                                begin
                                        to_cpu_datablock <= to_cpu_datablock;
                                end
                        endcase
                end
                else if(current_state[5] & to_mem_rd_rsp_ready & from_mem_rd_rsp_valid)
                begin
                        to_cpu_datablock[255:224] <= from_mem_rd_rsp_data;
                        to_cpu_datablock[223:192] <= to_cpu_datablock[255:224];
                        to_cpu_datablock[191:160] <= to_cpu_datablock[223:192];
                        to_cpu_datablock[159:128] <= to_cpu_datablock[191:160];
                        to_cpu_datablock[127:96] <= to_cpu_datablock[159:128];
                        to_cpu_datablock[95:64] <= to_cpu_datablock[127:96];
                        to_cpu_datablock[63:32] <= to_cpu_datablock[95:64];
                        to_cpu_datablock[31:0] <= to_cpu_datablock[63:32];
                end
        end

        assign tag_wen_w1 = current_state[6] & ~rank[1] & ~rank[0];
        assign tag_wen_w2 = current_state[6] & ~rank[1] & rank[0];
        assign tag_wen_w3 = current_state[6] & rank[1] & ~rank[0];
        assign tag_wen_w4 = current_state[6] & rank[1] & rank[0];

        assign data_wen_w1 = tag_wen_w1;
        assign data_wen_w2 = tag_wen_w2;
        assign data_wen_w3 = tag_wen_w3;
        assign data_wen_w4 = tag_wen_w4;

        assign to_cpu_cache_rsp_valid = current_state[7];

        assign to_cpu_cache_rsp_data = {32{to_cpu_cache_rsp_valid}} 
                                     &((to_cpu_datablock[31:0] & {32{~offset[4] & ~offset[3] & ~offset[2]}})
                                     | (to_cpu_datablock[63:32] & {32{~offset[4] & ~offset[3] & offset[2]}})
                                     | (to_cpu_datablock[95:64] & {32{~offset[4] & offset[3] & ~offset[2]}})
                                     | (to_cpu_datablock[127:96] & {32{~offset[4] & offset[3] & offset[2]}})
                                     | (to_cpu_datablock[159:128] & {32{offset[4] & ~offset[3] & ~offset[2]}})
                                     | (to_cpu_datablock[191:160] & {32{offset[4] & ~offset[3] & offset[2]}})
                                     | (to_cpu_datablock[223:192] & {32{offset[4] & offset[3] & ~offset[2]}})
                                     | (to_cpu_datablock[255:224] & {32{offset[4] & offset[3] & offset[2]}}));

        
endmodule

