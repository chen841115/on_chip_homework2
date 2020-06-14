`timescale 1 ns/1 ps
`include "PE.sv"
`include "input_SRAM.sv"
`include "output_SRAM.sv"
`include "weight_SRAM.sv"

module controller(
    clk,
    rst,
    DMA_done,
	kernel_size,
	kernel_num,
	row_end,
	col_end,
	stride,
	channel,
	tile_done
);

    // Input Ports: clock and control signals
    input   clk;
    input	rst;
    input   DMA_done;
	input	[3:0]	kernel_size;
	input	[9:0]	kernel_num;
	input	[5:0]	row_end;
	input	[5:0]	col_end;
	input	[2:0]	stride;
	input	[9:0]	channel;
	output	logic	tile_done;

	//PE
    logic   read_input_enable;
	logic   read_weight_enable;
	logic   read_psum_enable;
    logic   read_bias_enable;
	logic   if_do_bias;
	logic   [1:0]   if_do_activation;       //0->no 1->relu 2->leaky relu
	// PE
    logic   signed	[31:0]	PE_data_input		[0:8];
	logic   signed	[31:0]	PE_data_weight		[0:31][0:8];
    logic   signed	[31:0]	PE_data_pre_psum	[0:31];
    logic   signed	[31:0]  PE_data_bias		[0:31];
	logic	[11:0]	PE_psum_addr				[0:31];
    logic   signed	[31:0]  PE_data_psum_out	[0:31];
	logic	[11:0]	output_sram_addr			[0:31];
	logic	PE_done	[0:31];
	//output_SRAM
	logic	[31:0]	output_SRAM_DI		[0:31];
	logic	[31:0]	output_SRAM_DO		[0:31];
	logic	[11:0]	output_SRAM_AA		[0:31];	//output_SRAM_DI
	logic	[11:0]	output_SRAM_AB		[0:31];	//output_SRAM_DO
	logic	output_SRAM_CEN;
	logic	output_SRAM_OEN;
	logic	output_SRAM_WEN				[0:31];
	//input_SRAM
	//logic	[127:0]	input_SRAM_DI		[0:7];
	logic	[127:0]	input_SRAM_DO		[0:7];
	logic	[6:0]	input_SRAM_A		[0:7];
	logic	input_SRAM_CEN	[0:7];
	logic	input_SRAM_OEN	[0:7];
	logic	input_SRAM_WEN	[0:7]; 
	//weight_SRAM
	//logic	[287:0]	weight_SRAM_DI		[0:31];
	logic	[287:0]	weight_SRAM_DO		[0:31];
	logic	[6:0]	weight_SRAM_A		[0:31];
	logic	weight_SRAM_CEN		[0:31];
	logic	weight_SRAM_OEN		[0:31];
	logic	weight_SRAM_WEN		[0:31];

	//inner logic
	logic	[5:0]	cur_row,mem_access_row,mem_data_row;
	logic	[5:0]	cur_col,mem_access_col,mem_data_col;
	logic	[5:0]	next_row;
	logic	[5:0]	next_col;
	logic	[5:0]	filter_times;
	logic	[5:0]	filter_times_now;
	logic	[11:0]	mem_data_addr				[0:31];

	//SRAM data to PE pipeline


	//input_SRAM_A_predict
	logic	[6:0]	input_SRAM_A_predict	[0:2];
	logic	[11:0]	output_SRAM_AB_prdict;
	logic	[3:0]	predict_tmp1;
	logic	[3:0]	predict_tmp2;
	logic	[3:0]	predict_tmp3;
	//input_select
	logic	[2:0]	input_select	[0:2];
	logic	[2:0]	mem_access_input_select	[0:2];
	logic	[2:0]	mem_data_input_select	[0:2];

	//reg store input feature

	logic	[2:0]	cur_state,move_state,mem_access_state;
	logic	[2:0]	next_state;
	parameter IDLE = 3'b000;
	parameter S1   = 3'b001;
	parameter S2   = 3'b010;
	parameter S3   = 3'b011;
	parameter S4   = 3'b100;
	parameter S5   = 3'b101;
	parameter S6   = 3'b110;
	parameter S7   = 3'b111;

	// FSM
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			cur_state <= IDLE;
		else
			cur_state <= next_state;
	end
	
	always_comb
	begin
		if(rst)
			next_state = 4'd0;
		else
		begin
			case(cur_state)
				IDLE: 	
				begin
					if(DMA_done) 	next_state = S1;
					else			next_state = IDLE;
				end
				S1	:
				begin
					if(tile_done)	next_state = S2;
					else			next_state = S1;
				end
				S2	:
				begin
					if(~DMA_done)	next_state = IDLE;
					else			next_state = S2;
				end
				S3	:	next_state = S3;
				S4	:	next_state = S4;
				S5	:	next_state = S5;
				S6	:	next_state = S6;
				S7	:	next_state = S7;
			endcase
		end
	end
	
	// cur_row & cur_col
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			cur_col <= 5'd0;
			cur_row <= 5'd0;
		end
		else if(~tile_done)
		begin
			cur_col <= next_col;
			cur_row <= next_row;
		end
		else
		begin
			cur_col <= 5'd0;
			cur_row <= 5'd0;
		end
	end

	always_comb
	begin
		if(cur_col >= (col_end - kernel_size + 'b1))
		begin
			if(cur_row >= (row_end - kernel_size + 'b1))
			begin
				next_col = 5'd0;
				next_row = 5'd0;
			end
			else
			begin
				next_col = 5'd0;
				next_row = cur_row + 5'd1;
			end
		end
		else
		begin
			if(cur_state == S1)
			begin
				next_col = cur_col + stride;
				next_row = cur_row;
			end
			else
			begin
				next_col = 5'd0;
				next_row = 5'd0;
			end
		end
	end

	//input_SRAM_A_predict
	assign predict_tmp1 = next_row[5:3];
	assign predict_tmp2 = next_row[2:0];
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_SRAM_A_predict[i])
				input_SRAM_A_predict[i] <= 7'd0;
		end
		else
		begin
			case (next_col[1:0])
				2'b00	:
				begin
					input_SRAM_A_predict[0] <= 	(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col;
					input_SRAM_A_predict[1] <= 	(predict_tmp2>=7)? (((predict_tmp1+1) << 3) + ((predict_tmp1+1) << 2) + (predict_tmp1+1) + next_col):
												(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col;
					input_SRAM_A_predict[2] <= 	(predict_tmp2>=6)? (((predict_tmp1+1) << 3) + ((predict_tmp1+1) << 2) + (predict_tmp1+1) + next_col):
												(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col;
				end
				2'b01	:
				begin
					input_SRAM_A_predict[0] <= 	(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col;
					input_SRAM_A_predict[1] <= 	(predict_tmp2>=7)? (((predict_tmp1+1) << 3) + ((predict_tmp1+1) << 2) + (predict_tmp1+1) + next_col):
												(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col;
					input_SRAM_A_predict[2] <= 	(predict_tmp2>=6)? (((predict_tmp1+1) << 3) + ((predict_tmp1+1) << 2) + (predict_tmp1+1) + next_col):
												(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col;
				end
				2'b10	:
				begin
					input_SRAM_A_predict[0] <= 	(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col + 2;
					input_SRAM_A_predict[1] <= 	(predict_tmp2>=7)? (((predict_tmp1+1) << 3) + ((predict_tmp1+1) << 2) + (predict_tmp1+1) + next_col + 2):
												(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col + 2;
					input_SRAM_A_predict[2] <= 	(predict_tmp2>=6)? (((predict_tmp1+1) << 3) + ((predict_tmp1+1) << 2) + (predict_tmp1+1) + next_col + 2):
												(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col + 2;
				end
				2'b11	:
				begin
					input_SRAM_A_predict[0] <= 	(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col + 1;
					input_SRAM_A_predict[1] <= 	(predict_tmp2>=7)? (((predict_tmp1+1) << 3) + ((predict_tmp1+1) << 2) + (predict_tmp1+1) + next_col + 1):
												(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col + 1;
					input_SRAM_A_predict[2] <= 	(predict_tmp2>=6)? (((predict_tmp1+1) << 3) + ((predict_tmp1+1) << 2) + (predict_tmp1+1) + next_col + 1):
												(predict_tmp1 << 3) + (predict_tmp1 << 2) + predict_tmp1 + next_col + 1;
				end
			endcase
		end
	end

	//input_select ***
	// assign	input_select[0]	=	cur_row[2:0];
	// assign	input_select[1]	=	cur_row[2:0] + 'd1;
	// assign	input_select[2]	=	cur_row[2:0] + 'd2;
	always_ff  @(posedge clk, posedge rst)
	begin
		input_select[0]	<=	next_row[2:0];
		input_select[1]	<=	next_row[2:0] + 'd1;
		input_select[2]	<=	next_row[2:0] + 'd2;
		mem_access_input_select[0]	<=	input_select[0];
		mem_access_input_select[1]	<=	input_select[1];
		mem_access_input_select[2]	<=	input_select[2];
		mem_data_input_select[0]	<=	mem_access_input_select[0];
		mem_data_input_select[1]	<=	mem_access_input_select[1];
		mem_data_input_select[2]	<=	mem_access_input_select[2];
	end

	//input_SRAM_A
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_SRAM_A[i])
				input_SRAM_A[i]   <=	7'd0;
		end
		else if(kernel_size == 3)
		begin
			if(cur_state == S1)
			begin
				foreach(input_SRAM_A[i])
				begin
					if(i==input_select[0])
						input_SRAM_A[input_select[0]] <=  input_SRAM_A_predict[0][6:2];
					else if(i==input_select[1])
						input_SRAM_A[input_select[1]] <=  input_SRAM_A_predict[1][6:2];
					else if(i==input_select[2])
						input_SRAM_A[input_select[2]] <=  input_SRAM_A_predict[2][6:2];
					else
						input_SRAM_A[i]	<=	7'b0;;
				end
			end
			else
			begin
				input_SRAM_A[input_select[0]] = 'b0;
				input_SRAM_A[input_select[1]] = 'b0;
				input_SRAM_A[input_select[2]] = 'b0;
			end
		end 
	end

	//input_SRAM control
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_SRAM_CEN[i])
				input_SRAM_OEN[i]   <=	1'd1;
			foreach(input_SRAM_WEN[i])
				input_SRAM_WEN[i]   <=	1'd1;
			foreach(input_SRAM_CEN[i])
				input_SRAM_CEN[i]   <=	1'd0;
		end
		else if(kernel_size == 3)
		begin
			if(cur_state == S1)
			begin
				foreach(input_SRAM_OEN[i])
				begin
					if(i==input_select[0]||i==input_select[1]||i==input_select[2])
						input_SRAM_OEN[i]	<=	1'd0;
					else
						input_SRAM_OEN[i]	<=	1'd1;
				end
			end
			else
			begin
				foreach(input_SRAM_OEN[i])
					input_SRAM_OEN[i]	<=	1'd1;
			end
		end 
	end

	//filter_times
	assign filter_times = 	( kernel_num <= 32) ? 6'd1 : {1'b0 , kernel_num[9:5]};
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
			filter_times_now   <=	6'd0;
		else
		begin
			if(cur_state == S1 && tile_done == 1'b0)
			begin
				if(cur_col == 6'd0 && cur_row == 6'd0 )
					filter_times_now <= filter_times_now + 1;
				else
					filter_times_now <= filter_times_now;
			end
			else
				filter_times_now   <=	filter_times_now;
		end 
	end

	//tile_done
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
			tile_done   <=	1'b0;
		else if(filter_times_now > 1)
			tile_done   <=	1'b1;
		else 
			tile_done	<=	tile_done;
	end			

	//weight_SRAM_A
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(weight_SRAM_A[i])
				weight_SRAM_A[i]   <=	7'd0;
		end
		else if(kernel_size == 3)
		begin
			if(cur_state == S1 && filter_times_now <= filter_times)
			begin
				foreach(weight_SRAM_A[i])
					weight_SRAM_A[i]	<=	{1'b0,((filter_times_now==0)?6'b0:filter_times_now - 1'b1)};
			end
			else
			begin
				foreach(weight_SRAM_A[i])
					weight_SRAM_A[i]	<=	7'd0;
			end
		end 
		else
		begin
			foreach(weight_SRAM_A[i])
				weight_SRAM_A[i]   <=	7'd0;
		end
	end

	//weight_SRAM control
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(weight_SRAM_OEN[i])
				weight_SRAM_OEN[i]   <=	1'd1;
			foreach(weight_SRAM_WEN[i])
				weight_SRAM_WEN[i]   <=	1'd1;
			foreach(weight_SRAM_CEN[i])
				weight_SRAM_CEN[i]   <=	1'd0;
		end
		if(kernel_size == 3)
		begin
			if(cur_state == S1)
			begin
				foreach(weight_SRAM_OEN[i])
					weight_SRAM_OEN[i]	<=	1'd0;
			end
			else
			begin
				foreach(weight_SRAM_OEN[i])
					weight_SRAM_OEN[i]	<=	1'd1;
			end
		end 
	end

	// may have some problem
	assign output_SRAM_AB_prdict = (cur_row << 5) + (cur_row << 4) + (cur_row << 2) + cur_col;
	//output_SRAM_AB
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(output_SRAM_AB[i])
				output_SRAM_AB[i]   <=	12'd0;
		end
		else if(kernel_size == 3)
		begin
			if(cur_state == S1)
			begin
				foreach(output_SRAM_AB[i])
					output_SRAM_AB[i]   <=	output_SRAM_AB_prdict;
			end
			else
			begin
				foreach(output_SRAM_AB[i])
					output_SRAM_AB[i]   <=	12'd0;
			end
		end 
	end
	//output_SRAM_AA
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(output_SRAM_AA[i])
				output_SRAM_AA[i]   <=	12'd0;
		end
		else if(kernel_size == 3)
		begin
			foreach(output_SRAM_AA[i])
				output_SRAM_AA[i]	<=	output_sram_addr[i];
			foreach(output_SRAM_WEN[i])
				output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
		end 
	end

	//output_SRAM_DI
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(output_SRAM_DI[i])
				output_SRAM_DI[i]	<=	32'b0;
		end
		else if(kernel_size == 3)
		begin
			foreach(output_SRAM_DI[i])
				output_SRAM_DI[i]	<=	PE_data_psum_out[i];
		end 
	end

	//output_SRAM control
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			output_SRAM_OEN   <=	1'd1;
			output_SRAM_CEN   <=	1'd0;
		end
		else if(kernel_size == 3)
		begin
			if(cur_state == S1)
			begin
				output_SRAM_OEN	<=	1'd0;
			end
			else
			begin
				output_SRAM_OEN	<=	1'd1;
			end
		end 
	end

	//PE_psum_addr
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(PE_psum_addr[i])
				PE_psum_addr[i]	<=	12'b0;
			foreach(mem_data_addr[i])
				mem_data_addr[i]<=	12'b0;
		end
		else
		begin
			foreach(PE_psum_addr[i])
				PE_psum_addr[i]	<=	mem_data_addr[i];
			foreach(mem_data_addr[i])
				mem_data_addr[i]<=	output_SRAM_AB[i];
		end
	end

	//PE data
	//weight
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(PE_data_weight[i])
			begin
				foreach(PE_data_weight[i][j])
					PE_data_weight[i][j]	<=	32'b0;
			end
		end
		else
		begin
			foreach(PE_data_weight[i])
			begin
				PE_data_weight[i][0] = weight_SRAM_DO[i][287:256];
				PE_data_weight[i][1] = weight_SRAM_DO[i][255:224];
				PE_data_weight[i][2] = weight_SRAM_DO[i][223:192];
				PE_data_weight[i][3] = weight_SRAM_DO[i][191:160];
				PE_data_weight[i][4] = weight_SRAM_DO[i][159:128];
				PE_data_weight[i][5] = weight_SRAM_DO[i][127:96];
				PE_data_weight[i][6] = weight_SRAM_DO[i][95:64];
				PE_data_weight[i][7] = weight_SRAM_DO[i][63:32];
				PE_data_weight[i][8] = weight_SRAM_DO[i][31:0];
			end	
		end
	end

	//input
	// always_ff  @(posedge clk)
	// begin
	// 	predict_tmp3	<=	mem_data_row[2:0];
	// end
	assign predict_tmp3 = mem_data_row[2:0];
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(PE_data_input[i])
				PE_data_input[i]	<=	32'b0;
		end
		else
		begin
			if(kernel_size == 'd3)
			begin
				if(stride == 'd1)
				begin
					case (mem_data_col[1:0])
						2'b00	:
						begin
							PE_data_input[0]	<=	input_SRAM_DO[mem_data_input_select[0]][127:96];
							PE_data_input[1]	<=	input_SRAM_DO[mem_data_input_select[0]][95:64];
							PE_data_input[2]	<=	input_SRAM_DO[mem_data_input_select[0]][63:32];
							PE_data_input[3]	<=	input_SRAM_DO[mem_data_input_select[1]][127:96];
							PE_data_input[4]	<=	input_SRAM_DO[mem_data_input_select[1]][95:64];
							PE_data_input[5]	<=	input_SRAM_DO[mem_data_input_select[1]][63:32];
							PE_data_input[6]	<=	input_SRAM_DO[mem_data_input_select[2]][127:96];
							PE_data_input[7]	<=	input_SRAM_DO[mem_data_input_select[2]][95:64];
							PE_data_input[8]	<=	input_SRAM_DO[mem_data_input_select[2]][63:32];
						end
						2'b01	:
						begin
							PE_data_input[0]	<=	input_SRAM_DO[mem_data_input_select[0]][95:64];
							PE_data_input[1]	<=	input_SRAM_DO[mem_data_input_select[0]][63:32];
							PE_data_input[2]	<=	input_SRAM_DO[mem_data_input_select[0]][31:0];
							PE_data_input[3]	<=	input_SRAM_DO[mem_data_input_select[1]][95:64];
							PE_data_input[4]	<=	input_SRAM_DO[mem_data_input_select[1]][63:32];
							PE_data_input[5]	<=	input_SRAM_DO[mem_data_input_select[1]][31:0];
							PE_data_input[6]	<=	input_SRAM_DO[mem_data_input_select[2]][95:64];
							PE_data_input[7]	<=	input_SRAM_DO[mem_data_input_select[2]][63:32];
							PE_data_input[8]	<=	input_SRAM_DO[mem_data_input_select[2]][31:0];
						end
						2'b10	:
						begin
							PE_data_input[0]	<=	PE_data_input[1];
							PE_data_input[1]	<=	PE_data_input[2];
							PE_data_input[2]	<=	input_SRAM_DO[mem_data_input_select[0]][127:96];
							PE_data_input[3]	<=	PE_data_input[4];
							PE_data_input[4]	<=	PE_data_input[5];
							PE_data_input[5]	<=	input_SRAM_DO[mem_data_input_select[1]][127:96];
							PE_data_input[6]	<=	PE_data_input[7];
							PE_data_input[7]	<=	PE_data_input[8];
							PE_data_input[8]	<=	input_SRAM_DO[mem_data_input_select[2]][127:96];
						end
						2'b11	:
						begin
							PE_data_input[0]	<=	PE_data_input[1];
							PE_data_input[1]	<=	PE_data_input[2];
							PE_data_input[2]	<=	input_SRAM_DO[mem_data_input_select[0]][95:64];
							PE_data_input[3]	<=	PE_data_input[4];
							PE_data_input[4]	<=	PE_data_input[5];
							PE_data_input[5]	<=	input_SRAM_DO[mem_data_input_select[1]][95:64];
							PE_data_input[6]	<=	PE_data_input[7];
							PE_data_input[7]	<=	PE_data_input[8];
							PE_data_input[8]	<=	input_SRAM_DO[mem_data_input_select[2]][95:64];
						end
						default	:
						begin
							foreach(PE_data_input[i])
								PE_data_input[i]	<=	32'b0;
						end
					endcase
				end
			end
		end
	end
	//psum
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(PE_data_pre_psum[i])
				PE_data_pre_psum[i]	<=	32'b0;
		end
		else
		begin
			foreach(PE_data_pre_psum[i])
				PE_data_pre_psum[i] <= output_SRAM_DO[i];
		end
	end
	
	//PE control
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			read_input_enable	<=	1'b0;
			read_weight_enable	<=	1'b0;
			read_psum_enable	<=	1'b0;
			read_bias_enable	<=	1'b0;
			if_do_bias			<=	1'b0;
			if_do_activation	<=	2'b0;
		end
		else if(mem_access_state == S1)
		begin
			read_input_enable	<=	1'b1;
			read_weight_enable	<=	1'b1;
			read_psum_enable	<=	1'b1;
		end
	end

	//pipeline state
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			move_state			<=	IDLE;
			mem_access_state	<=	IDLE;
		end
		else 
		begin
			move_state			<=	cur_state;
			mem_access_state	<=	move_state;
		end 
	end

	//pipeline col row
	always_ff  @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			mem_access_row	<=	5'd0;
			mem_data_row	<=	5'd0;
			mem_access_col	<=	5'd0;
			mem_data_col	<=	5'd0;
		end
		else 
		begin
			mem_access_row	<=	cur_row;
			mem_data_row	<=	mem_access_row;
			mem_access_col	<=	cur_col;
			mem_data_col	<=	mem_access_col;
		end 
	end

	//PE * 32
	genvar i;
	generate
		for(i=0;i<32;i=i+1)
		begin: u_PE
			PE PE_i(
				.clk(clk),
				.rst(rst),
				.read_input_enable(read_input_enable),        
				.read_weight_enable(read_weight_enable),
				.read_psum_enable(read_psum_enable),        
				.read_bias_enable(read_bias_enable),
				.if_do_bias(if_do_bias),        
				.if_do_activation(if_do_activation),
				// Input Ports
				.Input(PE_data_input),        
				.Weight(PE_data_weight[i]),
				.Pre_psum(PE_data_pre_psum[i]),
				.Bias(PE_data_bias[i]),
				.Psum_addr(PE_psum_addr[i]),
				// Output Ports
				.Psum_out(PE_data_psum_out[i]),
				.output_sram_addr(output_sram_addr[i]),
				.PE_done(PE_done[i])
			);
		end
	endgenerate

	//output_SRAM * 32
	generate
		for(i=0;i<32;i=i+1)
		begin: u_output_SRAM
			output_SRAM output_SRAM_i(
				// A
				.CLKA(clk),
				.CENA(output_SRAM_CEN),
				.WENA(output_SRAM_WEN[i]),
				.OENA(),
				.AA(output_SRAM_AA[i]),
				.DA(output_SRAM_DI[i]),
				.QA(),
				// B
				.CLKB(clk),
				.CENB(output_SRAM_CEN),
				.WENB(),
				.OENB(output_SRAM_OEN),
				.AB(output_SRAM_AB[i]),
				.DB(),
				.QB(output_SRAM_DO[i])
			);
		end
	endgenerate

	//input_SRAM * 8
	generate
		for(i=0;i<8;i=i+1)
		begin: u_input_SRAM
			input_SRAM input_SRAM_i(
				.CLK(clk),
				.CEN(input_SRAM_CEN[i]),
				.WEN(input_SRAM_WEN[i]),
				.OEN(input_SRAM_OEN[i]),
				.A(input_SRAM_A[i]),
				.D(),
				.Q(input_SRAM_DO[i])
			);
		end
	endgenerate

	//weight_SRAM * 32
	generate
		for(i=0;i<32;i=i+1)
		begin: u_weight_SRAM
			weight_SRAM weight_SRAM_i(
				.CLK(clk),
				.CEN(weight_SRAM_CEN[i]),
				.WEN(weight_SRAM_WEN[i]),
				.OEN(weight_SRAM_OEN[i]),
				.A(weight_SRAM_A[i]),
				.D(),
				.Q(weight_SRAM_DO[i])
			);
		end
	endgenerate

	
endmodule
// 	//PE data
// 	//weight
// 	always_comb
// 	begin
// 		foreach(PE_data_weight[i])
// 		begin
// 			PE_data_weight[i][0] = weight_SRAM_DO[i][287:256];
// 			PE_data_weight[i][1] = weight_SRAM_DO[i][255:224];
// 			PE_data_weight[i][2] = weight_SRAM_DO[i][223:192];
// 			PE_data_weight[i][3] = weight_SRAM_DO[i][191:160];
// 			PE_data_weight[i][4] = weight_SRAM_DO[i][159:128];
// 			PE_data_weight[i][5] = weight_SRAM_DO[i][127:96];
// 			PE_data_weight[i][6] = weight_SRAM_DO[i][95:64];
// 			PE_data_weight[i][7] = weight_SRAM_DO[i][63:32];
// 			PE_data_weight[i][8] = weight_SRAM_DO[i][31:0];
// 		end
// 	end
// 	//input
// 	assign predict_tmp3 = mem_data_row[2:0];
// 	always_comb
// 	begin
// 		foreach(PE_data_input[i])
// 		begin
// 			if(kernel_size == 'd3)
// 			begin
// 				if(stride == 'd1)
// 				begin
// 					case (PE_data_input[i][1:0])
// 						2'b00	:
// 						begin
// 							if(predict_tmp3 == 'd7)
// 							begin
// 								PE_data_input[0] = input_SRAM_DO[]
// 							end
// 						end
// 					endcase
// 				end
// 			end
// 		end
// 	end
// 	//psum
// 	always_comb
// 	begin
// 		foreach(PE_data_pre_psum[i])
// 		begin
// 			PE_data_pre_psum[i] = output_SRAM_DO[i];
// 		end
// 	end
	
// 	//PE control
// 	always_ff  @(posedge clk, posedge rst)
// 	begin
// 		if(rst)
// 		begin
// 			read_input_enable	<=	1'b0;
// 			read_weight_enable	<=	1'b0;
// 			read_psum_enable	<=	1'b0;
// 			read_bias_enable	<=	1'b0;
// 			if_do_bias			<=	1'b0;
// 			if_do_activation	<=	2'b0;
// 		end
// 		else if(mem_access_state == S1)
// 		begin
// 			read_input_enable	<=	1'b1;
// 			read_weight_enable	<=	1'b1;
// 			read_psum_enable	<=	1'b1;
// 		end
// 	end