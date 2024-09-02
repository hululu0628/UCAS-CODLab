`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Xu Zhang (zhangxu415@mails.ucas.ac.cn)
// 
// Create Date: 06/14/2018 11:39:09 AM
// Design Name: 
// Module Name: dma_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module engine_core #(
	parameter integer  DATA_WIDTH       = 32
)
(
	input    clk,
	input    rst,
	
	output reg [31:0]       src_base,
	output reg [31:0]       dest_base,
	output reg [31:0]       tail_ptr,
	output reg [31:0]       head_ptr,
	output reg [31:0]       dma_size,
	output reg [31:0]       ctrl_stat,

	input  [31:0]	    reg_wr_data,
	input  [ 5:0]       reg_wr_en,
  
	output              intr,
  
	output [31:0]       rd_req_addr,
	output [ 4:0]       rd_req_len,
	output              rd_req_valid,
	
	input               rd_req_ready,
	input  [31:0]       rd_rdata,
	input               rd_last,
	input               rd_valid,
	output              rd_ready,
	
	output [31:0]       wr_req_addr,
	output [ 4:0]       wr_req_len,
	output              wr_req_valid,
	input               wr_req_ready,
	output [31:0]       wr_data,
	output              wr_valid,
	input               wr_ready,
	output              wr_last,
	
	output              fifo_rden,
	output [31:0]       fifo_wdata,
	output              fifo_wen,
	
	input  [31:0]       fifo_rdata,
	input               fifo_is_empty,
	input               fifo_is_full
);
	// TODO: Please add your logic design here

        localparam      IDLE    = 4'b0001,
                        REQ     = 4'b0010,
                        RW      = 4'b0100,
                        FIFO    = 4'b1000;

	reg [3:0] rd_current_state;
	reg [3:0] rd_next_state;
	reg [3:0] wr_current_state;
	reg [3:0] wr_next_state;

        reg [31:0] fifodata;

	reg [31:0] rd_cnt;
	reg [31:0] wr_cnt;
	reg [31:0] wdata_counter;


	wire [2:0] last_burst;
	wire [31:0] total_burst_num;
	wire rd_burst_finish;
	wire wr_burst_finish;

	wire equal;

	assign equal = head_ptr == tail_ptr;

	assign last_burst = dma_size[4:2] + |dma_size[1:0];
	assign total_burst_num = {5'b0, dma_size[31:5]} + |dma_size[4:0];
	assign rd_burst_finish = (rd_cnt == total_burst_num);
	assign wr_burst_finish = (wr_cnt == total_burst_num);

        /*RD ENG*/
	always @ (posedge clk)
        begin
		if (rst)
                        rd_current_state <= IDLE;
		else
                        rd_current_state <= rd_next_state;
	end

	always @ (*)
        begin
		case (rd_current_state)
			IDLE:
                        begin
				if (ctrl_stat[0] & wr_current_state[0] & ~equal & ~rd_burst_finish& & fifo_is_empty)
					rd_next_state = REQ;
				else
                                        rd_next_state = IDLE;
			end
			REQ:
                        begin
				if (rd_burst_finish)
                                        rd_next_state = IDLE;
				else if(rd_req_ready)
                                        rd_next_state = RW;
				else
                                        rd_next_state = REQ;
			end
			RW:
                        begin
				if (rd_valid & rd_last & ~fifo_is_full)
                                        rd_next_state = REQ;
				else
                                        rd_next_state = RW;
			end
			default:
                                rd_next_state = IDLE;
		endcase
	end

        /*WR ENG*/
        always @ (posedge clk)
        begin
		if (rst)
                        wr_current_state <= IDLE;
		else
                        wr_current_state <= wr_next_state;
	end

	always @ (*)
        begin
		case (wr_current_state)
			IDLE:
                        begin
				if (ctrl_stat[0] & ~equal & ~wr_burst_finish & (wr_cnt < rd_cnt))
					wr_next_state = REQ;
				else
                                        wr_next_state = IDLE;
			end
			REQ:
                        begin
				if (wr_burst_finish)
                                        wr_next_state = IDLE;
				else if(wr_req_ready & (wr_cnt < rd_cnt))
                                        wr_next_state = FIFO;
				else
                                        wr_next_state = REQ;
			end
			FIFO:
                        begin
				wr_next_state = RW;
			end
			RW:
                        begin
				if (wr_ready & wr_last)
                                        wr_next_state = REQ;
				else if (wr_ready & ~fifo_is_empty)
                                        wr_next_state = FIFO;
				else
                                        wr_next_state = RW;
			end
			default:
                                wr_next_state = IDLE;
		endcase
	end


        /*控制寄存器*/
        always @ (posedge clk)
        begin
		if (reg_wr_en[0])
                        src_base <= reg_wr_data;
	end
	always @ (posedge clk)
        begin
		if (reg_wr_en[1])
                        dest_base <= reg_wr_data;
	end
	always @ (posedge clk)
        begin
		if (reg_wr_en[2])
                        tail_ptr <= reg_wr_data;
		else if (rd_burst_finish & wr_burst_finish & rd_current_state[0] & wr_current_state[0])
			tail_ptr <= tail_ptr + dma_size;
	end
	always @ (posedge clk)
        begin
		if (reg_wr_en[3])
                        head_ptr <= reg_wr_data;
	end
	always @ (posedge clk)
        begin
		if (reg_wr_en[4])
                        dma_size <= reg_wr_data;
	end
	always @ (posedge clk)
        begin
		if (reg_wr_en[5])
                        ctrl_stat <= reg_wr_data;
		else if (ctrl_stat[0] & rd_burst_finish & wr_burst_finish & rd_current_state[0] & wr_current_state[0])
			ctrl_stat[31] = 1'b1;
	end



        /*记录一次DMA引擎启动过程中突发读的次数*/
	always @ (posedge clk)
        begin
		if (rst | rd_current_state[0] & wr_current_state[0] & ctrl_stat[0] & ~equal & rd_burst_finish & wr_burst_finish)
			rd_cnt <= 32'b0;
		else if (rd_current_state[2] & rd_valid & rd_last)
			rd_cnt <= rd_cnt + 32'b1;
	end

	/*保存从FIFO中读出的数据*/
	always @ (posedge clk)
        begin
		if(wr_current_state[3])
                        fifodata <= fifo_rdata;
	end

        /*记录一次DMA引擎启动过程中突发写的次数*/
	always @ (posedge clk)
        begin
		if(rst | (rd_current_state[0] & wr_current_state[0] & ctrl_stat[0] & ~equal & ~intr & rd_burst_finish & wr_burst_finish))
			wr_cnt <= 32'b0;
		else if(wr_current_state[2] & wr_ready & wr_last)
			wr_cnt <= wr_cnt + 32'b1;
	end

        /*突发写的过程中已经读的数据数*/
	always @ (posedge clk)
        begin
		if(rst | wr_current_state[1])
                        wdata_counter <= 3'b0;
		else if(wr_current_state[2] & wr_ready)
                        wdata_counter <= wdata_counter + 3'b1;
	end

        assign intr = ctrl_stat[31];

        assign rd_req_addr = src_base + tail_ptr + (rd_cnt << 5);
	assign rd_req_len = ((rd_cnt == total_burst_num - 1) & |last_burst)? {2'b0, (last_burst - 3'b1)} : 5'b111;
	assign rd_req_valid = rd_current_state[1] & ~fifo_is_full & ~rd_burst_finish;
	assign rd_ready = rd_current_state[2];

	assign fifo_wen = rd_ready & rd_valid & ~fifo_is_full;
	assign fifo_wdata = rd_rdata;
        assign fifo_rden = (wr_next_state == FIFO);

	assign wr_req_valid = wr_current_state[1] & (wr_cnt < rd_cnt);
	assign wr_req_addr = dest_base + tail_ptr + {wr_cnt[26:0],5'b0};
	assign wr_req_len = ((wr_cnt == total_burst_num - 1) & |last_burst)? {2'b0, (last_burst - 3'b1)} : 5'b111;
	assign wr_valid = wr_current_state[2];
	assign wr_data = fifodata;
	assign wr_last = (wdata_counter == wr_req_len[2:0]);

endmodule
