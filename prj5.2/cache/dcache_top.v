`timescale 10ns / 1ns

`define CACHE_SET	8
`define CACHE_WAY	4
`define TAG_LEN		24
`define LINE_LEN	256

module dcache_top (
	input	      clk,
	input	      rst,
  
	//CPU interface
	/** CPU memory/IO access request to Cache: valid signal */
	input         from_cpu_mem_req_valid,
	/** CPU memory/IO access request to Cache: 0 for read; 1 for write (when req_valid is high) */
	input         from_cpu_mem_req,
	/** CPU memory/IO access request to Cache: address (4 byte alignment) */
	input  [31:0] from_cpu_mem_req_addr,
	/** CPU memory/IO access request to Cache: 32-bit write data */
	input  [31:0] from_cpu_mem_req_wdata,
	/** CPU memory/IO access request to Cache: 4-bit write strobe */
	input  [ 3:0] from_cpu_mem_req_wstrb,
	/** Acknowledgement from Cache: ready to receive CPU memory access request */
	output        to_cpu_mem_req_ready,
		
	/** Cache responses to CPU: valid signal */
	output        to_cpu_cache_rsp_valid,
	/** Cache responses to CPU: 32-bit read data */
	output [31:0] to_cpu_cache_rsp_data,
	/** Acknowledgement from CPU: Ready to receive read data */
	input         from_cpu_cache_rsp_ready,
		
	//Memory/IO read interface
	/** Cache sending memory/IO read request: valid signal */
	output        to_mem_rd_req_valid,
	/** Cache sending memory read request: address
	  * 4 byte alignment for I/O read 
	  * 32 byte alignment for cache read miss */
	output [31:0] to_mem_rd_req_addr,
        /** Cache sending memory read request: burst length
	  * 0 for I/O read (read only one data beat)
	  * 7 for cache read miss (read eight data beats) */
	output [ 7:0] to_mem_rd_req_len,
        /** Acknowledgement from memory: ready to receive memory read request */
	input	      from_mem_rd_req_ready,

	/** Memory return read data: valid signal of one data beat */
	input	      from_mem_rd_rsp_valid,
	/** Memory return read data: 32-bit one data beat */
	input  [31:0] from_mem_rd_rsp_data,
	/** Memory return read data: if current data beat is the last in this burst data transmission */
	input	      from_mem_rd_rsp_last,
	/** Acknowledgement from cache: ready to receive current data beat */
	output        to_mem_rd_rsp_ready,

	//Memory/IO write interface
	/** Cache sending memory/IO write request: valid signal */
	output        to_mem_wr_req_valid,
	/** Cache sending memory write request: address
	  * 4 byte alignment for I/O write 
	  * 4 byte alignment for cache write miss
          * 32 byte alignment for cache write-back */
	output [31:0] to_mem_wr_req_addr,
        /** Cache sending memory write request: burst length
          * 0 for I/O write (write only one data beat)
          * 0 for cache write miss (write only one data beat)
          * 7 for cache write-back (write eight data beats) */
	output [ 7:0] to_mem_wr_req_len,
        /** Acknowledgement from memory: ready to receive memory write request */
	input         from_mem_wr_req_ready,

	/** Cache sending memory/IO write data: valid signal for current data beat */
	output        to_mem_wr_data_valid,
	/** Cache sending memory/IO write data: current data beat */
	output [31:0] to_mem_wr_data,
	/** Cache sending memory/IO write data: write strobe
	  * 4'b1111 for cache write-back 
	  * other values for I/O write and cache write miss according to the original CPU request*/ 
	output [ 3:0] to_mem_wr_data_strb,
	/** Cache sending memory/IO write data: if current data beat is the last in this burst data transmission */
	output        to_mem_wr_data_last,
	/** Acknowledgement from memory/IO: ready to receive current data beat */
	input	      from_mem_wr_data_ready
);

  //TODO: Please add your D-Cache code here
        localparam      WAIT            = 17'b1,                                //0
                        BYPASS_LD       = 17'b10,                               //1
                        BYPASS_RDW      = 17'b100,                              //2
                        BYPASS_ST       = 17'b1000,                             //3
                        WRITE           = 17'b10000,                            //4
                        CACHE_WT        = 17'b100000,                           //5
                        READ            = 17'b1000000,                          //6
                        CACHE_RD        = 17'b10000000,                         //7
                        EVICT           = 17'b100000000,                        //8
                        MEM_RD          = 17'b1000000000,                       //9
                        RECV            = 17'b10000000000,                      //10
                        REFILL          = 17'b100000000000,                     //11
                        RESP            = 17'b1000000000000,                    //12
                        MEM_WT          = 17'b10000000000000,                   //13
                        MEM_RECV        = 17'b100000000000000,                  //14
                        BYPASS_MEMRECV  = 17'b1000000000000000,                 //15
                        INIT            = 17'b10000000000000000;                //16

        wire [23:0]tag;
        wire [2:0]index;
        wire [4:0]offset;

        wire isdirty;

        wire needbypass;

        wire [3:0]ways;
        wire hit;

        wire [23:0]tag_w1,tag_w2,tag_w3,tag_w4;
        wire [255:0]data_w1,data_w2,data_w3,data_w4;

        wire tag_wen_w1,tag_wen_w2,tag_wen_w3,tag_wen_w4;
        wire data_wen_w1,data_wen_w2,data_wen_w3,data_wen_w4;
        wire dirty_wen_w1,dirty_wen_w2,dirty_wen_w3,dirty_wen_w4;
        wire valid_w1,valid_w2,valid_w3,valid_w4;
        wire dirty_w1,dirty_w2,dirty_w3,dirty_w4;


        wire [31:0]wb_data_w1_0,wb_data_w1_1,wb_data_w1_2,wb_data_w1_3,wb_data_w1_4,wb_data_w1_5,wb_data_w1_6,wb_data_w1_7;
        wire [31:0]wb_data_w2_0,wb_data_w2_1,wb_data_w2_2,wb_data_w2_3,wb_data_w2_4,wb_data_w2_5,wb_data_w2_6,wb_data_w2_7;
        wire [31:0]wb_data_w3_0,wb_data_w3_1,wb_data_w3_2,wb_data_w3_3,wb_data_w3_4,wb_data_w3_5,wb_data_w3_6,wb_data_w3_7;
        wire [31:0]wb_data_w4_0,wb_data_w4_1,wb_data_w4_2,wb_data_w4_3,wb_data_w4_4,wb_data_w4_5,wb_data_w4_6,wb_data_w4_7;
        wire [255:0]wb_data_w1,wb_data_w2,wb_data_w3,wb_data_w4;


        reg [31:0]Address;
        reg [31:0]Write_data;
        reg [3:0]Write_strb;
        reg iswrite;
        reg [16:0]current_state;
        reg [31:0]to_mem_cpu_data;
        reg dirty;
        reg [1:0]rank;
        reg [3:0]Freq_array_s0[3:0];
        reg [3:0]Freq_array_s1[3:0];
        reg [3:0]Freq_array_s2[3:0];
        reg [3:0]Freq_array_s3[3:0];
        reg [3:0]Freq_array_s4[3:0];
        reg [3:0]Freq_array_s5[3:0];
        reg [3:0]Freq_array_s6[3:0];
        reg [3:0]Freq_array_s7[3:0];
        reg [7:0]len;
        reg [7:0]cnt1;
        reg [2:0]cnt2;
        reg [31:0]wr_address_reg;
        reg [255:0]to_mem_datablock;
        reg [255:0]cache_datablock;


        assign needbypass = (|from_cpu_mem_req_addr[31:30]) | ~(|from_cpu_mem_req_addr[31:5]);

        
        always @(posedge clk)
        begin
                if(rst)
                        Address <= 32'b0;
                else if(from_cpu_mem_req_valid & to_cpu_mem_req_ready)
                        Address <= from_cpu_mem_req_addr;
        end
        assign tag = Address[31:8];
        assign index = Address[7:5];
        assign offset = Address[4:0];

        
        always @(posedge clk)
        begin
                if(rst)
                        Write_data <= 32'b0;
                else if(from_cpu_mem_req_valid & to_cpu_mem_req_ready & from_cpu_mem_req)
                        Write_data <= from_cpu_mem_req_wdata;
        end

        
        always @(posedge clk)
        begin
                if(rst)
                        Write_strb <= 4'b0;
                else if(from_cpu_mem_req_valid & to_cpu_mem_req_ready)
                        Write_strb <= from_cpu_mem_req_wstrb;
        end

        
        always @(posedge clk)
        begin
                if(rst)
                        iswrite <= 1'b0;
                else if(current_state[0] & from_cpu_mem_req_valid & to_cpu_mem_req_ready)
                        iswrite <= from_cpu_mem_req;
        end

        
        always @(posedge clk)
        begin
                if(rst)
                        current_state <= INIT;
                else
                begin
                        case(current_state)
                        INIT:
                        begin
                                current_state <= WAIT;
                        end
                        WAIT:
                        begin
                                if(from_cpu_mem_req_valid & to_cpu_mem_req_ready & needbypass & from_cpu_mem_req)
                                        current_state <= BYPASS_ST;
                                else if(from_cpu_mem_req_valid & to_cpu_mem_req_ready & needbypass & ~from_cpu_mem_req)
                                        current_state <= BYPASS_LD;
                                else if(from_cpu_mem_req_valid & to_cpu_mem_req_ready & ~needbypass & from_cpu_mem_req)
                                        current_state <= WRITE;
                                else if(from_cpu_mem_req_valid & to_cpu_mem_req_ready & ~needbypass & ~from_cpu_mem_req)
                                        current_state <= READ;
                                else
                                        current_state <= WAIT;
                        end
                        BYPASS_LD:
                        begin
                                if(from_mem_rd_req_ready)
                                        current_state <= BYPASS_RDW;
                                else
                                        current_state <= BYPASS_LD;
                        end
                        BYPASS_RDW:
                        begin
                                if(from_mem_rd_rsp_valid)
                                        current_state <= WAIT;
                                else
                                        current_state <= BYPASS_RDW;
                        end
                        BYPASS_ST:
                        begin
                                if(from_mem_wr_req_ready)
                                        current_state <= BYPASS_MEMRECV;
                                else
                                        current_state <= BYPASS_ST;
                        end
                        WRITE:
                        begin
                                if(hit)
                                        current_state <= CACHE_WT;
                                else
                                        current_state <= EVICT;
                        end
                        CACHE_WT:
                        begin
                                current_state <= WAIT;
                        end
                        READ:
                        begin
                                if(hit)
                                        current_state <= CACHE_RD;
                                else
                                        current_state <= EVICT;
                        end
                        CACHE_RD:
                        begin
                                current_state <= RESP;
                        end
                        EVICT:
                        begin
                                current_state <= MEM_RD;
                        end
                        MEM_RD:
                        begin
                                if(from_mem_rd_req_ready)
                                        current_state <= RECV;
                                else
                                        current_state <= MEM_RD;
                        end
                        RECV:
                        begin
                                if(from_mem_rd_rsp_valid & from_mem_rd_rsp_last)
                                        current_state <= REFILL;
                                else
                                        current_state <= RECV;
                        end
                        REFILL:
                        begin
                                if(~dirty & iswrite)
                                        current_state <= WAIT;
                                else if(dirty & iswrite)
                                        current_state <= MEM_WT;
                                else if(~iswrite)
                                        current_state <= RESP;
                        end
                        RESP:
                        begin
                                if(from_cpu_cache_rsp_ready & dirty)
                                        current_state <= MEM_WT;
                                else if(from_cpu_cache_rsp_ready & ~dirty)
                                        current_state <= WAIT;
                                else
                                        current_state <= RESP;
                        end
                        MEM_WT:
                        begin
                                if(from_mem_wr_req_ready)
                                        current_state <= MEM_RECV;
                                else
                                        current_state <= MEM_WT;
                        end
                        MEM_RECV:
                        begin
                                if(from_mem_wr_data_ready & to_mem_wr_data_last)
                                        current_state <= WAIT;
                                else
                                        current_state <= MEM_RECV;
                        end
                        BYPASS_MEMRECV:
                        begin
                                if(from_mem_wr_data_ready & to_mem_wr_data_last)
                                        current_state <= WAIT;
                                else
                                        current_state <= BYPASS_MEMRECV;
                        end
                        default:
                        begin
                                current_state <= WAIT;
                        end
                endcase
                end
        end


        assign to_cpu_mem_req_ready = current_state[0];
        assign to_cpu_cache_rsp_valid = (current_state[2] & from_mem_rd_rsp_valid) | current_state[12];
        assign to_mem_rd_req_valid = current_state[1] | current_state[9];
        assign to_mem_rd_req_addr = (Address & {32{current_state[1]}}) | ({Address[31:5],5'b0} & {32{current_state[9]}});
        assign to_mem_rd_req_len = {5'b0,current_state[9],current_state[9],(current_state[9])};
        assign to_mem_rd_rsp_ready = current_state[10] | current_state[16] | current_state[0];
        assign to_mem_wr_req_valid = current_state[13] | current_state[3];
        assign to_mem_wr_req_addr = wr_address_reg;
        assign to_mem_wr_req_len = {5'b0,current_state[13],current_state[13],(current_state[13])};
        assign to_mem_wr_data_valid = current_state[14] | current_state[15];
        assign to_mem_wr_data = to_mem_datablock[31:0];
        assign to_mem_wr_data_strb = (Write_strb & {4{current_state[15]}}) | (4'b1111 & {4{current_state[14]}});
        assign to_mem_wr_data_last = ((~cnt1[3] & ~cnt1[2] & ~cnt1[1] & cnt1[0]) & from_mem_wr_data_ready) | current_state[16];


        assign tag_wen_w1 = current_state[11] & ~rank[1] & ~rank[0];
        assign tag_wen_w2 = current_state[11] & ~rank[1] & rank[0];
        assign tag_wen_w3 = current_state[11] & rank[1] & ~rank[0];
        assign tag_wen_w4 = current_state[11] & rank[1] & rank[0];

        assign data_wen_w1 = (current_state[5] | current_state[11]) & ~rank[1] & ~rank[0];
        assign data_wen_w2 = (current_state[5] | current_state[11]) & ~rank[1] & rank[0];
        assign data_wen_w3 = (current_state[5] | current_state[11]) & rank[1] & ~rank[0];
        assign data_wen_w4 = (current_state[5] | current_state[11]) & rank[1] & rank[0];

        assign dirty_wen_w1 = (current_state[5] | current_state[11]) & ~rank[1] & ~rank[0];
        assign dirty_wen_w2 = (current_state[5] | current_state[11]) & ~rank[1] & rank[0];
        assign dirty_wen_w3 = (current_state[5] | current_state[11]) & rank[1] & ~rank[0];
        assign dirty_wen_w4 = (current_state[5] | current_state[11]) & rank[1] & rank[0];

        assign isdirty = current_state[5] | (current_state[11] & iswrite);


        ///*BYPASS*///
        
        always @(posedge clk)
        begin
                if(current_state[0] & needbypass & ~rst)
                        to_mem_cpu_data <= from_cpu_mem_req_wdata;
        end



        dirty_array Dirty_w1(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(dirty_wen_w1),.wdata(isdirty),.rdata(dirty_w1));
        dirty_array Dirty_w2(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(dirty_wen_w2),.wdata(isdirty),.rdata(dirty_w2));
        dirty_array Dirty_w3(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(dirty_wen_w3),.wdata(isdirty),.rdata(dirty_w3));
        dirty_array Dirty_w4(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(dirty_wen_w4),.wdata(isdirty),.rdata(dirty_w4));

        tag_array Tag_w1(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(tag_wen_w1),.wdata(tag),.rdata(tag_w1),.vsignal(valid_w1));
        tag_array Tag_w2(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(tag_wen_w2),.wdata(tag),.rdata(tag_w2),.vsignal(valid_w2));
        tag_array Tag_w3(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(tag_wen_w3),.wdata(tag),.rdata(tag_w3),.vsignal(valid_w3));
        tag_array Tag_w4(.clk(clk),.rst(rst),.waddr(index),.raddr(index),.wen(tag_wen_w4),.wdata(tag),.rdata(tag_w4),.vsignal(valid_w4));

        data_array Data_w1(.clk(clk),.waddr(index),.raddr(index),.wen(data_wen_w1),.wdata(cache_datablock),.rdata(data_w1));
        data_array Data_w2(.clk(clk),.waddr(index),.raddr(index),.wen(data_wen_w2),.wdata(cache_datablock),.rdata(data_w2));
        data_array Data_w3(.clk(clk),.waddr(index),.raddr(index),.wen(data_wen_w3),.wdata(cache_datablock),.rdata(data_w3));
        data_array Data_w4(.clk(clk),.waddr(index),.raddr(index),.wen(data_wen_w4),.wdata(cache_datablock),.rdata(data_w4));

        assign ways = {(~|(tag ^ tag_w4) & valid_w4),(~|(tag ^ tag_w3) & valid_w3),(~|(tag ^ tag_w2) & valid_w2),(~|(tag ^ tag_w1) & valid_w1)};
        assign hit = |ways;
        
        
        always @(posedge clk)
        begin
                if(current_state[0])
                        dirty <= 1'b0;
                else if(current_state[8])
                begin
                        dirty <= (dirty_w1 & ~rank[1] & ~rank[0])
                              | (dirty_w2 & ~rank[1] & rank[0])
                              | (dirty_w3 & rank[1] & ~rank[0])
                              | (dirty_w4 & rank[1] & rank[0]);
                end
        end

        
        always @(posedge clk)
        begin
                if((current_state[4] | current_state[6]) & hit)
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
                else if((current_state[4] | current_state[6]) & ~hit)
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
                else if(current_state[5] | current_state[7] | current_state[8])
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
                else if(current_state[5] | current_state[7] | current_state[8])
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
                else if(current_state[5] | current_state[7] | current_state[8])
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
                else if(current_state[5] | current_state[7] | current_state[8])
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
                else if(current_state[5] | current_state[7] | current_state[8])
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
                else if(current_state[5] | current_state[7] | current_state[8])
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
                else if(current_state[5] | current_state[7] | current_state[8])
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
                else if(current_state[5] | current_state[7] | current_state[8])
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


        
        always @(posedge clk)
        begin
                if(rst)
                        len <= 8'b0;
                else if(current_state[8])
                        len <= 8'b111;
                else if(current_state[1] | current_state[3])
                        len <= 8'b0;
        end
        

        
        always @(posedge clk)
        begin
                if(rst)
                begin
                        cnt1 <= 8'b0;
                end
                else if(current_state[8])
                begin
                        cnt1 <= 8'b1000;
                end
                else if(current_state[3])
                begin
                        cnt1 <= 8'b1;
                end
                else if((current_state[15] | current_state[14]) & from_mem_wr_data_ready)
                begin
                        cnt1 <= cnt1 - 1;
                end
        end
        
        always @(posedge clk)
        begin
                if(rst)
                begin
                        cnt2 <= 3'b0;
                end
                else if(current_state[4])
                begin
                        cnt2 <= offset[4:2];
                end
                else if(current_state[10] & to_mem_rd_rsp_ready & from_mem_rd_rsp_valid)
                begin
                        cnt2 <= cnt2 -1;
                end
        end


        
        always @(posedge clk)
        begin
                if(current_state[0] & needbypass & ~rst)
                begin
                        wr_address_reg <= from_cpu_mem_req_addr;
                end
                else if(current_state[8])
                begin
                        case(rank)
                                2'b0:
                                begin
                                        wr_address_reg <= {tag_w1,index,5'b0};
                                end
                                2'b1:
                                begin
                                        wr_address_reg <= {tag_w2,index,5'b0};
                                end
                                2'b10:
                                begin
                                        wr_address_reg <= {tag_w3,index,5'b0};
                                end
                                2'b11:
                                begin
                                        wr_address_reg <= {tag_w4,index,5'b0};
                                end
                                default:
                                begin
                                        wr_address_reg <= wr_address_reg;
                                end
                        endcase
                end
        end

        
        always @(posedge clk)
        begin
                if(current_state[3])
                begin
                        to_mem_datablock[31:0] <= to_mem_cpu_data;
                end
                else if(current_state[8])
                begin
                        case(rank)
                                2'b0:
                                begin
                                        to_mem_datablock <= data_w1;
                                end
                                2'b1:
                                begin
                                        to_mem_datablock <= data_w2;
                                end
                                2'b10:
                                begin
                                        to_mem_datablock <= data_w3;
                                end
                                2'b11:
                                begin
                                        to_mem_datablock <= data_w4;
                                end
                                default:
                                begin
                                        to_mem_datablock <= to_mem_datablock;
                                end
                        endcase
                end
                else if(current_state[14] & from_mem_wr_data_ready & to_mem_wr_data_valid)
                begin
                        to_mem_datablock[223:192] <= to_mem_datablock[255:224];
                        to_mem_datablock[191:160] <= to_mem_datablock[223:192];
                        to_mem_datablock[159:128] <= to_mem_datablock[191:160];
                        to_mem_datablock[127:96] <= to_mem_datablock[159:128];
                        to_mem_datablock[95:64] <= to_mem_datablock[127:96];
                        to_mem_datablock[63:32] <= to_mem_datablock[95:64];
                        to_mem_datablock[31:0] <= to_mem_datablock[63:32];
                end
        end
        
        


        assign wb_data_w1_0 = (data_w1[31:0] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w1_1 = (data_w1[63:32] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w1_2 = (data_w1[95:64] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w1_3 = (data_w1[127:96] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w1_4 = (data_w1[159:128] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w1_5 = (data_w1[191:160] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w1_6 = (data_w1[223:192] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w1_7 = (data_w1[255:224] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});

        assign wb_data_w2_0 = (data_w2[31:0] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w2_1 = (data_w2[63:32] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w2_2 = (data_w2[95:64] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w2_3 = (data_w2[127:96] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w2_4 = (data_w2[159:128] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w2_5 = (data_w2[191:160] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w2_6 = (data_w2[223:192] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w2_7 = (data_w2[255:224] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});

        assign wb_data_w3_0 = (data_w3[31:0] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w3_1 = (data_w3[63:32] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w3_2 = (data_w3[95:64] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w3_3 = (data_w3[127:96] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w3_4 = (data_w3[159:128] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w3_5 = (data_w3[191:160] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w3_6 = (data_w3[223:192] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w3_7 = (data_w3[255:224] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});

        assign wb_data_w4_0 = (data_w4[31:0] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w4_1 = (data_w4[63:32] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w4_2 = (data_w4[95:64] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w4_3 = (data_w4[127:96] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w4_4 = (data_w4[159:128] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w4_5 = (data_w4[191:160] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w4_6 = (data_w4[223:192] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        assign wb_data_w4_7 = (data_w4[255:224] & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                            | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
        
        assign wb_data_w1 = ({data_w1[255:32],wb_data_w1_0} & {256{~offset[4] & ~offset[3] & ~offset[2]}})
                          | ({data_w1[255:64],wb_data_w1_1,data_w1[31:0]} & {256{~offset[4] & ~offset[3] & offset[2]}})
                          | ({data_w1[255:96],wb_data_w1_2,data_w1[63:0]} & {256{~offset[4] & offset[3] & ~offset[2]}})
                          | ({data_w1[255:128],wb_data_w1_3,data_w1[95:0]} & {256{~offset[4] & offset[3] & offset[2]}})
                          | ({data_w1[255:160],wb_data_w1_4,data_w1[127:0]} & {256{offset[4] & ~offset[3] & ~offset[2]}})
                          | ({data_w1[255:192],wb_data_w1_5,data_w1[159:0]} & {256{offset[4] & ~offset[3] & offset[2]}})
                          | ({data_w1[255:224],wb_data_w1_6,data_w1[191:0]} & {256{offset[4] & offset[3] & ~offset[2]}})
                          | ({wb_data_w1_7,data_w1[223:0]} & {256{offset[4] & offset[3] & offset[2]}});
        assign wb_data_w2 = ({data_w2[255:32],wb_data_w2_0} & {256{~offset[4] & ~offset[3] & ~offset[2]}})
                          | ({data_w2[255:64],wb_data_w2_1,data_w2[31:0]} & {256{~offset[4] & ~offset[3] & offset[2]}})
                          | ({data_w2[255:96],wb_data_w2_2,data_w2[63:0]} & {256{~offset[4] & offset[3] & ~offset[2]}})
                          | ({data_w2[255:128],wb_data_w2_3,data_w2[95:0]} & {256{~offset[4] & offset[3] & offset[2]}})
                          | ({data_w2[255:160],wb_data_w2_4,data_w2[127:0]} & {256{offset[4] & ~offset[3] & ~offset[2]}})
                          | ({data_w2[255:192],wb_data_w2_5,data_w2[159:0]} & {256{offset[4] & ~offset[3] & offset[2]}})
                          | ({data_w2[255:224],wb_data_w2_6,data_w2[191:0]} & {256{offset[4] & offset[3] & ~offset[2]}})
                          | ({wb_data_w2_7,data_w2[223:0]} & {256{offset[4] & offset[3] & offset[2]}});
        assign wb_data_w3 = ({data_w3[255:32],wb_data_w3_0} & {256{~offset[4] & ~offset[3] & ~offset[2]}})
                          | ({data_w3[255:64],wb_data_w3_1,data_w3[31:0]} & {256{~offset[4] & ~offset[3] & offset[2]}})
                          | ({data_w3[255:96],wb_data_w3_2,data_w3[63:0]} & {256{~offset[4] & offset[3] & ~offset[2]}})
                          | ({data_w3[255:128],wb_data_w3_3,data_w3[95:0]} & {256{~offset[4] & offset[3] & offset[2]}})
                          | ({data_w3[255:160],wb_data_w3_4,data_w3[127:0]} & {256{offset[4] & ~offset[3] & ~offset[2]}})
                          | ({data_w3[255:192],wb_data_w3_5,data_w3[159:0]} & {256{offset[4] & ~offset[3] & offset[2]}})
                          | ({data_w3[255:224],wb_data_w3_6,data_w3[191:0]} & {256{offset[4] & offset[3] & ~offset[2]}})
                          | ({wb_data_w3_7,data_w3[223:0]} & {256{offset[4] & offset[3] & offset[2]}});
        assign wb_data_w4 = ({data_w4[255:32],wb_data_w4_0} & {256{~offset[4] & ~offset[3] & ~offset[2]}})
                          | ({data_w4[255:64],wb_data_w4_1,data_w4[31:0]} & {256{~offset[4] & ~offset[3] & offset[2]}})
                          | ({data_w4[255:96],wb_data_w4_2,data_w4[63:0]} & {256{~offset[4] & offset[3] & ~offset[2]}})
                          | ({data_w4[255:128],wb_data_w4_3,data_w4[95:0]} & {256{~offset[4] & offset[3] & offset[2]}})
                          | ({data_w4[255:160],wb_data_w4_4,data_w4[127:0]} & {256{offset[4] & ~offset[3] & ~offset[2]}})
                          | ({data_w4[255:192],wb_data_w4_5,data_w4[159:0]} & {256{offset[4] & ~offset[3] & offset[2]}})
                          | ({data_w4[255:224],wb_data_w4_6,data_w4[191:0]} & {256{offset[4] & offset[3] & ~offset[2]}})
                          | ({wb_data_w4_7,data_w4[223:0]} & {256{offset[4] & offset[3] & offset[2]}});


        
        always @(posedge clk)
        begin
                if(current_state[4] & hit)
                begin
                        case(ways)
                                4'b1:
                                begin
                                        cache_datablock <= wb_data_w1;
                                end
                                4'b10:
                                begin
                                        cache_datablock <= wb_data_w2;
                                end
                                4'b100:
                                begin
                                        cache_datablock <= wb_data_w3;
                                end
                                4'b1000:
                                begin
                                        cache_datablock <= wb_data_w4;
                                end
                                default:
                                begin
                                        cache_datablock <= cache_datablock;
                                end
                        endcase
                end
                else if(current_state[7])
                begin
                        case(ways)
                        4'b1:
                                begin
                                        cache_datablock <= data_w1;
                                end
                                4'b10:
                                begin
                                        cache_datablock <= data_w2;
                                end
                                4'b100:
                                begin
                                        cache_datablock <= data_w3;
                                end
                                4'b1000:
                                begin
                                        cache_datablock <= data_w4;
                                end
                                default:
                                begin
                                        cache_datablock <= cache_datablock;
                                end        
                        endcase
                end
                else if(current_state[10] & to_mem_rd_rsp_ready & from_mem_rd_rsp_valid)
                begin
                        if(~(|cnt2) & iswrite)
                        begin
                                cache_datablock[255:224] <= 
                                        (from_mem_rd_rsp_data & {{8{~Write_strb[3]}},{8{~Write_strb[2]}},{8{~Write_strb[1]}},{8{~Write_strb[0]}}})
                                      | (Write_data & {{8{Write_strb[3]}},{8{Write_strb[2]}},{8{Write_strb[1]}},{8{Write_strb[0]}}});
                        end
                        else
                        begin
                                cache_datablock[255:224] <= from_mem_rd_rsp_data;
                        end
                        cache_datablock[223:192] <= cache_datablock[255:224];
                        cache_datablock[191:160] <= cache_datablock[223:192];
                        cache_datablock[159:128] <= cache_datablock[191:160];
                        cache_datablock[127:96] <= cache_datablock[159:128];
                        cache_datablock[95:64] <= cache_datablock[127:96];
                        cache_datablock[63:32] <= cache_datablock[95:64];
                        cache_datablock[31:0] <= cache_datablock[63:32];
                end
        end


        assign to_cpu_cache_rsp_data = ({32{to_cpu_cache_rsp_valid & current_state[12]}} &
                                      ((cache_datablock[31:0] & {32{~offset[4] & ~offset[3] & ~offset[2]}})
                                     | (cache_datablock[63:32] & {32{~offset[4] & ~offset[3] & offset[2]}})
                                     | (cache_datablock[95:64] & {32{~offset[4] & offset[3] & ~offset[2]}})
                                     | (cache_datablock[127:96] & {32{~offset[4] & offset[3] & offset[2]}})
                                     | (cache_datablock[159:128] & {32{offset[4] & ~offset[3] & ~offset[2]}})
                                     | (cache_datablock[191:160] & {32{offset[4] & ~offset[3] & offset[2]}})
                                     | (cache_datablock[223:192] & {32{offset[4] & offset[3] & ~offset[2]}})
                                     | (cache_datablock[255:224] & {32{offset[4] & offset[3] & offset[2]}})))
                                     | ({32{to_cpu_cache_rsp_valid & current_state[2]}} & from_mem_rd_rsp_data);

endmodule