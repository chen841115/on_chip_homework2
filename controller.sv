`timescale 1 ns/1 ps
`include "PE.sv"

module controller(
    clk,
    rst,
    controller_run,
	input_SRAM_ready,
	kernel_size,
	kernel_num,
	row_end,
	col_end,
	stride,
	channel,
	tile_done,
	act_cur_channel,
	cur_channel,
	pooling_enable,
	//SRAM
	//output_SRAM
	output_SRAM_DI,
	output_SRAM_DO,
	output_SRAM_AA,
	output_SRAM_AB,
	output_SRAM_CEN,
	output_SRAM_OEN,
	output_SRAM_WEN,
	//input_SRAM
	input_SRAM_DO,
	input_SRAM_A,
	input_SRAM_CEN,
	input_SRAM_OEN,
	//input_SRAM_WEN,
	//weight_SRAM
	weight_SRAM_DO,
	weight_SRAM_A,
	weight_SRAM_CEN,
	weight_SRAM_OEN,
	weight_SRAM_WEN,
	//bank_done
	cur_row,
	cur_state,
	//filter_parting_size1_times
	filter_parting_map_times
);

    // Input Ports: clock and control signals
    input   clk;
    input	rst;
    input   controller_run;
	input	input_SRAM_ready	[0:63];
	input	[3:0]	kernel_size;
	input	[9:0]	kernel_num;
	input	[5:0]	row_end;
	input	[5:0]	col_end;
	input	[2:0]	stride;
	input	[10:0]	channel;
	output	logic	tile_done;
	input	[10:0]	act_cur_channel;
	input	[10:0]	cur_channel;
	input	pooling_enable;
	//output_SRAM
	output	logic	[15:0]	output_SRAM_DI		[0:31];
	input	logic	[15:0]	output_SRAM_DO		[0:31];
	output	logic	[11:0]	output_SRAM_AA		[0:31];	//output_SRAM_DI
	output	logic	[11:0]	output_SRAM_AB		[0:31];	//output_SRAM_DO
	output	logic	output_SRAM_CEN;
	output	logic	output_SRAM_OEN;
	output	logic	output_SRAM_WEN				[0:31];
	//input_SRAM
	//logic	[127:0]	input_SRAM_DI		[0:7];
	input	logic	[31:0]	input_SRAM_DO		[0:63];
	output	logic	[6:0]	input_SRAM_A		[0:63];
	output	logic	input_SRAM_CEN	[0:63];
	output	logic	input_SRAM_OEN	[0:63];
	//output	logic	input_SRAM_WEN	[0:7]; 
	//weight_SRAM
	//logic	[287:0]	weight_SRAM_DI		[0:31];
	input	logic	[7:0]	weight_SRAM_DO		[0:287];
	output	logic	[6:0]	weight_SRAM_A		[0:287];
	output	logic	weight_SRAM_CEN		[0:287];
	output	logic	weight_SRAM_OEN		[0:287];
	output	logic	weight_SRAM_WEN		[0:287];
	//bank_done
	output	[5:0]	cur_row;
	output	[2:0]	cur_state;

	//filter_parting_size1_times
	input	[3:0]	filter_parting_map_times;

	


	//PE
    logic   read_input_enable;
	logic   read_weight_enable;
	logic   read_psum_enable;
    logic   read_bias_enable;
	logic   if_do_bias;
	logic   [1:0]   if_do_activation;       //0->no 1->relu 2->leaky relu
	// PE
    logic   signed	[7:0]	PE_data_input		[0:8];
	logic   signed	[7:0]	PE_data_weight		[0:31][0:8];
    logic   signed	[15:0]	PE_data_pre_psum	[0:31];
    logic   signed	[15:0]  PE_data_bias		[0:31];
	logic	[11:0]	PE_psum_addr				[0:31];
    logic   signed	[15:0]  PE_data_psum_out	[0:31];
	logic	[11:0]	output_sram_addr			[0:31];
	logic	PE_done	[0:31];
	logic	rst_PE_reg;

	//inner logic
	logic	[5:0]	cur_row,mem_access_row,mem_data_row;
	logic	[5:0]	cur_col,mem_access_col,mem_data_col;
	logic	[5:0]	PE_row,PE_mult_row,PE_add_row,PE_out_row;
	logic	[5:0]	PE_col,PE_mult_col,PE_add_col,PE_out_col;
	logic	[5:0]	next_row;
	logic	[5:0]	next_col;
	logic	[5:0]	filter_times;
	logic	[5:0]	filter_times_now;
	logic	[11:0]	mem_data_addr				[0:31];
	logic	[11:0]	output_SRAM_addr_write;

	//SRAM data to PE pipeline


	//input_SRAM_A_predict
	logic	[6:0]	input_SRAM_A_predict	[0:10];
	logic	[11:0]	output_SRAM_AB_prdict;
	logic	[3:0]	predict_tmp1;
	logic	[3:0]	predict_tmp2;
	logic	[3:0]	predict_tmp3;
	//input_select
	logic	[5:0]	input_select	[0:8];
	logic	[5:0]	mem_access_input_select	[0:8];
	logic	[5:0]	mem_data_input_select	[0:8];
	//input_SRAM buffer
	logic	[7:0]	data_buffer	[0:51];
	//oversize kernel
	logic	[4:0]	oversize_count;
	logic	[1:0]	oversize_first,mem_access_oversize_first,mem_data_oversize_first;
	logic	oversize_part_done;
	//max_pooling
	logic	[15:0]	max_pooling_buffer1	[0:31];
	logic	[15:0]	max_pooling_buffer2	[0:31];
	logic	[15:0]	max_pooling_buffer3	[0:31];
	logic	pooling_delay;
	logic	state_done;

	//reg store input feature

	logic	[2:0]	cur_state,move_state,mem_access_state;
	logic	[2:0]	next_state,pre_state;
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
			cur_state	<=	IDLE;
		else
		begin
			cur_state	<=	next_state;
			pre_state	<=	cur_state;
		end
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
					if(controller_run)
					begin
						if(kernel_size == 'd3 || kernel_size == 'd1)
							next_state = S1;
						else
							next_state = S3;
					end
					else			
						next_state = IDLE;
				end
				S1:
				begin
					if(state_done || oversize_part_done)	
						next_state = S2;
					else			
						next_state = S1;
				end
				S2:
				begin
					if(~controller_run)	
					begin
						if(kernel_size == 'd3 || kernel_size == 'd1)
						begin
							if(tile_done)
								next_state = IDLE;
							else
								next_state = S2;
						end
							// next_state = IDLE;
						else
							next_state = S3;
					end
					else
						next_state = S2;
				end
				S3:
				begin
					if(kernel_size == 'd5 && oversize_count < 'b10)
						next_state = S1;
					else if(kernel_size == 'd7 && oversize_count < 'b101)
						next_state = S1;
					else
						next_state = IDLE;
				end
				S4:	next_state = S4;
				S5:	next_state = S5;
				S6:	next_state = S6;
				S7:	next_state = S7;
			endcase
		end
	end

	//oversize kernel 
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			oversize_count	<=	'b0;
		else if(cur_state == IDLE)
			oversize_count	<=	'b0;
		else if(cur_state == S3)
		begin
			if(kernel_size == 'd5)
			begin
				if(pre_state == IDLE)
					oversize_count	<=	'b0;
				else if(oversize_count >= 'b10)
					oversize_count	<=	oversize_count;
				else 
					oversize_count	<=	oversize_count + 'b1;
			end
			else if(kernel_size == 'd7)
			begin
				if(pre_state == IDLE)
					oversize_count	<=	'b0;
				else if(oversize_count >= 'b101)
					oversize_count	<=	oversize_count;
				else 
					oversize_count	<=	oversize_count + 'b1;
			end
		end
	end
	//oversize_first
	always_ff @(posedge clk, posedge rst)
	begin
		if(kernel_size == 'd5)
		begin
			if(cur_state == IDLE)
				oversize_first	<=	'b0;
			else if(cur_state == S1)
			begin
				if(next_col == 6'b0 && cur_col != 6'b1)
					oversize_first	<=	oversize_first + 'b1;
				else
					oversize_first	<=	'b0;
			end
			else
				oversize_first	<=	'b0;
		end
		else if(kernel_size == 'd7)
		begin
			if(cur_state == IDLE)
				oversize_first	<=	'b0;
			else if(cur_state == S1)
			begin
				if(next_col == 6'b0 && cur_col != 6'b1)
					oversize_first	<=	oversize_first + 'b1;
				else
					oversize_first	<=	'b0;
			end
			else
				oversize_first	<=	'b0;
		end
		else
			oversize_first	<=	1'b0;			
	end
	always_ff @(posedge clk, posedge rst)
	begin
		if(kernel_size == 'd5 || kernel_size == 'd7)
		begin
			mem_access_oversize_first	<=	oversize_first;
			mem_data_oversize_first	<=	mem_access_oversize_first;
		end
		else
		begin
			mem_access_oversize_first	<=	'b0;
			mem_data_oversize_first	<=	'b0;
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
		if(kernel_size == 'd3)
		begin
			if(stride == 'd1)
			begin
				if(cur_state == S1)
				begin
					if(pooling_enable)
					begin
						if(pooling_delay)
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
								next_col = cur_col + 1'b1;
								next_row = cur_row;
							end
						end
					end
					else
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
							next_col = cur_col + 1'b1;
							next_row = cur_row;
						end
					end
				end
				else
				begin
					next_col = 5'd0;
					next_row = 5'd0;
				end
			end
			else if(stride == 'd2)
			begin
				if(cur_state == S1)
				begin
					if(cur_col >= (col_end - kernel_size + 'b0))
					begin
						if(cur_row >= (row_end - kernel_size + 'b0))
						begin
							next_col = 5'd0;
							next_row = 5'd0;
						end
						else
						begin
							next_col = 5'd0;
							next_row = cur_row + 5'd2;
						end
					end
					else
					begin
						next_col = cur_col + 'b10;
						next_row = cur_row;
					end
				end
				else
				begin
					next_col = 5'd0;
					next_row = 5'd0;
				end
			end
			// if(stride == 'd1)
			// begin
			// 	if(cur_col >= (col_end - kernel_size + 'b1))
			// 	begin
			// 		if(cur_row >= (row_end - kernel_size + 'b1))
			// 		begin
			// 			next_col = 5'd0;
			// 			next_row = 5'd0;
			// 		end
			// 		else
			// 		begin
			// 			next_col = 5'd0;
			// 			next_row = cur_row + 5'd1;
			// 		end
			// 	end
			// 	else
			// 	begin
			// 		if(cur_state == S1)
			// 		begin
			// 			next_col = cur_col + 1'b1;
			// 			next_row = cur_row;
			// 		end
			// 		else
			// 		begin
			// 			next_col = 5'd0;
			// 			next_row = 5'd0;
			// 		end
			// 	end
			// end
		end
		else if(kernel_size == 'd5)
		begin
			if(stride == 'd1)
			begin
				if(cur_state == S1)
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
						if(cur_col == 6'b0 && oversize_count == 'b10)
						begin
							if(oversize_first == 'b10)
								next_col = cur_col + 1'b1;
							else
								next_col = cur_col;
						end
						else
							next_col = cur_col + 1'b1;
						next_row = cur_row;
					end
				end
				else
				begin
					next_col = 5'd0;
					next_row = 5'd0;
				end
			end
			else if(stride == 'd2)
			begin
				if(cur_state == S1)
				begin
					if(cur_col >= (col_end - kernel_size + 'b0))
					begin
						if(cur_row >= (row_end - kernel_size + 'b0))
						begin
							next_col = 5'd0;
							next_row = 5'd0;
						end
						else
						begin
							next_col = 5'd0;
							next_row = cur_row + 5'd2;
						end
					end
					else
					begin
						if(cur_col == 6'b0 && oversize_count == 'b10)
						begin
							if(oversize_first == 'b10)
								next_col = cur_col + 'b10;
							else
								next_col = cur_col;
						end
						else
							next_col = cur_col + 'b10;
						next_row = cur_row;
					end
				end
				else
				begin
					next_col = 5'd0;
					next_row = 5'd0;
				end
			end
		end
		else if(kernel_size == 'd7)
		begin
			if(stride == 'd1)
			begin
				if(cur_state == S1 && pre_state == S1)
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
						if(cur_col == 6'b0 && oversize_count == 'b11)
						begin
							if(oversize_first == 'b10)
								next_col = cur_col + 1'b1;
							else
								next_col = cur_col;
						end
						else
							next_col = cur_col + 1'b1;
						next_row = cur_row;
					end
				end
				else
				begin
					next_col = 5'd0;
					next_row = 5'd0;
				end
			end
			else if(stride == 'd2)
			begin
				if(cur_state == S1 && pre_state == S1)
				begin
					if(cur_col >= (col_end - kernel_size + 'b0))
					begin
						if(cur_row >= (row_end - kernel_size + 'b0))
						begin
							next_col = 5'd0;
							next_row = 5'd0;
						end
						else
						begin
							next_col = 5'd0;
							next_row = cur_row + 5'd2;
						end
					end
					else
					begin
						if(cur_col == 6'b0 && oversize_count == 'b11)
						begin
							if(oversize_first == 'b10)
								next_col = cur_col + 'b10;
							else
								next_col = cur_col;
						end
						else
							next_col = cur_col + 'b10;
						next_row = cur_row;
					end
				end
				else
				begin
					next_col = 5'd0;
					next_row = 5'd0;
				end
			end
		end
		else if(kernel_size == 'd1)
		begin
			if(stride == 'd1)
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
						next_col = cur_col + 1'b1;
						next_row = cur_row;
					end
					else
					begin
						next_col = 5'd0;
						next_row = 5'd0;
					end
				end
			end
		end
	end

	// //bank_done
	// always_ff @(posedge clk, posedge rst)
	// begin
	// 	if(rst || (cur_state==IDLE))
	// 	begin
	// 		foreach(bank_done[i])
	// 			bank_done[i]	<=	1'b0;
	// 	end
	// 	else if(kernel_size == 3)
	// 	begin
	// 		if(cur_row	>	44)	bank_done[4]	<=	1'b1;
	// 		if(cur_row	>	45)	bank_done[5]	<=	1'b1;
	// 		if(cur_row	>	46)	bank_done[6]	<=	1'b1;
	// 		if(cur_row	>	47)	bank_done[7]	<=	1'b1;
	// 		if(cur_row	>	48)	bank_done[0]	<=	1'b1;
	// 		if(tile_done)	bank_done[1]	<=	1'b1;
	// 		if(tile_done)	bank_done[2]	<=	1'b1;
	// 		if(tile_done)	bank_done[3]	<=	1'b1;
	// 	end
	// end

	//input_SRAM_A_predict
	assign predict_tmp1 = next_row[5:3];
	assign predict_tmp2 = next_row[2:0];
	always_comb
	begin
		if(rst)
		begin
			foreach(input_SRAM_A_predict[i])
				input_SRAM_A_predict[i] = 7'd0;
		end
		else
		begin
			if(kernel_size == 'd3)
			begin
				if(stride == 'd1 || stride == 'd2)
				begin
					case (next_col[1:0])
						2'b00	:
						begin
							input_SRAM_A_predict[0] = 	next_col;
							input_SRAM_A_predict[1] = 	next_col;
							input_SRAM_A_predict[2] = 	next_col;
						end
						2'b01	:
						begin
							input_SRAM_A_predict[0] = 	next_col;
							input_SRAM_A_predict[1] = 	next_col;
							input_SRAM_A_predict[2] = 	next_col;
						end
						2'b10	:
						begin
							input_SRAM_A_predict[0] = 	next_col + 2;
							input_SRAM_A_predict[1] = 	next_col + 2;
							input_SRAM_A_predict[2] = 	next_col + 2;
						end
						2'b11	:
						begin
							input_SRAM_A_predict[0] = 	next_col + 1;
							input_SRAM_A_predict[1] = 	next_col + 1;
							input_SRAM_A_predict[2] = 	next_col + 1;
						end
					endcase
				end
			end
			else if(kernel_size == 'd5)
			begin
				if(stride == 'd1 || stride == 'd2)
				begin
					case (next_col[1:0])
						2'b00	:
						begin
							if(oversize_count == 'b0)
							begin
								input_SRAM_A_predict[0] = 	next_col;
								input_SRAM_A_predict[1] = 	next_col;
								input_SRAM_A_predict[2] = 	next_col;
								input_SRAM_A_predict[3] = 	next_col;
								input_SRAM_A_predict[4] = 	next_col;
							end
							else if(oversize_count == 'b1)
							begin
								input_SRAM_A_predict[0] = 	next_col;
								input_SRAM_A_predict[1] = 	next_col;
								input_SRAM_A_predict[2] = 	next_col;
								input_SRAM_A_predict[3] = 	next_col;
								input_SRAM_A_predict[4] = 	next_col;
							end
							else if(oversize_count == 'b10)
							begin
								if(next_col == 6'b0)
								begin
									if(oversize_first == 1'b0)
									begin
										input_SRAM_A_predict[0] = 	next_col;
										input_SRAM_A_predict[1] = 	next_col;
										input_SRAM_A_predict[2] = 	next_col;
										input_SRAM_A_predict[3] = 	next_col;
										input_SRAM_A_predict[4] = 	next_col;
									end
									else
									begin
										input_SRAM_A_predict[0] = 	next_col + 'b100;
										input_SRAM_A_predict[1] = 	next_col + 'b100;
										input_SRAM_A_predict[2] = 	next_col + 'b100;
										input_SRAM_A_predict[3] = 	next_col + 'b100;
										input_SRAM_A_predict[4] = 	next_col + 'b100;
									end
								end
								else
								begin
									input_SRAM_A_predict[0] = 	next_col + 'b100;
									input_SRAM_A_predict[1] = 	next_col + 'b100;
									input_SRAM_A_predict[2] = 	next_col + 'b100;
									input_SRAM_A_predict[3] = 	next_col + 'b100;
									input_SRAM_A_predict[4] = 	next_col + 'b100;
								end
							end
						end
						2'b01	:
						begin
							if(oversize_count == 'b0)
							begin
								input_SRAM_A_predict[0] = 	next_col;
								input_SRAM_A_predict[1] = 	next_col;
								input_SRAM_A_predict[2] = 	next_col;
								input_SRAM_A_predict[3] = 	next_col;
								input_SRAM_A_predict[4] = 	next_col;
							end
							else if(oversize_count == 'b1)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd3;
								input_SRAM_A_predict[1] = 	next_col + 'd3;
								input_SRAM_A_predict[2] = 	next_col + 'd3;
								input_SRAM_A_predict[3] = 	next_col + 'd3;
								input_SRAM_A_predict[4] = 	next_col + 'd3;
							end
							else if(oversize_count == 'b10)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd3;
								input_SRAM_A_predict[1] = 	next_col + 'd3;
								input_SRAM_A_predict[2] = 	next_col + 'd3;
								input_SRAM_A_predict[3] = 	next_col + 'd3;
								input_SRAM_A_predict[4] = 	next_col + 'd3;
							end
						end
						2'b10	:
						begin
							if(oversize_count == 'b0)
							begin
								input_SRAM_A_predict[0] = 	next_col;
								input_SRAM_A_predict[1] = 	next_col;
								input_SRAM_A_predict[2] = 	next_col;
								input_SRAM_A_predict[3] = 	next_col;
								input_SRAM_A_predict[4] = 	next_col;
							end
							else if(oversize_count == 'b1)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd2;
								input_SRAM_A_predict[1] = 	next_col + 'd2;
								input_SRAM_A_predict[2] = 	next_col + 'd2;
								input_SRAM_A_predict[3] = 	next_col + 'd2;
								input_SRAM_A_predict[4] = 	next_col + 'd2;
							end
							else if(oversize_count == 'b10)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd2;
								input_SRAM_A_predict[1] = 	next_col + 'd2;
								input_SRAM_A_predict[2] = 	next_col + 'd2;
								input_SRAM_A_predict[3] = 	next_col + 'd2;
								input_SRAM_A_predict[4] = 	next_col + 'd2;
							end
						end
						2'b11	:
						begin
							if(oversize_count == 'b0)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd1;
								input_SRAM_A_predict[1] = 	next_col + 'd1;
								input_SRAM_A_predict[2] = 	next_col + 'd1;
								input_SRAM_A_predict[3] = 	next_col + 'd1;
								input_SRAM_A_predict[4] = 	next_col + 'd1;
							end
							else if(oversize_count == 'b1)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd1;
								input_SRAM_A_predict[1] = 	next_col + 'd1;
								input_SRAM_A_predict[2] = 	next_col + 'd1;
								input_SRAM_A_predict[3] = 	next_col + 'd1;
								input_SRAM_A_predict[4] = 	next_col + 'd1;
							end
							else if(oversize_count == 'b10)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd1;
								input_SRAM_A_predict[1] = 	next_col + 'd1;
								input_SRAM_A_predict[2] = 	next_col + 'd1;
								input_SRAM_A_predict[3] = 	next_col + 'd1;
								input_SRAM_A_predict[4] = 	next_col + 'd1;
							end
						end
					endcase
				end
			end
			else if(kernel_size == 'd7)
			begin
				if(stride == 'd1 || stride == 'd2)
				begin
					case (next_col[1:0])
						2'b00	:
						begin
							if(oversize_count == 'b000 || oversize_count == 'b001 || oversize_count == 'b010)
							begin
								input_SRAM_A_predict[0] = 	next_col;
								input_SRAM_A_predict[1] = 	next_col;
								input_SRAM_A_predict[2] = 	next_col;
								input_SRAM_A_predict[3] = 	next_col;
								input_SRAM_A_predict[4] = 	next_col;
								input_SRAM_A_predict[5] = 	next_col;
								input_SRAM_A_predict[6] = 	next_col;
							end
							else if(oversize_count == 'b011)
							begin
								if(next_col == 6'b0)
								begin
									if(oversize_first == 1'b0)
									begin
										input_SRAM_A_predict[0] = 	next_col;
										input_SRAM_A_predict[1] = 	next_col;
										input_SRAM_A_predict[2] = 	next_col;
										input_SRAM_A_predict[3] = 	next_col;
										input_SRAM_A_predict[4] = 	next_col;
										input_SRAM_A_predict[5] = 	next_col;
										input_SRAM_A_predict[6] = 	next_col;
									end
									else
									begin
										input_SRAM_A_predict[0] = 	next_col + 'b100;
										input_SRAM_A_predict[1] = 	next_col + 'b100;
										input_SRAM_A_predict[2] = 	next_col + 'b100;
										input_SRAM_A_predict[3] = 	next_col + 'b100;
										input_SRAM_A_predict[4] = 	next_col + 'b100;
										input_SRAM_A_predict[5] = 	next_col + 'b100;
										input_SRAM_A_predict[6] = 	next_col + 'b100;
									end
								end
								else
								begin
									input_SRAM_A_predict[0] = 	next_col + 'b100;
									input_SRAM_A_predict[1] = 	next_col + 'b100;
									input_SRAM_A_predict[2] = 	next_col + 'b100;
									input_SRAM_A_predict[3] = 	next_col + 'b100;
									input_SRAM_A_predict[4] = 	next_col + 'b100;
									input_SRAM_A_predict[5] = 	next_col + 'b100;
									input_SRAM_A_predict[6] = 	next_col + 'b100;
								end
							end
							else if(oversize_count == 'b100 || oversize_count == 'b101)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'b100;
								input_SRAM_A_predict[1] = 	next_col + 'b100;
								input_SRAM_A_predict[2] = 	next_col + 'b100;
								input_SRAM_A_predict[3] = 	next_col + 'b100;
								input_SRAM_A_predict[4] = 	next_col + 'b100;
								input_SRAM_A_predict[5] = 	next_col + 'b100;
								input_SRAM_A_predict[6] = 	next_col + 'b100;
							end
						end
						2'b01	:
						begin
							if(oversize_count == 'b000 || oversize_count == 'b001)
							begin
								input_SRAM_A_predict[0] = 	next_col;
								input_SRAM_A_predict[1] = 	next_col;
								input_SRAM_A_predict[2] = 	next_col;
								input_SRAM_A_predict[3] = 	next_col;
								input_SRAM_A_predict[4] = 	next_col;
								input_SRAM_A_predict[5] = 	next_col;
								input_SRAM_A_predict[6] = 	next_col;
							end
							else if(oversize_count == 'b010 || oversize_count == 'b011 || 
									oversize_count == 'b100 || oversize_count == 'b101)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd3;
								input_SRAM_A_predict[1] = 	next_col + 'd3;
								input_SRAM_A_predict[2] = 	next_col + 'd3;
								input_SRAM_A_predict[3] = 	next_col + 'd3;
								input_SRAM_A_predict[4] = 	next_col + 'd3;
								input_SRAM_A_predict[5] = 	next_col + 'd3;
								input_SRAM_A_predict[6] = 	next_col + 'd3;
							end
						end
						2'b10	:
						begin
							if(oversize_count == 'b000)
							begin
								input_SRAM_A_predict[0] = 	next_col;
								input_SRAM_A_predict[1] = 	next_col;
								input_SRAM_A_predict[2] = 	next_col;
								input_SRAM_A_predict[3] = 	next_col;
								input_SRAM_A_predict[4] = 	next_col;
								input_SRAM_A_predict[5] = 	next_col;
								input_SRAM_A_predict[6] = 	next_col;
							end
							else if(oversize_count == 'b001 || oversize_count == 'b010 || oversize_count == 'b011)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd2;
								input_SRAM_A_predict[1] = 	next_col + 'd2;
								input_SRAM_A_predict[2] = 	next_col + 'd2;
								input_SRAM_A_predict[3] = 	next_col + 'd2;
								input_SRAM_A_predict[4] = 	next_col + 'd2;
								input_SRAM_A_predict[5] = 	next_col + 'd2;
								input_SRAM_A_predict[6] = 	next_col + 'd2;
							end
							else if(oversize_count == 'b100 || oversize_count == 'b101)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd6;
								input_SRAM_A_predict[1] = 	next_col + 'd6;
								input_SRAM_A_predict[2] = 	next_col + 'd6;
								input_SRAM_A_predict[3] = 	next_col + 'd6;
								input_SRAM_A_predict[4] = 	next_col + 'd6;
								input_SRAM_A_predict[5] = 	next_col + 'd6;
								input_SRAM_A_predict[6] = 	next_col + 'd6;
							end
						end
						2'b11	:
						begin
							if(oversize_count == 'b000 || oversize_count == 'b001 || oversize_count == 'b010)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd1;
								input_SRAM_A_predict[1] = 	next_col + 'd1;
								input_SRAM_A_predict[2] = 	next_col + 'd1;
								input_SRAM_A_predict[3] = 	next_col + 'd1;
								input_SRAM_A_predict[4] = 	next_col + 'd1;
								input_SRAM_A_predict[5] = 	next_col + 'd1;
								input_SRAM_A_predict[6] = 	next_col + 'd1;
							end
							else if(oversize_count == 'b011 || oversize_count == 'b100 || oversize_count == 'b101)
							begin
								input_SRAM_A_predict[0] = 	next_col + 'd5;
								input_SRAM_A_predict[1] = 	next_col + 'd5;
								input_SRAM_A_predict[2] = 	next_col + 'd5;
								input_SRAM_A_predict[3] = 	next_col + 'd5;
								input_SRAM_A_predict[4] = 	next_col + 'd5;
								input_SRAM_A_predict[5] = 	next_col + 'd5;
								input_SRAM_A_predict[6] = 	next_col + 'd5;
							end
						end
					endcase
				end
			end
			else if(kernel_size == 'd1)
			begin
				if(stride == 'd1)
				begin
					if(filter_parting_map_times == 'd1)
						input_SRAM_A_predict[0] = 	next_col;
					else if(filter_parting_map_times == 'd4)
					begin
						input_SRAM_A_predict[0] = 	(next_row[0])?next_col+'d32:next_col;
						input_SRAM_A_predict[1] = 	(next_row[0])?next_col+'d32:next_col;
						input_SRAM_A_predict[2] = 	(next_row[0])?next_col+'d32:next_col;
						input_SRAM_A_predict[3] = 	(next_row[0])?next_col+'d32:next_col;
					end
					else if(filter_parting_map_times == 'd9)
					begin
						if(next_row % 'd3 == 0)
						begin
							input_SRAM_A_predict[0] =	next_col;
							input_SRAM_A_predict[1] =	next_col;
							input_SRAM_A_predict[2] =	next_col;
							input_SRAM_A_predict[3] =	next_col;
							input_SRAM_A_predict[4] =	next_col;
							input_SRAM_A_predict[5] =	next_col;
							input_SRAM_A_predict[6] =	next_col;
							input_SRAM_A_predict[7] =	next_col;
							input_SRAM_A_predict[8] =	next_col;
						end
						else if(next_row % 'd3 == 1)
						begin
							input_SRAM_A_predict[0] =	next_col + 'd20;
							input_SRAM_A_predict[1] =	next_col + 'd20;
							input_SRAM_A_predict[2] =	next_col + 'd20;
							input_SRAM_A_predict[3] =	next_col + 'd20;
							input_SRAM_A_predict[4] =	next_col + 'd20;
							input_SRAM_A_predict[5] =	next_col + 'd20;
							input_SRAM_A_predict[6] =	next_col + 'd20;
							input_SRAM_A_predict[7] =	next_col + 'd20;
							input_SRAM_A_predict[8] =	next_col + 'd20;
						end
						else if(next_row % 'd3 == 2)
						begin
							input_SRAM_A_predict[0] =	next_col + 'd40;
							input_SRAM_A_predict[1] =	next_col + 'd40;
							input_SRAM_A_predict[2] =	next_col + 'd40;
							input_SRAM_A_predict[3] =	next_col + 'd40;
							input_SRAM_A_predict[4] =	next_col + 'd40;
							input_SRAM_A_predict[5] =	next_col + 'd40;
							input_SRAM_A_predict[6] =	next_col + 'd40;
							input_SRAM_A_predict[7] =	next_col + 'd40;
							input_SRAM_A_predict[8] =	next_col + 'd40;
						end
					end
				end
			end
		end
	end

	//input_select ***
	// assign	input_select[0]	=	cur_row[2:0];
	// assign	input_select[1]	=	cur_row[2:0] + 'd1;
	// assign	input_select[2]	=	cur_row[2:0] + 'd2;

	always_comb
	begin
		if(rst)
		begin
			input_select[0]	=	'd0;
			input_select[1]	=	'd0;
			input_select[2]	=	'd0;
			input_select[3]	=	'd0;
			input_select[4]	=	'd0;
			input_select[5]	=	'd0;
			input_select[6]	=	'd0;
			input_select[7]	=	'd0;
			input_select[8]	=	'd0;
		end
		else
		begin
			if(kernel_size == 'd1)
			begin
				if(filter_parting_map_times == 'd1)
					input_select[0]	=	next_row;
				else if(filter_parting_map_times == 'd4)
				begin
					input_select[0]	=	(next_row >> 'd1);
					input_select[1]	=	(next_row >> 'd1) + 'd16;
					input_select[2]	=	(next_row >> 'd1) + 'd32;
					input_select[3]	=	(next_row >> 'd1) + 'd48;
				end
				else if(filter_parting_map_times == 'd9)
				begin
					input_select[0]	=	(next_row / 'd3);
					input_select[1]	=	(next_row / 'd3) + 'd7;
					input_select[2]	=	(next_row / 'd3) + 'd14;
					input_select[3]	=	(next_row / 'd3) + 'd21;
					input_select[4]	=	(next_row / 'd3) + 'd28;
					input_select[5]	=	(next_row / 'd3) + 'd35;
					input_select[6]	=	(next_row / 'd3) + 'd42;
					input_select[7]	=	(next_row / 'd3) + 'd49;
					input_select[8]	=	(next_row / 'd3) + 'd56;
				end
			end
			else if(kernel_size == 'd3)
			begin
				input_select[0]	=	next_row;
				input_select[1]	=	next_row + 'd1;
				input_select[2]	=	next_row + 'd2;
			end
			else if(kernel_size == 'd5)
			begin
				input_select[0]	=	next_row;
				input_select[1]	=	next_row + 'd1;
				input_select[2]	=	next_row + 'd2;
				input_select[3]	=	next_row + 'd3;
				input_select[4]	=	next_row + 'd4;
			end
			else if(kernel_size == 'd7)
			begin
				input_select[0]	=	next_row;
				input_select[1]	=	next_row + 'd1;
				input_select[2]	=	next_row + 'd2;
				input_select[3]	=	next_row + 'd3;
				input_select[4]	=	next_row + 'd4;
				input_select[5]	=	next_row + 'd5;
				input_select[6]	=	next_row + 'd6;
			end
			// else
			// begin
			// 	input_select[0]	=	next_row;
			// 	input_select[1]	=	next_row + 'd1;
			// 	input_select[2]	=	next_row + 'd2;
			// 	if(kernel_size == 'd5)
			// 	begin
			// 		input_select[3]	=	next_row + 'd3;
			// 		input_select[4]	=	next_row + 'd4;
			// 	end
			// 	else if(kernel_size == 'd7)
			// 	begin
			// 		input_select[3]	=	next_row + 'd3;
			// 		input_select[4]	=	next_row + 'd4;
			// 		input_select[5]	=	next_row + 'd5;
			// 		input_select[6]	=	next_row + 'd6;
			// 	end
			// end
		end
	end

	always_ff @(posedge clk, posedge rst)
	begin
		mem_access_input_select[0]	<=	input_select[0];
		mem_access_input_select[1]	<=	input_select[1];
		mem_access_input_select[2]	<=	input_select[2];
		mem_access_input_select[3]	<=	input_select[3];
		mem_access_input_select[4]	<=	input_select[4];
		mem_access_input_select[5]	<=	input_select[5];
		mem_access_input_select[6]	<=	input_select[6];
		mem_access_input_select[7]	<=	input_select[7];
		mem_access_input_select[8]	<=	input_select[8];
		mem_data_input_select[0]	<=	mem_access_input_select[0];
		mem_data_input_select[1]	<=	mem_access_input_select[1];
		mem_data_input_select[2]	<=	mem_access_input_select[2];
		mem_data_input_select[3]	<=	mem_access_input_select[3];
		mem_data_input_select[4]	<=	mem_access_input_select[4];
		mem_data_input_select[5]	<=	mem_access_input_select[5];
		mem_data_input_select[6]	<=	mem_access_input_select[6];
		mem_data_input_select[7]	<=	mem_access_input_select[7];
		mem_data_input_select[8]	<=	mem_access_input_select[8];
	end

	//input_SRAM_A
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_SRAM_A[i])
				input_SRAM_A[i]   <=	7'd0;
		end
		else if(kernel_size == 'd3)
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
						input_SRAM_A[i]	<=	7'b0;
				end
			end
			else
			begin
				foreach(input_SRAM_A[i])
					input_SRAM_A[i]	<=	7'b0;
			end
		end
		else if(kernel_size == 'd5)
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
					else if(i==input_select[3])
						input_SRAM_A[input_select[3]] <=  input_SRAM_A_predict[3][6:2];
					else if(i==input_select[4])
						input_SRAM_A[input_select[4]] <=  input_SRAM_A_predict[4][6:2];
					else
						input_SRAM_A[i]	<=	7'b0;
				end
			end
			else
			begin
				foreach(input_SRAM_A[i])
					input_SRAM_A[i]	<=	7'b0;
			end
		end  
		else if(kernel_size == 'd7)
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
					else if(i==input_select[3])
						input_SRAM_A[input_select[3]] <=  input_SRAM_A_predict[3][6:2];
					else if(i==input_select[4])
						input_SRAM_A[input_select[4]] <=  input_SRAM_A_predict[4][6:2];
					else if(i==input_select[5])
						input_SRAM_A[input_select[5]] <=  input_SRAM_A_predict[5][6:2];
					else if(i==input_select[6])
						input_SRAM_A[input_select[6]] <=  input_SRAM_A_predict[6][6:2];
					else
						input_SRAM_A[i]	<=	7'b0;
				end
			end
			else
			begin
				foreach(input_SRAM_A[i])
					input_SRAM_A[i]	<=	7'b0;
			end
		end  
		else if(kernel_size == 'd1)
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
					else if(i==input_select[3])
						input_SRAM_A[input_select[3]] <=  input_SRAM_A_predict[3][6:2];
					else if(i==input_select[4])
						input_SRAM_A[input_select[4]] <=  input_SRAM_A_predict[4][6:2];
					else if(i==input_select[5])
						input_SRAM_A[input_select[5]] <=  input_SRAM_A_predict[5][6:2];
					else if(i==input_select[6])
						input_SRAM_A[input_select[6]] <=  input_SRAM_A_predict[6][6:2];
					else if(i==input_select[7])
						input_SRAM_A[input_select[7]] <=  input_SRAM_A_predict[7][6:2];
					else if(i==input_select[8])
						input_SRAM_A[input_select[8]] <=  input_SRAM_A_predict[8][6:2];
					else
						input_SRAM_A[i]	<=	7'b0;
				end
			end
			else
			begin
				foreach(input_SRAM_A[i])
					input_SRAM_A[i]	<=	7'b0;
			end
		end  
	end

	//input_SRAM control
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_SRAM_CEN[i])
				input_SRAM_OEN[i]   <=	1'd1;
			// foreach(input_SRAM_WEN[i])
			// 	input_SRAM_WEN[i]   <=	1'd1;
			foreach(input_SRAM_CEN[i])
				input_SRAM_CEN[i]   <=	1'd0;
		end
		else if(kernel_size == 'd3)
		begin
			if(cur_state == S1 || next_state == S1)
			begin
				foreach(input_SRAM_OEN[i])
				begin
					if((i==input_select[0]||i==input_select[1]||i==input_select[2])&&(next_col==6'b0||next_col[1:0]==2'b10))
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
		else if(kernel_size == 'd5)
		begin
			if(cur_state == S1 || next_state == S1)
			begin
				foreach(input_SRAM_OEN[i])
				begin
					if((i==input_select[0]||i==input_select[1]||i==input_select[2]||i==input_select[3]||i==input_select[4]))
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
		else if(kernel_size == 'd7)
		begin
			if(cur_state == S1 || next_state == S1)
			begin
				foreach(input_SRAM_OEN[i])
				begin
					if((i==input_select[0]||i==input_select[1]||i==input_select[2]||i==input_select[3]||i==input_select[4]
					||i==input_select[5]||i==input_select[6]))
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
		else if(kernel_size == 'd1)
		begin
			if(cur_state == S1 || next_state == S1)
			begin
				foreach(input_SRAM_OEN[i])
				begin
					if(i==input_select[0]||i==input_select[1]||i==input_select[2]||i==input_select[3]||i==input_select[4]||
					i==input_select[5]||i==input_select[6]||i==input_select[7]||i==input_select[8])
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

	//ERROR 
	//filter_times
	//assign filter_times = 	6'd1;
	always_comb
	begin
		if(kernel_size == 'd3 || kernel_size == 'd1)
			filter_times = 	6'd0;
		else if(kernel_size == 'd5)
			filter_times = 	6'd2;
		else if(kernel_size == 'd7)
			filter_times = 	6'd5;
	end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			filter_times_now   <=	6'd0;
		else if(cur_state == IDLE)
			filter_times_now	<=	6'b0;
		else
		begin
			if(cur_state == S1 && tile_done == 1'b0)
			begin
				if(kernel_size == 'd3)
				begin
					if(stride =='d1)
					begin
						if(cur_col == (col_end-'d2) && cur_row == (row_end-'d2))
							filter_times_now <= filter_times_now + 1;
						else
							filter_times_now <= filter_times_now;
					end
					else if(stride =='d2)
					begin
						if(cur_col >= (col_end-'d3) && cur_row >= (row_end-'d3))
							filter_times_now <= filter_times_now + 1;
						else
							filter_times_now <= filter_times_now;
					end
				end
				else if(kernel_size == 'd5)
				begin
					if(stride =='d1)
					begin
						if(cur_col == (col_end-'d4) && cur_row == (row_end-'d4))
							filter_times_now <= filter_times_now + 1;
						else
							filter_times_now <= filter_times_now;
					end
					else if(stride =='d2)
					begin
						if(cur_col >= (col_end-'d5) && cur_row >= (row_end-'d5))
							filter_times_now <= filter_times_now + 1;
						else
							filter_times_now <= filter_times_now;
					end
				end
				else if(kernel_size == 'd7)
				begin
					if(stride =='d1)
					begin
						if(cur_col == (col_end-'d6) && cur_row == (row_end-'d6))
							filter_times_now <= filter_times_now + 1;
						else
							filter_times_now <= filter_times_now;
					end
					else if(stride =='d2)
					begin
						if(cur_col >= (col_end-'d7) && cur_row >= (row_end-'d7))
							filter_times_now <= filter_times_now + 1;
						else
							filter_times_now <= filter_times_now;
					end
				end
				else if(kernel_size == 'd1)
				begin
					if(cur_col == (col_end) && cur_row == (row_end))
						filter_times_now <= filter_times_now + 1;
					else
						filter_times_now <= filter_times_now;
				end
			end
			else
				filter_times_now   <=	filter_times_now;
		end 
	end

	//tile_done
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			oversize_part_done	<=	1'b0;
			tile_done   <=	1'b0;
			state_done	<=	1'b0;
		end
		else if(cur_state == IDLE)
		begin
			oversize_part_done	<=	1'b0;
			tile_done   <=	1'b0;
			state_done	<=	1'b0;
		end
		else if(kernel_size == 'd3)
		begin
			if(filter_times_now > filter_times)
				state_done	<=	1'b1;
			if(filter_times_now > filter_times && PE_out_row == 1'b0 && PE_out_col == 1'b0)
				tile_done   <=	1'b1;
		end
		else if(kernel_size == 'd5)
		begin
			if(stride == 'd1)
			begin
				if(cur_col == (col_end-'d4) && cur_row == (row_end-'d4))
					oversize_part_done   <=	1'b1;
				else 
					oversize_part_done   <=	1'b0;
			end
			else if(stride == 'd2)
			begin
				if(cur_col >= (col_end-'d5) && cur_row >= (row_end-'d5))
					oversize_part_done   <=	1'b1;
				else 
					oversize_part_done   <=	1'b0;
			end
			if(filter_times_now > filter_times && oversize_count == 'b10)
				tile_done   <=	1'b1;
			if(filter_times_now > filter_times && oversize_count == 'b10)
				state_done   <=	1'b1;
		end
		else if(kernel_size == 'd7)
		begin
			if(stride == 'd1)
			begin
				if(cur_col == (col_end-'d6) && cur_row == (row_end-'d6))
					oversize_part_done   <=	1'b1;
				else 
					oversize_part_done   <=	1'b0;
			end
			else if(stride == 'd2)
			begin
				if(cur_col >= (col_end-'d7) && cur_row >= (row_end-'d7))
					oversize_part_done   <=	1'b1;
				else 
					oversize_part_done   <=	1'b0;
			end
			if(filter_times_now > filter_times && oversize_count == 'b101)
				tile_done   <=	1'b1;
			if(filter_times_now > filter_times && oversize_count == 'b101)
				state_done   <=	1'b1;
		end
		else if(kernel_size == 'd1)
		begin
			if(filter_times_now > filter_times)
				state_done	<=	1'b1;
			if(filter_times_now > filter_times && PE_out_row == 1'b0 && PE_out_col == 1'b0)
				tile_done   <=	1'b1;
		end
		else 
		begin
			tile_done	<=	tile_done;
			state_done	<=	state_done;
		end
	end			

	//weight_SRAM_A
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(weight_SRAM_A[i])
				weight_SRAM_A[i]   <=	7'd0;
		end
		else if(kernel_size == 'd3)
		begin
			if(cur_state == S1 && filter_times_now <= filter_times)
			begin
				foreach(weight_SRAM_A[i])
					weight_SRAM_A[i]	<=	cur_channel[6:0];
			end
			else
			begin
				foreach(weight_SRAM_A[i])
					weight_SRAM_A[i]	<=	7'd0;
			end
		end
		else if(kernel_size == 'd5)
		begin
			if(cur_state == S1 && filter_times_now <= filter_times)
			begin
				foreach(weight_SRAM_A[i])
					weight_SRAM_A[i]	<=	(cur_channel[6:0]*'d3) + oversize_count;
			end
			else
			begin
				foreach(weight_SRAM_A[i])
					weight_SRAM_A[i]	<=	7'd0;
			end
		end  
		else if(kernel_size == 'd7)
		begin
			if(cur_state == S1 && filter_times_now <= filter_times)
			begin
				foreach(weight_SRAM_A[i])
					weight_SRAM_A[i]	<=	(cur_channel[6:0]*'d6) + oversize_count;
			end
			else
			begin
				foreach(weight_SRAM_A[i])
					weight_SRAM_A[i]	<=	7'd0;
			end
		end  
		else if(kernel_size == 'd1)
		begin
			if(cur_state == S1 && filter_times_now <= filter_times)
			begin
				// foreach(weight_SRAM_A[i])
				// 	weight_SRAM_A[i]	<=	cur_channel[6:0];
				if(filter_parting_map_times =='d1)
				begin
					foreach(weight_SRAM_A[i])
						weight_SRAM_A[i]	<=	cur_channel[6:0];
				end
				else if(filter_parting_map_times =='d4)
				begin
					foreach(weight_SRAM_A[i])
						weight_SRAM_A[i]	<=	cur_channel >> 'd2;
				end
				else if(filter_parting_map_times =='d9)
				begin
					foreach(weight_SRAM_A[i])
						weight_SRAM_A[i]	<=	cur_channel / 'd9;
				end
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
	always_ff @(posedge clk, posedge rst)
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
		else if(kernel_size == 'd3)
		begin
			if(cur_state == S1 && pre_state == IDLE)
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
		else if(kernel_size == 'd5)
		begin
			if(cur_state == S1 && pre_state == S3)
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
		else if(kernel_size == 'd7)
		begin
			//if(cur_state == S1 && pre_state == S3)
			if(cur_col == 'b0 && cur_row == 'b0)
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
		else if(kernel_size == 'd1)
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
	//assign output_SRAM_AB_prdict = (cur_row << 5) + (cur_row << 4) + (cur_row << 3) + (cur_row << 2) + (cur_row << 1) + cur_col;
	always_comb
	begin
		if(kernel_size == 'd3)
		begin
			if(pooling_enable)
			begin
				if(pooling_delay == 1'b1)
					output_SRAM_AB_prdict	=	cur_row	* 'd62 + cur_col;
				else
				begin
					if(cur_row[0] == 1'b1 && cur_col[0] == 1'b1)
						output_SRAM_AB_prdict	=	cur_row[5:1] * 'd62 + cur_col[5:1];
				end
			end
			else
			begin
				if(stride == 'd1)
					output_SRAM_AB_prdict	=	cur_row	* 'd62 + cur_col;
				else if(stride == 'd2)
					output_SRAM_AB_prdict	=	cur_row	* 'd31 + cur_col[5:1];
			end
		end
		else if(kernel_size == 'd5)
		begin
			if(stride == 'd1)
				output_SRAM_AB_prdict	=	cur_row	* 'd62 + cur_col;
			else if(stride == 'd2)
				output_SRAM_AB_prdict	=	cur_row	* 'd31 + cur_col[5:1];
		end
		else if(kernel_size == 'd7)
		begin
			if(stride == 'd1)
				output_SRAM_AB_prdict	=	cur_row	* 'd62 + cur_col;
			else if(stride == 'd2)
				output_SRAM_AB_prdict	=	cur_row	* 'd31 + cur_col[5:1];
		end
		else if(kernel_size == 'd1)
			output_SRAM_AB_prdict	=	cur_row	* 'd62 + cur_col;
	end
	//output_SRAM_AB
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(output_SRAM_AB[i])
				output_SRAM_AB[i]   <=	12'd0;
		end
		else if(kernel_size == 'd3)
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
		else if(kernel_size == 'd5)
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
		else if(kernel_size == 'd7)
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
		else if(kernel_size == 'd1)
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
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(output_SRAM_AA[i])
				output_SRAM_AA[i]   <=	12'd0;
		end
		else if(kernel_size == 'd3)
		begin
			if(pooling_enable)
			begin
				if(pooling_delay == 1'b1)
				begin
					if(PE_out_col[0] == 1'b1)
					begin
						if(PE_out_row[0] == 1'b1)
						begin
							foreach(output_SRAM_AA[i])
								output_SRAM_AA[i]	<=	(PE_out_row[5:1] * 'd62) + (PE_out_col[5:1]);
							foreach(output_SRAM_WEN[i])
								output_SRAM_WEN[i]	<=	(PE_done[i]||PE_out_col!='b0)?'b0:'b1;
						end
						else
						begin
							foreach(output_SRAM_AA[i])
								output_SRAM_AA[i]	<=	(PE_out_row[5:1] * 'd62) + (PE_out_col[5:1]);
							foreach(output_SRAM_WEN[i])
								output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
						end
					end
				end
				// if(PE_out_col[0] == 'b1 && pooling_delay == 1'b1)
				// begin
				// 	foreach(output_SRAM_AA[i])
				// 		output_SRAM_AA[i]	<=	(PE_out_row * 'd62) + (PE_out_col >> 'd1);
				// 	foreach(output_SRAM_WEN[i])
				// 		output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
				// end
				else
				begin
					foreach(output_SRAM_WEN[i])
						output_SRAM_WEN[i]	<=	'b1;
				end
			end
			else
			begin
				if(stride == 'd1)
				begin
					foreach(output_SRAM_AA[i])
						output_SRAM_AA[i]	<=	(PE_out_row * 'd62) + PE_out_col;
					foreach(output_SRAM_WEN[i])
						output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
				end
				else if(stride == 'd2)
				begin
					foreach(output_SRAM_AA[i])
						output_SRAM_AA[i]	<=	(PE_out_row * 'd31) + PE_out_col[5:1];
					foreach(output_SRAM_WEN[i])
						output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
				end
			end
		end
		else if(kernel_size == 'd5)
		begin
			if(stride == 'd1)
			begin
				foreach(output_SRAM_AA[i])
					output_SRAM_AA[i]	<=	(PE_out_row * 'd62) + PE_out_col;
				foreach(output_SRAM_WEN[i])
					output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
			end
			else if(stride == 'd2)
			begin
				foreach(output_SRAM_AA[i])
					output_SRAM_AA[i]	<=	(PE_out_row * 'd31) + PE_out_col[5:1];
				foreach(output_SRAM_WEN[i])
					output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
			end
		end
		else if(kernel_size == 'd7)
		begin
			if(stride == 'd1)
			begin
				foreach(output_SRAM_AA[i])
					output_SRAM_AA[i]	<=	(PE_out_row * 'd62) + PE_out_col;
				foreach(output_SRAM_WEN[i])
					output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
			end
			else if(stride == 'd2)
			begin
				foreach(output_SRAM_AA[i])
					output_SRAM_AA[i]	<=	(PE_out_row * 'd31) + PE_out_col[5:1];
				foreach(output_SRAM_WEN[i])
					output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
			end
		end
		else if(kernel_size == 'd1)
		begin
			foreach(output_SRAM_AA[i])
				output_SRAM_AA[i]	<=	(PE_out_row * 'd62) + PE_out_col;
			// foreach(output_SRAM_AA[i])
			// 	output_SRAM_AA[i]	<=	output_sram_addr[i];
			foreach(output_SRAM_WEN[i])
				output_SRAM_WEN[i]	<=	(PE_done[i])?'b0:'b1;
		end  
	end

	//output_SRAM_DI
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(output_SRAM_DI[i])
				output_SRAM_DI[i]	<=	16'b0;
		end
		else if(kernel_size == 'd3)
		begin
			if(pooling_enable)
			begin
				if(PE_out_col[0] == 'b1 && pooling_delay == 1'b1)
				begin
					if(PE_out_row[0] == 1'b0)
					begin
						foreach(output_SRAM_DI[i])
						begin
							if($signed(PE_data_psum_out[i]) > $signed(max_pooling_buffer1[i]))
								output_SRAM_DI[i]	<=	PE_data_psum_out[i];
							else
								output_SRAM_DI[i]	<=	max_pooling_buffer1[i];
						end
					end
					else
					begin
						foreach(output_SRAM_DI[i])
						begin
							if($signed(PE_data_psum_out[i]) > $signed(max_pooling_buffer1[i]))
							begin
								if($signed(max_pooling_buffer3[i]) > $signed(PE_data_psum_out[i]))
									output_SRAM_DI[i]	<=	max_pooling_buffer3[i];
								else
									output_SRAM_DI[i]	<=	PE_data_psum_out[i];
							end
							else
							begin
								if($signed(max_pooling_buffer3[i]) > $signed(max_pooling_buffer1[i]))
									output_SRAM_DI[i]	<=	max_pooling_buffer3[i];
								else
									output_SRAM_DI[i]	<=	max_pooling_buffer1[i];
							end
						end
					end
				end
			end
			else
			begin
				foreach(output_SRAM_DI[i])
					output_SRAM_DI[i]	<=	PE_data_psum_out[i];
			end
		end 
		else if(kernel_size == 'd5)
		begin
			foreach(output_SRAM_DI[i])
				output_SRAM_DI[i]	<=	PE_data_psum_out[i];
		end
		else if(kernel_size == 'd7)
		begin
			foreach(output_SRAM_DI[i])
				output_SRAM_DI[i]	<=	PE_data_psum_out[i];
		end
		else if(kernel_size == 'd1)
		begin
			foreach(output_SRAM_DI[i])
				output_SRAM_DI[i]	<=	PE_data_psum_out[i];
		end  
	end

	//output_SRAM control
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			output_SRAM_OEN   <=	1'd1;
			output_SRAM_CEN   <=	1'd0;
		end
		else if(kernel_size == 'd3)
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
		else if(kernel_size == 'd5)
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
		else if(kernel_size == 'd7)
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
		else if(kernel_size == 'd1)
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
	//output_SRAM_addr_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			output_SRAM_addr_write	<=	12'b0;
		else if(kernel_size == 'd3)
		begin
			if(cur_state == S1)
			begin
				if(stride == 'd1)
					output_SRAM_addr_write	<=	(cur_row * 'd62) + cur_col;
				else if(stride == 'd2)
					output_SRAM_addr_write	<=	(cur_row * 'd31) + cur_col[5:1];
			end
		end
		else if(kernel_size == 'd5)
		begin
			if(cur_state == S1)
			begin
				if(stride == 'd1)
					output_SRAM_addr_write	<=	(cur_row * 'd62) + cur_col;
				else if(stride == 'd2)
					output_SRAM_addr_write	<=	(cur_row * 'd31) + cur_col[5:1];
			end
		end
		else if(kernel_size == 'd7)
		begin
			if(cur_state == S1)
			begin
				if(stride == 'd1)
					output_SRAM_addr_write	<=	(cur_row * 'd62) + cur_col;
				else if(stride == 'd2)
					output_SRAM_addr_write	<=	(cur_row * 'd31) + cur_col[5:1];
			end
		end
		else if(kernel_size == 'd1)
		begin
			if(cur_state == S1)
				output_SRAM_addr_write	<=	(cur_row * 'd62) + cur_col;
		end
	end

	//max_pooling_buffer1
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(max_pooling_buffer1[i])
				max_pooling_buffer1[i]	<=	16'b0;
		end
		else if(pooling_enable == 1'b1 )
		begin
			if(pooling_delay == 1'b1 && PE_out_col[0] == 1'b0)
			begin
				foreach(max_pooling_buffer1[i])
					max_pooling_buffer1[i]	<=	PE_data_psum_out[i];
			end
		end
	end

	//pooling_delay
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			pooling_delay	<=	1'b0;
		else if(pooling_enable)
		begin
			if(kernel_size == 'd3)
			begin
				if(cur_state == S1)
				begin
					pooling_delay	<=	~pooling_delay;
				end
				else
				begin
					if(PE_out_col!='b0 && PE_out_row!= 'b0)
						pooling_delay	<=	~pooling_delay;
					else
						pooling_delay	<=	1'b0;
				end
			end
		end
	end

	//PE_psum_addr
	always_ff @(posedge clk, posedge rst)
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
				mem_data_addr[i]<=	output_SRAM_addr_write;
		end
	end

	//PE data
	//weight
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer i,j;
			// for(i=0;i<32;i++)
			// begin
			// 	for(j=0;j<9;j++)
			// 	begin
			// 		PE_data_weight[i][j]	<=	32'b0;
			// 	end
			// end
			// foreach(PE_data_weight[i])
			// begin
			// 	foreach(PE_data_weight[i][j])
			// 		PE_data_weight[i][j]	<=	32'b0;
			// end
		end
		else
		begin
			if(kernel_size == 'd3)
			begin
				if(pooling_enable)
				begin
					if(cur_state == S1 && mem_access_col == 'b0 && mem_access_row =='b0)
					begin
						foreach(PE_data_weight[i])
						begin
							PE_data_weight[i][0] = weight_SRAM_DO[i*'d9 + 'd0];
							PE_data_weight[i][1] = weight_SRAM_DO[i*'d9 + 'd1];
							PE_data_weight[i][2] = weight_SRAM_DO[i*'d9 + 'd2];
							PE_data_weight[i][3] = weight_SRAM_DO[i*'d9 + 'd3];
							PE_data_weight[i][4] = weight_SRAM_DO[i*'d9 + 'd4];
							PE_data_weight[i][5] = weight_SRAM_DO[i*'d9 + 'd5];
							PE_data_weight[i][6] = weight_SRAM_DO[i*'d9 + 'd6];
							PE_data_weight[i][7] = weight_SRAM_DO[i*'d9 + 'd7];
							PE_data_weight[i][8] = weight_SRAM_DO[i*'d9 + 'd8];
						end	
					end
				end
				else 
				begin
					if((cur_state == S1 && mem_access_col == 'b1 && mem_access_row =='b0 && stride == 'd1)||
					(cur_state == S1 && mem_access_col == 'b10 && mem_access_row =='b0 && stride == 'd2))
					begin
						foreach(PE_data_weight[i])
						begin
							PE_data_weight[i][0] = weight_SRAM_DO[i*'d9 + 'd0];
							PE_data_weight[i][1] = weight_SRAM_DO[i*'d9 + 'd1];
							PE_data_weight[i][2] = weight_SRAM_DO[i*'d9 + 'd2];
							PE_data_weight[i][3] = weight_SRAM_DO[i*'d9 + 'd3];
							PE_data_weight[i][4] = weight_SRAM_DO[i*'d9 + 'd4];
							PE_data_weight[i][5] = weight_SRAM_DO[i*'d9 + 'd5];
							PE_data_weight[i][6] = weight_SRAM_DO[i*'d9 + 'd6];
							PE_data_weight[i][7] = weight_SRAM_DO[i*'d9 + 'd7];
							PE_data_weight[i][8] = weight_SRAM_DO[i*'d9 + 'd8];
						end	
					end
				end
			end
			else if(kernel_size == 'd5)
			begin
				if(cur_state == S1)
				begin
					if(oversize_count != 'b10  && ((mem_access_col == 'b1 && mem_access_row =='b0 && stride =='d1) || 
												(mem_access_col == 'b10 && mem_access_row =='b0 && stride =='d2)))
					begin
						foreach(PE_data_weight[i])
						begin
							PE_data_weight[i][0] = weight_SRAM_DO[i*'d9 + 'd0];
							PE_data_weight[i][1] = weight_SRAM_DO[i*'d9 + 'd1];
							PE_data_weight[i][2] = weight_SRAM_DO[i*'d9 + 'd2];
							PE_data_weight[i][3] = weight_SRAM_DO[i*'d9 + 'd3];
							PE_data_weight[i][4] = weight_SRAM_DO[i*'d9 + 'd4];
							PE_data_weight[i][5] = weight_SRAM_DO[i*'d9 + 'd5];
							PE_data_weight[i][6] = weight_SRAM_DO[i*'d9 + 'd6];
							PE_data_weight[i][7] = weight_SRAM_DO[i*'d9 + 'd7];
							PE_data_weight[i][8] = weight_SRAM_DO[i*'d9 + 'd8];
						end	
					end
					else if(cur_col == 'b0 && cur_row =='b0 && oversize_count == 'b10 && next_state != 'd2)
					begin
						foreach(PE_data_weight[i])
						begin
							PE_data_weight[i][0] = weight_SRAM_DO[i*'d9 + 'd0];
							PE_data_weight[i][1] = weight_SRAM_DO[i*'d9 + 'd1];
							PE_data_weight[i][2] = weight_SRAM_DO[i*'d9 + 'd2];
							PE_data_weight[i][3] = weight_SRAM_DO[i*'d9 + 'd3];
							PE_data_weight[i][4] = weight_SRAM_DO[i*'d9 + 'd4];
							PE_data_weight[i][5] = weight_SRAM_DO[i*'d9 + 'd5];
							PE_data_weight[i][6] = weight_SRAM_DO[i*'d9 + 'd6];
							PE_data_weight[i][7] = weight_SRAM_DO[i*'d9 + 'd7];
							PE_data_weight[i][8] = weight_SRAM_DO[i*'d9 + 'd8];
						end	
					end
				end
			end
			else if(kernel_size == 'd7)
			begin
				if(cur_state == S1)
				begin
					if(oversize_count != 'b11  && ((mem_access_col == 'b1 && mem_access_row =='b0 && stride =='d1) || 
												(mem_access_col == 'b10 && mem_access_row =='b0 && stride =='d2)))
					begin
						foreach(PE_data_weight[i])
						begin
							PE_data_weight[i][0] = weight_SRAM_DO[i*'d9 + 'd0];
							PE_data_weight[i][1] = weight_SRAM_DO[i*'d9 + 'd1];
							PE_data_weight[i][2] = weight_SRAM_DO[i*'d9 + 'd2];
							PE_data_weight[i][3] = weight_SRAM_DO[i*'d9 + 'd3];
							PE_data_weight[i][4] = weight_SRAM_DO[i*'d9 + 'd4];
							PE_data_weight[i][5] = weight_SRAM_DO[i*'d9 + 'd5];
							PE_data_weight[i][6] = weight_SRAM_DO[i*'d9 + 'd6];
							PE_data_weight[i][7] = weight_SRAM_DO[i*'d9 + 'd7];
							PE_data_weight[i][8] = weight_SRAM_DO[i*'d9 + 'd8];
						end	
					end
					else if(cur_col == 'b0 && cur_row =='b0 && oversize_count == 'b11 && next_state != 'd2)
					begin
						foreach(PE_data_weight[i])
						begin
							PE_data_weight[i][0] = weight_SRAM_DO[i*'d9 + 'd0];
							PE_data_weight[i][1] = weight_SRAM_DO[i*'d9 + 'd1];
							PE_data_weight[i][2] = weight_SRAM_DO[i*'d9 + 'd2];
							PE_data_weight[i][3] = weight_SRAM_DO[i*'d9 + 'd3];
							PE_data_weight[i][4] = weight_SRAM_DO[i*'d9 + 'd4];
							PE_data_weight[i][5] = weight_SRAM_DO[i*'d9 + 'd5];
							PE_data_weight[i][6] = weight_SRAM_DO[i*'d9 + 'd6];
							PE_data_weight[i][7] = weight_SRAM_DO[i*'d9 + 'd7];
							PE_data_weight[i][8] = weight_SRAM_DO[i*'d9 + 'd8];
						end	
					end
				end
			end
			else if(kernel_size == 'd1)
			begin
				if(cur_state == S1 && mem_access_col == 'b1 && mem_access_row =='b0)
				begin
					if(filter_parting_map_times == 'd9)
					begin
						foreach(PE_data_weight[i])
						begin
							PE_data_weight[i][0] = weight_SRAM_DO[i*'d9 + 'd0];
							PE_data_weight[i][1] = weight_SRAM_DO[i*'d9 + 'd1];
							PE_data_weight[i][2] = weight_SRAM_DO[i*'d9 + 'd2];
							PE_data_weight[i][3] = weight_SRAM_DO[i*'d9 + 'd3];
							PE_data_weight[i][4] = weight_SRAM_DO[i*'d9 + 'd4];
							PE_data_weight[i][5] = weight_SRAM_DO[i*'d9 + 'd5];
							PE_data_weight[i][6] = weight_SRAM_DO[i*'d9 + 'd6];
							PE_data_weight[i][7] = weight_SRAM_DO[i*'d9 + 'd7];
							PE_data_weight[i][8] = weight_SRAM_DO[i*'d9 + 'd8];
						end	
					end
					else if(filter_parting_map_times == 'd4)
					begin
						foreach(PE_data_weight[i])
						begin
							PE_data_weight[i][0] = weight_SRAM_DO[i*'d9 + 'd0];
							PE_data_weight[i][1] = weight_SRAM_DO[i*'d9 + 'd1];
							PE_data_weight[i][2] = weight_SRAM_DO[i*'d9 + 'd2];
							PE_data_weight[i][3] = weight_SRAM_DO[i*'d9 + 'd3];
							PE_data_weight[i][4] = 8'd0;
							PE_data_weight[i][5] = 8'd0;
							PE_data_weight[i][6] = 8'd0;
							PE_data_weight[i][7] = 8'd0;
							PE_data_weight[i][8] = 8'd0;
						end	
					end
					else if(filter_parting_map_times == 'd1)
					begin
						foreach(PE_data_weight[i])
						begin
							PE_data_weight[i][0] = weight_SRAM_DO[i*'d9 + 'd0];
							PE_data_weight[i][1] = 8'd0;
							PE_data_weight[i][2] = 8'd0;
							PE_data_weight[i][3] = 8'd0;
							PE_data_weight[i][4] = 8'd0;
							PE_data_weight[i][5] = 8'd0;
							PE_data_weight[i][6] = 8'd0;
							PE_data_weight[i][7] = 8'd0;
							PE_data_weight[i][8] = 8'd0;
						end	
					end
				end
			end
		end
	end


	//data_buffer 2
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(data_buffer[i])
				data_buffer[i]	<=	8'b0;
		end
		else
		begin
			if(kernel_size == 'd3 && ((pooling_enable=='b1 && pooling_delay)||(pooling_enable=='b0)))
			begin
				if(stride == 'd1 )
				begin
					if(mem_access_col == 6'b0)
					begin
						data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
						data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
						data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
						data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

						data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
						data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
						data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
						data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

						data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
						data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
						data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
						data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];
					end
					else if(mem_access_col[1:0] == 2'b00 ||
							mem_access_col[1:0] == 2'b01 || mem_access_col[1:0] == 2'b11)
					begin
						data_buffer[0]	<=	data_buffer[1];
						data_buffer[1]	<=	data_buffer[2];
						data_buffer[2]	<=	data_buffer[3];
						data_buffer[3]	<=	data_buffer[4];
						data_buffer[4]	<=	data_buffer[5];

						data_buffer[6]	<=	data_buffer[7];
						data_buffer[7]	<=	data_buffer[8];
						data_buffer[8]	<=	data_buffer[9];
						data_buffer[9]	<=	data_buffer[10];
						data_buffer[10]	<=	data_buffer[11];

						data_buffer[12]	<=	data_buffer[13];
						data_buffer[13]	<=	data_buffer[14];
						data_buffer[14]	<=	data_buffer[15];
						data_buffer[15]	<=	data_buffer[16];
						data_buffer[16]	<=	data_buffer[17];
					end
					else 
					begin
						data_buffer[0]	<=	data_buffer[1];
						data_buffer[1]	<=	data_buffer[2];
						data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
						data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
						data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
						data_buffer[5]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

						data_buffer[6]	<=	data_buffer[7];
						data_buffer[7]	<=	data_buffer[8];
						data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
						data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
						data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
						data_buffer[11]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

						data_buffer[12]	<=	data_buffer[13];
						data_buffer[13]	<=	data_buffer[14];
						data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
						data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
						data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
						data_buffer[17]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];
					end
				end
				else if(stride == 'd2 )
				begin
					case(mem_access_col[1:0])
						2'b00:
						begin
							if(mem_access_col == 6'b0)
							begin
								data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];
							end
							else
							begin
								data_buffer[0]	<=	data_buffer[2];
								data_buffer[1]	<=	data_buffer[3];
								data_buffer[2]	<=	data_buffer[4];
								data_buffer[3]	<=	data_buffer[5];

								data_buffer[6]	<=	data_buffer[8];
								data_buffer[7]	<=	data_buffer[9];
								data_buffer[8]	<=	data_buffer[10];
								data_buffer[9]	<=	data_buffer[11];

								data_buffer[12]	<=	data_buffer[14];
								data_buffer[13]	<=	data_buffer[15];
								data_buffer[14]	<=	data_buffer[16];
								data_buffer[15]	<=	data_buffer[17];
							end
						end
						2'b01:
						begin
							;
						end
						2'b10:
						begin
							data_buffer[0]	<=	data_buffer[2];
							data_buffer[1]	<=	data_buffer[3];
							data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
							data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
							data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
							data_buffer[5]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

							data_buffer[6]	<=	data_buffer[8];
							data_buffer[7]	<=	data_buffer[9];
							data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
							data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
							data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
							data_buffer[11]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

							data_buffer[12]	<=	data_buffer[14];
							data_buffer[13]	<=	data_buffer[15];
							data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
							data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
							data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
							data_buffer[17]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];
						end
						2'b11:
						begin
							;
						end
					endcase
				end
			end
			else if(kernel_size == 'd5)
			begin
				if(stride == 'd1)
				begin
					if(mem_access_col == 6'b0)
					begin
						case(oversize_count)
							'b00:
							begin
								data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
							end
							'b01:
							begin
								data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
							end
							'b10:
							begin
								if(mem_access_oversize_first == 'b1)
								begin
									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];
									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
								end
								else
								begin
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
									data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
									data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
									data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
									data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
									data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
									data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
									data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
									data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
									data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
									data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
								end
							end
						endcase
					end
					else if((mem_access_col[1:0] == 2'b00 && (oversize_count == 'b0 || oversize_count == 'b1))||
							(mem_access_col[1:0] == 2'b01 && (oversize_count == 'b0 || oversize_count == 'b10))||
							(mem_access_col[1:0] == 2'b10 && (oversize_count == 'b0 || oversize_count == 'b1 || oversize_count == 'b10))||
							(mem_access_col[1:0] == 2'b11 && (oversize_count == 'b1 || oversize_count == 'b10)))
					begin
						data_buffer[0]	<=	data_buffer[1];
						data_buffer[1]	<=	data_buffer[2];
						data_buffer[2]	<=	data_buffer[3];
						data_buffer[3]	<=	data_buffer[4];
						data_buffer[4]	<=	data_buffer[5];

						data_buffer[6]	<=	data_buffer[7];
						data_buffer[7]	<=	data_buffer[8];
						data_buffer[8]	<=	data_buffer[9];
						data_buffer[9]	<=	data_buffer[10];
						data_buffer[10]	<=	data_buffer[11];

						data_buffer[12]	<=	data_buffer[13];
						data_buffer[13]	<=	data_buffer[14];
						data_buffer[14]	<=	data_buffer[15];
						data_buffer[15]	<=	data_buffer[16];
						data_buffer[16]	<=	data_buffer[17];

						data_buffer[18]	<=	data_buffer[19];
						data_buffer[19]	<=	data_buffer[20];
						data_buffer[20]	<=	data_buffer[21];
						data_buffer[21]	<=	data_buffer[22];
						data_buffer[22]	<=	data_buffer[23];

						data_buffer[24]	<=	data_buffer[25];
						data_buffer[25]	<=	data_buffer[26];
						data_buffer[26]	<=	data_buffer[27];
						data_buffer[27]	<=	data_buffer[28];
						data_buffer[28]	<=	data_buffer[29];
					end
					else if((mem_access_col[1:0] == 2'b00 && oversize_count == 'b10)||
							(mem_access_col[1:0] == 2'b11 && oversize_count == 'b0))
					begin
						data_buffer[0]	<=	data_buffer[1];
						data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
						data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
						data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
						data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

						data_buffer[6]	<=	data_buffer[7];
						data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
						data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
						data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
						data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

						data_buffer[12]	<=	data_buffer[13];
						data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
						data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
						data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
						data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

						data_buffer[18]	<=	data_buffer[19];
						data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
						data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
						data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
						data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

						data_buffer[24]	<=	data_buffer[25];
						data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
						data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
						data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
						data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
					end
					else if(mem_access_col[1:0] == 2'b01 && oversize_count == 'b1)
					begin
						data_buffer[0]	<=	data_buffer[1];
						data_buffer[1]	<=	data_buffer[2];
						data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
						data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
						data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
						data_buffer[5]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

						data_buffer[6]	<=	data_buffer[7];
						data_buffer[7]	<=	data_buffer[8];
						data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
						data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
						data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
						data_buffer[11]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

						data_buffer[12]	<=	data_buffer[13];
						data_buffer[13]	<=	data_buffer[14];
						data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
						data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
						data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
						data_buffer[17]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

						data_buffer[18]	<=	data_buffer[19];
						data_buffer[19]	<=	data_buffer[20];
						data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
						data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
						data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
						data_buffer[23]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

						data_buffer[24]	<=	data_buffer[25];
						data_buffer[25]	<=	data_buffer[26];
						data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
						data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
						data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
						data_buffer[29]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
					end
				end
				else if(stride == 'd2)
				begin
					if(mem_access_col == 6'b0 && oversize_count == 'b10)
					begin
						if(mem_access_oversize_first == 'b1)
						begin
							data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];
							data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
						end
						else
						begin
							data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
							data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
							data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
							data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

							data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
							data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
							data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
							data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

							data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
							data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
							data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
							data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

							data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
							data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
							data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
							data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

							data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
							data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
							data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
							data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
						end
					end
					else if(mem_access_col == 6'b0 && oversize_count == 'b1)
					begin
						data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
						data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
						data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

						data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
						data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
						data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

						data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
						data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
						data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

						data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
						data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
						data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

						data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
						data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
						data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
					end
					else if(mem_access_col[1:0] == 2'b00 && oversize_count == 'b0)
					begin
						data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
						data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
						data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
						data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

						data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
						data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
						data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
						data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

						data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
						data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
						data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
						data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

						data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
						data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
						data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
						data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

						data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
						data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
						data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
						data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
					end
					else if((mem_access_col[1:0] == 2'b00 && oversize_count == 'b1)||
							(mem_access_col[1:0] == 2'b10 && oversize_count == 'b0)||
							(mem_access_col[1:0] == 2'b10 && oversize_count == 'b10))
					begin
						data_buffer[0]	<=	data_buffer[2];
						data_buffer[1]	<=	data_buffer[3];
						data_buffer[2]	<=	data_buffer[4];

						data_buffer[6]	<=	data_buffer[8];
						data_buffer[7]	<=	data_buffer[9];
						data_buffer[8]	<=	data_buffer[10];

						data_buffer[12]	<=	data_buffer[14];
						data_buffer[13]	<=	data_buffer[15];
						data_buffer[14]	<=	data_buffer[16];

						data_buffer[18]	<=	data_buffer[20];
						data_buffer[19]	<=	data_buffer[21];
						data_buffer[20]	<=	data_buffer[22];

						data_buffer[24]	<=	data_buffer[26];
						data_buffer[25]	<=	data_buffer[27];
						data_buffer[26]	<=	data_buffer[28];
					end
					else if((mem_access_col[1:0] == 2'b00 && oversize_count == 'b10)||
							(mem_access_col[1:0] == 2'b10 && oversize_count == 'b1))
					begin
						data_buffer[0]	<=	data_buffer[2];
						data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
						data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
						data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
						data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

						data_buffer[6]	<=	data_buffer[8];
						data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
						data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
						data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
						data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

						data_buffer[12]	<=	data_buffer[14];
						data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
						data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
						data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
						data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

						data_buffer[18]	<=	data_buffer[20];
						data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
						data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
						data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
						data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

						data_buffer[24]	<=	data_buffer[26];
						data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
						data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
						data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
						data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];
					end
				end
			end
			else if(kernel_size == 'd7)
			begin
				if(stride == 'd1)
				begin
					case(mem_access_col[1:0])
						2'b00:
						begin
							if(oversize_count == 'b0)
							begin
								if(mem_access_col == 6'b0)
								begin
									data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
									data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
									data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
									data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
									data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
									data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
									data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
									data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[1];
									data_buffer[1]	<=	data_buffer[2];
									data_buffer[2]	<=	data_buffer[3];
									data_buffer[3]	<=	data_buffer[4];

									data_buffer[6]	<=	data_buffer[7];
									data_buffer[7]	<=	data_buffer[8];
									data_buffer[8]	<=	data_buffer[9];
									data_buffer[9]	<=	data_buffer[10];

									data_buffer[12]	<=	data_buffer[13];
									data_buffer[13]	<=	data_buffer[14];
									data_buffer[14]	<=	data_buffer[15];
									data_buffer[15]	<=	data_buffer[16];

									data_buffer[18]	<=	data_buffer[19];
									data_buffer[19]	<=	data_buffer[20];
									data_buffer[20]	<=	data_buffer[21];
									data_buffer[21]	<=	data_buffer[22];

									data_buffer[24]	<=	data_buffer[25];
									data_buffer[25]	<=	data_buffer[26];
									data_buffer[26]	<=	data_buffer[27];
									data_buffer[27]	<=	data_buffer[28];
									
									data_buffer[30]	<=	data_buffer[31];
									data_buffer[31]	<=	data_buffer[32];
									data_buffer[32]	<=	data_buffer[33];
									data_buffer[33]	<=	data_buffer[34];

									data_buffer[36]	<=	data_buffer[37];
									data_buffer[37]	<=	data_buffer[38];
									data_buffer[38]	<=	data_buffer[39];
									data_buffer[39]	<=	data_buffer[40];
								end
							end
							else if(oversize_count == 'b1)
							begin
								if(mem_access_col == 6'b0)
								begin
									data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[1];
									data_buffer[1]	<=	data_buffer[2];
									data_buffer[2]	<=	data_buffer[3];

									data_buffer[6]	<=	data_buffer[7];
									data_buffer[7]	<=	data_buffer[8];
									data_buffer[8]	<=	data_buffer[9];

									data_buffer[12]	<=	data_buffer[13];
									data_buffer[13]	<=	data_buffer[14];
									data_buffer[14]	<=	data_buffer[15];

									data_buffer[18]	<=	data_buffer[19];
									data_buffer[19]	<=	data_buffer[20];
									data_buffer[20]	<=	data_buffer[21];

									data_buffer[24]	<=	data_buffer[25];
									data_buffer[25]	<=	data_buffer[26];
									data_buffer[26]	<=	data_buffer[27];

									data_buffer[30]	<=	data_buffer[31];
									data_buffer[31]	<=	data_buffer[32];
									data_buffer[32]	<=	data_buffer[33];

									data_buffer[36]	<=	data_buffer[37];
									data_buffer[37]	<=	data_buffer[38];
									data_buffer[38]	<=	data_buffer[39];
								end
							end
							else if(oversize_count == 'b10)
							begin
								if(mem_access_col == 6'b0)
								begin
									data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[1];
									data_buffer[1]	<=	data_buffer[2];

									data_buffer[6]	<=	data_buffer[7];
									data_buffer[7]	<=	data_buffer[8];

									data_buffer[12]	<=	data_buffer[13];
									data_buffer[13]	<=	data_buffer[14];

									data_buffer[18]	<=	data_buffer[19];
									data_buffer[19]	<=	data_buffer[20];

									data_buffer[24]	<=	data_buffer[25];
									data_buffer[25]	<=	data_buffer[26];

									data_buffer[30]	<=	data_buffer[31];
									data_buffer[31]	<=	data_buffer[32];

									data_buffer[36]	<=	data_buffer[37];
									data_buffer[37]	<=	data_buffer[38];
								end
							end
							else if(oversize_count == 'b11)
							begin
								if(mem_access_col == 6'b0)
								begin
									if(mem_access_oversize_first == 'b1)
									begin
										data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
									end
									else
									begin
										data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
										data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
										data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
										data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

										data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
										data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
										data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
										data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

										data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
										data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
										data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
										data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

										data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
										data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
										data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
										data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

										data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
										data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
										data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
										data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

										data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
										data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
										data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
										data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

										data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
										data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
										data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
										data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
									end
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[1];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
									data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
									data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	data_buffer[7];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
									data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
									data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	data_buffer[13];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
									data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
									data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	data_buffer[19];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
									data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
									data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	data_buffer[25];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
									data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
									data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	data_buffer[31];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
									data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
									data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	data_buffer[37];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
									data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
									data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
							end
							else if(oversize_count == 'b100)
							begin
								if(mem_access_col == 6'b0)
								begin
									data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[1];
									data_buffer[1]	<=	data_buffer[2];
									data_buffer[2]	<=	data_buffer[3];

									data_buffer[6]	<=	data_buffer[7];
									data_buffer[7]	<=	data_buffer[8];
									data_buffer[8]	<=	data_buffer[9];

									data_buffer[12]	<=	data_buffer[13];
									data_buffer[13]	<=	data_buffer[14];
									data_buffer[14]	<=	data_buffer[15];

									data_buffer[18]	<=	data_buffer[19];
									data_buffer[19]	<=	data_buffer[20];
									data_buffer[20]	<=	data_buffer[21];

									data_buffer[24]	<=	data_buffer[25];
									data_buffer[25]	<=	data_buffer[26];
									data_buffer[26]	<=	data_buffer[27];

									data_buffer[30]	<=	data_buffer[31];
									data_buffer[31]	<=	data_buffer[32];
									data_buffer[32]	<=	data_buffer[33];

									data_buffer[36]	<=	data_buffer[37];
									data_buffer[37]	<=	data_buffer[38];
									data_buffer[38]	<=	data_buffer[39];
								end
							end
							else if(oversize_count == 'b101)
							begin
								if(mem_access_col == 6'b0)
								begin
									data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[1];
									data_buffer[1]	<=	data_buffer[2];

									data_buffer[6]	<=	data_buffer[7];
									data_buffer[7]	<=	data_buffer[8];

									data_buffer[12]	<=	data_buffer[13];
									data_buffer[13]	<=	data_buffer[14];

									data_buffer[18]	<=	data_buffer[19];
									data_buffer[19]	<=	data_buffer[20];

									data_buffer[24]	<=	data_buffer[25];
									data_buffer[25]	<=	data_buffer[26];

									data_buffer[30]	<=	data_buffer[31];
									data_buffer[31]	<=	data_buffer[32];

									data_buffer[36]	<=	data_buffer[37];
									data_buffer[37]	<=	data_buffer[38];
								end
							end
						end
						2'b01:
						begin
							if(oversize_count == 'b0)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];
								data_buffer[2]	<=	data_buffer[3];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];
								data_buffer[8]	<=	data_buffer[9];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];
								data_buffer[14]	<=	data_buffer[15];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];
								data_buffer[20]	<=	data_buffer[21];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];
								data_buffer[26]	<=	data_buffer[27];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];
								data_buffer[32]	<=	data_buffer[33];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
								data_buffer[38]	<=	data_buffer[39];
							end
							else if(oversize_count == 'b1)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
							end
							else if(oversize_count == 'b10)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
							else if(oversize_count == 'b11)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];
								data_buffer[2]	<=	data_buffer[3];
								data_buffer[3]	<=	data_buffer[4];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];
								data_buffer[8]	<=	data_buffer[9];
								data_buffer[9]	<=	data_buffer[10];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];
								data_buffer[14]	<=	data_buffer[15];
								data_buffer[15]	<=	data_buffer[16];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];
								data_buffer[20]	<=	data_buffer[21];
								data_buffer[21]	<=	data_buffer[22];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];
								data_buffer[26]	<=	data_buffer[27];
								data_buffer[27]	<=	data_buffer[28];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];
								data_buffer[32]	<=	data_buffer[33];
								data_buffer[33]	<=	data_buffer[34];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
								data_buffer[38]	<=	data_buffer[39];
								data_buffer[39]	<=	data_buffer[40];
							end
							else if(oversize_count == 'b100)
							begin
								data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
							else if(oversize_count == 'b101)
							begin
								data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
						end
						2'b10:
						begin
							if(oversize_count == 'b0)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
							end
							else if(oversize_count == 'b1)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
							else if(oversize_count == 'b10)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];
								data_buffer[2]	<=	data_buffer[3];
								data_buffer[3]	<=	data_buffer[4];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];
								data_buffer[8]	<=	data_buffer[9];
								data_buffer[9]	<=	data_buffer[10];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];
								data_buffer[14]	<=	data_buffer[15];
								data_buffer[15]	<=	data_buffer[16];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];
								data_buffer[20]	<=	data_buffer[21];
								data_buffer[21]	<=	data_buffer[22];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];
								data_buffer[26]	<=	data_buffer[27];
								data_buffer[27]	<=	data_buffer[28];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];
								data_buffer[32]	<=	data_buffer[33];
								data_buffer[33]	<=	data_buffer[34];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
								data_buffer[38]	<=	data_buffer[39];
								data_buffer[39]	<=	data_buffer[40];
							end
							else if(oversize_count == 'b11)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];
								data_buffer[2]	<=	data_buffer[3];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];
								data_buffer[8]	<=	data_buffer[9];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];
								data_buffer[14]	<=	data_buffer[15];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];
								data_buffer[20]	<=	data_buffer[21];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];
								data_buffer[26]	<=	data_buffer[27];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];
								data_buffer[32]	<=	data_buffer[33];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
								data_buffer[38]	<=	data_buffer[39];
							end
							else if(oversize_count == 'b100)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
							else if(oversize_count == 'b101)
							begin
								data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
						end
						2'b11:
						begin
							if(oversize_count == 'b0)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
							else if(oversize_count == 'b1)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];
								data_buffer[2]	<=	data_buffer[3];
								data_buffer[3]	<=	data_buffer[4];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];
								data_buffer[8]	<=	data_buffer[9];
								data_buffer[9]	<=	data_buffer[10];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];
								data_buffer[14]	<=	data_buffer[15];
								data_buffer[15]	<=	data_buffer[16];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];
								data_buffer[20]	<=	data_buffer[21];
								data_buffer[21]	<=	data_buffer[22];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];
								data_buffer[26]	<=	data_buffer[27];
								data_buffer[27]	<=	data_buffer[28];
								
								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];
								data_buffer[32]	<=	data_buffer[33];
								data_buffer[33]	<=	data_buffer[34];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
								data_buffer[38]	<=	data_buffer[39];
								data_buffer[39]	<=	data_buffer[40];
							end
							else if(oversize_count == 'b10)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];
								data_buffer[2]	<=	data_buffer[3];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];
								data_buffer[8]	<=	data_buffer[9];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];
								data_buffer[14]	<=	data_buffer[15];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];
								data_buffer[20]	<=	data_buffer[21];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];
								data_buffer[26]	<=	data_buffer[27];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];
								data_buffer[32]	<=	data_buffer[33];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
								data_buffer[38]	<=	data_buffer[39];
							end
							else if(oversize_count == 'b11)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[5]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[11]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[17]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[23]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[29]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[35]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[41]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];								
							end
							else if(oversize_count == 'b100)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];
								data_buffer[2]	<=	data_buffer[3];
								data_buffer[3]	<=	data_buffer[4];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];
								data_buffer[8]	<=	data_buffer[9];
								data_buffer[9]	<=	data_buffer[10];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];
								data_buffer[14]	<=	data_buffer[15];
								data_buffer[15]	<=	data_buffer[16];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];
								data_buffer[20]	<=	data_buffer[21];
								data_buffer[21]	<=	data_buffer[22];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];
								data_buffer[26]	<=	data_buffer[27];
								data_buffer[27]	<=	data_buffer[28];
								
								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];
								data_buffer[32]	<=	data_buffer[33];
								data_buffer[33]	<=	data_buffer[34];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
								data_buffer[38]	<=	data_buffer[39];
								data_buffer[39]	<=	data_buffer[40];
							end
							else if(oversize_count == 'b101)
							begin
								data_buffer[0]	<=	data_buffer[1];
								data_buffer[1]	<=	data_buffer[2];
								data_buffer[2]	<=	data_buffer[3];

								data_buffer[6]	<=	data_buffer[7];
								data_buffer[7]	<=	data_buffer[8];
								data_buffer[8]	<=	data_buffer[9];

								data_buffer[12]	<=	data_buffer[13];
								data_buffer[13]	<=	data_buffer[14];
								data_buffer[14]	<=	data_buffer[15];

								data_buffer[18]	<=	data_buffer[19];
								data_buffer[19]	<=	data_buffer[20];
								data_buffer[20]	<=	data_buffer[21];

								data_buffer[24]	<=	data_buffer[25];
								data_buffer[25]	<=	data_buffer[26];
								data_buffer[26]	<=	data_buffer[27];
								
								data_buffer[30]	<=	data_buffer[31];
								data_buffer[31]	<=	data_buffer[32];
								data_buffer[32]	<=	data_buffer[33];

								data_buffer[36]	<=	data_buffer[37];
								data_buffer[37]	<=	data_buffer[38];
								data_buffer[38]	<=	data_buffer[39];
							end
						end
					endcase
				end
				else if(stride == 'd2)
				begin
					case(mem_access_col[1:0])
						2'b00:
						begin
							if(oversize_count == 'b0)
							begin
								data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
							else if(oversize_count == 'b1)
							begin
								if(mem_access_col == 6'b0)
								begin
									data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[2];
									data_buffer[1]	<=	data_buffer[3];
									data_buffer[2]	<=	data_buffer[4];

									data_buffer[6]	<=	data_buffer[8];
									data_buffer[7]	<=	data_buffer[9];
									data_buffer[8]	<=	data_buffer[10];

									data_buffer[12]	<=	data_buffer[14];
									data_buffer[13]	<=	data_buffer[15];
									data_buffer[14]	<=	data_buffer[16];

									data_buffer[18]	<=	data_buffer[20];
									data_buffer[19]	<=	data_buffer[21];
									data_buffer[20]	<=	data_buffer[22];

									data_buffer[24]	<=	data_buffer[26];
									data_buffer[25]	<=	data_buffer[27];
									data_buffer[26]	<=	data_buffer[28];
									
									data_buffer[30]	<=	data_buffer[32];
									data_buffer[31]	<=	data_buffer[33];
									data_buffer[32]	<=	data_buffer[34];

									data_buffer[36]	<=	data_buffer[38];
									data_buffer[37]	<=	data_buffer[39];
									data_buffer[38]	<=	data_buffer[40];
								end
							end
							else if(oversize_count == 'b10)
							begin
								if(mem_access_col == 6'b0)
								begin
									data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[2];
									data_buffer[1]	<=	data_buffer[3];

									data_buffer[6]	<=	data_buffer[8];
									data_buffer[7]	<=	data_buffer[9];

									data_buffer[12]	<=	data_buffer[14];
									data_buffer[13]	<=	data_buffer[15];

									data_buffer[18]	<=	data_buffer[20];
									data_buffer[19]	<=	data_buffer[21];

									data_buffer[24]	<=	data_buffer[26];
									data_buffer[25]	<=	data_buffer[27];

									data_buffer[30]	<=	data_buffer[32];
									data_buffer[31]	<=	data_buffer[33];

									data_buffer[36]	<=	data_buffer[38];
									data_buffer[37]	<=	data_buffer[39];
								end
							end
							else if(oversize_count == 'b11)
							begin
								if(mem_access_col == 6'b0)
								begin
									if(mem_access_oversize_first == 'b1)
									begin
										data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
									end
									else
									begin
										data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
										data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
										data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
										data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

										data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
										data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
										data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
										data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

										data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
										data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
										data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
										data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

										data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
										data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
										data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
										data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

										data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
										data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
										data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
										data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

										data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
										data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
										data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
										data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

										data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
										data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
										data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
										data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
									end
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[2];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
									data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
									data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	data_buffer[8];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
									data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
									data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	data_buffer[14];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
									data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
									data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	data_buffer[20];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
									data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
									data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	data_buffer[26];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
									data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
									data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	data_buffer[32];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
									data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
									data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	data_buffer[38];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
									data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
									data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
							end
							else if(oversize_count == 'b100)
							begin
								if(mem_access_col == 6'b0)
								begin
									data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[2];
									data_buffer[1]	<=	data_buffer[3];
									data_buffer[2]	<=	data_buffer[4];

									data_buffer[6]	<=	data_buffer[8];
									data_buffer[7]	<=	data_buffer[9];
									data_buffer[8]	<=	data_buffer[10];

									data_buffer[12]	<=	data_buffer[14];
									data_buffer[13]	<=	data_buffer[15];
									data_buffer[14]	<=	data_buffer[16];

									data_buffer[18]	<=	data_buffer[20];
									data_buffer[19]	<=	data_buffer[21];
									data_buffer[20]	<=	data_buffer[22];

									data_buffer[24]	<=	data_buffer[26];
									data_buffer[25]	<=	data_buffer[27];
									data_buffer[26]	<=	data_buffer[28];
									
									data_buffer[30]	<=	data_buffer[32];
									data_buffer[31]	<=	data_buffer[33];
									data_buffer[32]	<=	data_buffer[34];

									data_buffer[36]	<=	data_buffer[38];
									data_buffer[37]	<=	data_buffer[39];
									data_buffer[38]	<=	data_buffer[40];
								end
							end
							else if(oversize_count == 'b101)
							begin
								if(mem_access_col == 6'b0)
								begin
									data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
									data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

									data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
									data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

									data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
									data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

									data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
									data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

									data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
									data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

									data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
									data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

									data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
									data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
								end
								else
								begin
									data_buffer[0]	<=	data_buffer[2];
									data_buffer[1]	<=	data_buffer[3];

									data_buffer[6]	<=	data_buffer[8];
									data_buffer[7]	<=	data_buffer[9];

									data_buffer[12]	<=	data_buffer[14];
									data_buffer[13]	<=	data_buffer[15];

									data_buffer[18]	<=	data_buffer[20];
									data_buffer[19]	<=	data_buffer[21];

									data_buffer[24]	<=	data_buffer[26];
									data_buffer[25]	<=	data_buffer[27];
									
									data_buffer[30]	<=	data_buffer[32];
									data_buffer[31]	<=	data_buffer[33];

									data_buffer[36]	<=	data_buffer[38];
									data_buffer[37]	<=	data_buffer[39];
								end
							end
						end
						2'b10:
						begin
							if(oversize_count == 'b0)
							begin
								data_buffer[0]	<=	data_buffer[2];
								data_buffer[1]	<=	data_buffer[3];

								data_buffer[6]	<=	data_buffer[8];
								data_buffer[7]	<=	data_buffer[9];

								data_buffer[12]	<=	data_buffer[14];
								data_buffer[13]	<=	data_buffer[15];

								data_buffer[18]	<=	data_buffer[20];
								data_buffer[19]	<=	data_buffer[21];

								data_buffer[24]	<=	data_buffer[26];
								data_buffer[25]	<=	data_buffer[27];

								data_buffer[30]	<=	data_buffer[32];
								data_buffer[31]	<=	data_buffer[33];

								data_buffer[36]	<=	data_buffer[38];
								data_buffer[37]	<=	data_buffer[39];
							end
							else if(oversize_count == 'b1)
							begin
								data_buffer[0]	<=	data_buffer[2];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	data_buffer[8];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	data_buffer[14];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	data_buffer[20];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	data_buffer[26];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	data_buffer[32];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	data_buffer[38];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
							else if(oversize_count == 'b10)
							begin
								data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
							else if(oversize_count == 'b11)
							begin
								data_buffer[0]	<=	data_buffer[2];
								data_buffer[1]	<=	data_buffer[3];
								data_buffer[2]	<=	data_buffer[4];

								data_buffer[6]	<=	data_buffer[8];
								data_buffer[7]	<=	data_buffer[9];
								data_buffer[8]	<=	data_buffer[10];

								data_buffer[12]	<=	data_buffer[14];
								data_buffer[13]	<=	data_buffer[15];
								data_buffer[14]	<=	data_buffer[16];

								data_buffer[18]	<=	data_buffer[20];
								data_buffer[19]	<=	data_buffer[21];
								data_buffer[20]	<=	data_buffer[22];

								data_buffer[24]	<=	data_buffer[26];
								data_buffer[25]	<=	data_buffer[27];
								data_buffer[26]	<=	data_buffer[28];
								
								data_buffer[30]	<=	data_buffer[32];
								data_buffer[31]	<=	data_buffer[33];
								data_buffer[32]	<=	data_buffer[34];

								data_buffer[36]	<=	data_buffer[38];
								data_buffer[37]	<=	data_buffer[39];
								data_buffer[38]	<=	data_buffer[40];
							end
							else if(oversize_count == 'b100)
							begin
								data_buffer[0]	<=	data_buffer[2];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[4]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	data_buffer[8];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[10]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	data_buffer[14];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[16]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	data_buffer[20];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[22]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	data_buffer[26];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[28]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	data_buffer[32];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[34]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	data_buffer[38];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[40]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
							else if(oversize_count == 'b101)
							begin
								data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
								data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
								data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
								data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

								data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
								data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
								data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
								data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

								data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
								data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
								data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
								data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

								data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
								data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
								data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
								data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

								data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
								data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
								data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
								data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

								data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
								data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
								data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
								data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

								data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
								data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
								data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
								data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];
							end
						end
					endcase
				end
			end
			else if(kernel_size == 'd1)
			begin
				if(stride == 'd1 )
				begin
					case(mem_access_col[1:0])
						2'b00:
						begin
							data_buffer[0]	<=	input_SRAM_DO[mem_data_input_select[0]][31:24];
							data_buffer[1]	<=	input_SRAM_DO[mem_data_input_select[0]][23:16];
							data_buffer[2]	<=	input_SRAM_DO[mem_data_input_select[0]][15:8];
							data_buffer[3]	<=	input_SRAM_DO[mem_data_input_select[0]][7:0];

							data_buffer[6]	<=	input_SRAM_DO[mem_data_input_select[1]][31:24];
							data_buffer[7]	<=	input_SRAM_DO[mem_data_input_select[1]][23:16];
							data_buffer[8]	<=	input_SRAM_DO[mem_data_input_select[1]][15:8];
							data_buffer[9]	<=	input_SRAM_DO[mem_data_input_select[1]][7:0];

							data_buffer[12]	<=	input_SRAM_DO[mem_data_input_select[2]][31:24];
							data_buffer[13]	<=	input_SRAM_DO[mem_data_input_select[2]][23:16];
							data_buffer[14]	<=	input_SRAM_DO[mem_data_input_select[2]][15:8];
							data_buffer[15]	<=	input_SRAM_DO[mem_data_input_select[2]][7:0];

							data_buffer[18]	<=	input_SRAM_DO[mem_data_input_select[3]][31:24];
							data_buffer[19]	<=	input_SRAM_DO[mem_data_input_select[3]][23:16];
							data_buffer[20]	<=	input_SRAM_DO[mem_data_input_select[3]][15:8];
							data_buffer[21]	<=	input_SRAM_DO[mem_data_input_select[3]][7:0];

							data_buffer[24]	<=	input_SRAM_DO[mem_data_input_select[4]][31:24];
							data_buffer[25]	<=	input_SRAM_DO[mem_data_input_select[4]][23:16];
							data_buffer[26]	<=	input_SRAM_DO[mem_data_input_select[4]][15:8];
							data_buffer[27]	<=	input_SRAM_DO[mem_data_input_select[4]][7:0];

							data_buffer[30]	<=	input_SRAM_DO[mem_data_input_select[5]][31:24];
							data_buffer[31]	<=	input_SRAM_DO[mem_data_input_select[5]][23:16];
							data_buffer[32]	<=	input_SRAM_DO[mem_data_input_select[5]][15:8];
							data_buffer[33]	<=	input_SRAM_DO[mem_data_input_select[5]][7:0];

							data_buffer[36]	<=	input_SRAM_DO[mem_data_input_select[6]][31:24];
							data_buffer[37]	<=	input_SRAM_DO[mem_data_input_select[6]][23:16];
							data_buffer[38]	<=	input_SRAM_DO[mem_data_input_select[6]][15:8];
							data_buffer[39]	<=	input_SRAM_DO[mem_data_input_select[6]][7:0];

							data_buffer[42]	<=	input_SRAM_DO[mem_data_input_select[7]][31:24];
							data_buffer[43]	<=	input_SRAM_DO[mem_data_input_select[7]][23:16];
							data_buffer[44]	<=	input_SRAM_DO[mem_data_input_select[7]][15:8];
							data_buffer[45]	<=	input_SRAM_DO[mem_data_input_select[7]][7:0];

							data_buffer[48]	<=	input_SRAM_DO[mem_data_input_select[8]][31:24];
							data_buffer[49]	<=	input_SRAM_DO[mem_data_input_select[8]][23:16];
							data_buffer[50]	<=	input_SRAM_DO[mem_data_input_select[8]][15:8];
							data_buffer[51]	<=	input_SRAM_DO[mem_data_input_select[8]][7:0];
						end
						2'b01:
						begin
							data_buffer[0]	<=	data_buffer[1];
							data_buffer[1]	<=	data_buffer[2];
							data_buffer[2]	<=	data_buffer[3];

							data_buffer[6]	<=	data_buffer[7];
							data_buffer[7]	<=	data_buffer[8];
							data_buffer[8]	<=	data_buffer[9];

							data_buffer[12]	<=	data_buffer[13];
							data_buffer[13]	<=	data_buffer[14];
							data_buffer[14]	<=	data_buffer[15];

							data_buffer[18]	<=	data_buffer[19];
							data_buffer[19]	<=	data_buffer[20];
							data_buffer[20]	<=	data_buffer[21];

							data_buffer[24]	<=	data_buffer[25];
							data_buffer[25]	<=	data_buffer[26];
							data_buffer[26]	<=	data_buffer[27];

							data_buffer[30]	<=	data_buffer[31];
							data_buffer[31]	<=	data_buffer[32];
							data_buffer[32]	<=	data_buffer[33];

							data_buffer[36]	<=	data_buffer[37];
							data_buffer[37]	<=	data_buffer[38];
							data_buffer[38]	<=	data_buffer[39];

							data_buffer[42]	<=	data_buffer[43];
							data_buffer[43]	<=	data_buffer[44];
							data_buffer[44]	<=	data_buffer[45];

							data_buffer[48]	<=	data_buffer[49];
							data_buffer[49]	<=	data_buffer[50];
							data_buffer[50]	<=	data_buffer[51];
						end
						2'b10:
						begin
							data_buffer[0]	<=	data_buffer[1];
							data_buffer[1]	<=	data_buffer[2];

							data_buffer[6]	<=	data_buffer[7];
							data_buffer[7]	<=	data_buffer[8];

							data_buffer[12]	<=	data_buffer[13];
							data_buffer[13]	<=	data_buffer[14];

							data_buffer[18]	<=	data_buffer[19];
							data_buffer[19]	<=	data_buffer[20];

							data_buffer[24]	<=	data_buffer[25];
							data_buffer[25]	<=	data_buffer[26];

							data_buffer[30]	<=	data_buffer[31];
							data_buffer[31]	<=	data_buffer[32];

							data_buffer[36]	<=	data_buffer[37];
							data_buffer[37]	<=	data_buffer[38];

							data_buffer[42]	<=	data_buffer[43];
							data_buffer[43]	<=	data_buffer[44];

							data_buffer[48]	<=	data_buffer[49];
							data_buffer[49]	<=	data_buffer[50];
						end
						2'b11:
						begin
							data_buffer[0]	<=	data_buffer[1];

							data_buffer[6]	<=	data_buffer[7];

							data_buffer[12]	<=	data_buffer[13];

							data_buffer[18]	<=	data_buffer[19];

							data_buffer[24]	<=	data_buffer[25];

							data_buffer[30]	<=	data_buffer[31];

							data_buffer[36]	<=	data_buffer[37];

							data_buffer[42]	<=	data_buffer[43];

							data_buffer[48]	<=	data_buffer[49];
						end
					endcase
				end
			end
		end
	end

	//input
	// always_ff @(posedge clk)
	// begin
	// 	predict_tmp3	<=	mem_data_row[2:0];
	// end
	//PE_data_input
	assign predict_tmp3 = mem_data_row[2:0];
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(PE_data_input[i])
				PE_data_input[i]	<=	8'b0;
		end
		else
		begin
			if(kernel_size == 'd3)
			begin
				if((stride == 'd1 || stride == 'd2) && ((pooling_enable=='b1 && pooling_delay)||(pooling_enable=='b0)))
				begin
					PE_data_input[0]	<=	data_buffer[0];
					PE_data_input[1]	<=	data_buffer[1];
					PE_data_input[2]	<=	data_buffer[2];
					PE_data_input[3]	<=	data_buffer[6];
					PE_data_input[4]	<=	data_buffer[7];
					PE_data_input[5]	<=	data_buffer[8];
					PE_data_input[6]	<=	data_buffer[12];
					PE_data_input[7]	<=	data_buffer[13];
					PE_data_input[8]	<=	data_buffer[14];
				end
			end
			else if(kernel_size == 'd5)
			begin
				if(stride == 'd1 || stride == 'd2)
				begin
					if(oversize_count == 'b0)
					begin
						PE_data_input[0]	<=	data_buffer[0];
						PE_data_input[1]	<=	data_buffer[6];
						PE_data_input[2]	<=	data_buffer[12];
						PE_data_input[3]	<=	data_buffer[18];
						PE_data_input[4]	<=	data_buffer[24];
						PE_data_input[5]	<=	data_buffer[1];
						PE_data_input[6]	<=	data_buffer[7];
						PE_data_input[7]	<=	data_buffer[13];
						PE_data_input[8]	<=	data_buffer[19];
					end
					else if(oversize_count == 'b1)
					begin
						PE_data_input[0]	<=	data_buffer[24];
						PE_data_input[1]	<=	data_buffer[1];
						PE_data_input[2]	<=	data_buffer[7];
						PE_data_input[3]	<=	data_buffer[13];
						PE_data_input[4]	<=	data_buffer[19];
						PE_data_input[5]	<=	data_buffer[25];
						PE_data_input[6]	<=	data_buffer[2];
						PE_data_input[7]	<=	data_buffer[8];
						PE_data_input[8]	<=	data_buffer[14];
					end
					else if(oversize_count == 'b10)
					begin
						PE_data_input[0]	<=	data_buffer[18];
						PE_data_input[1]	<=	data_buffer[24];
						PE_data_input[2]	<=	data_buffer[1];
						PE_data_input[3]	<=	data_buffer[7];
						PE_data_input[4]	<=	data_buffer[13];
						PE_data_input[5]	<=	data_buffer[19];
						PE_data_input[6]	<=	data_buffer[25];
						PE_data_input[7]	<=	8'b0;
						PE_data_input[8]	<=	8'b0;
					end
				end
			end
			else if(kernel_size == 'd7)
			begin
				if(stride == 'd1 || stride == 'd2)
				begin
					if(oversize_count == 'b000)
					begin
						PE_data_input[0]	<=	data_buffer[0];
						PE_data_input[1]	<=	data_buffer[6];
						PE_data_input[2]	<=	data_buffer[12];
						PE_data_input[3]	<=	data_buffer[18];
						PE_data_input[4]	<=	data_buffer[24];
						PE_data_input[5]	<=	data_buffer[30];
						PE_data_input[6]	<=	data_buffer[36];
						PE_data_input[7]	<=	data_buffer[1];
						PE_data_input[8]	<=	data_buffer[7];
					end
					else if(oversize_count == 'b001)
					begin
						PE_data_input[0]	<=	data_buffer[12];
						PE_data_input[1]	<=	data_buffer[18];
						PE_data_input[2]	<=	data_buffer[24];
						PE_data_input[3]	<=	data_buffer[30];
						PE_data_input[4]	<=	data_buffer[36];
						PE_data_input[5]	<=	data_buffer[1];
						PE_data_input[6]	<=	data_buffer[7];
						PE_data_input[7]	<=	data_buffer[13];
						PE_data_input[8]	<=	data_buffer[19];
					end
					else if(oversize_count == 'b010)
					begin
						PE_data_input[0]	<=	data_buffer[24];
						PE_data_input[1]	<=	data_buffer[30];
						PE_data_input[2]	<=	data_buffer[36];
						PE_data_input[3]	<=	data_buffer[1];
						PE_data_input[4]	<=	data_buffer[7];
						PE_data_input[5]	<=	data_buffer[13];
						PE_data_input[6]	<=	data_buffer[19];
						PE_data_input[7]	<=	data_buffer[25];
						PE_data_input[8]	<=	data_buffer[31];
					end
					else if(oversize_count == 'b011)
					begin
						PE_data_input[0]	<=	data_buffer[36];
						PE_data_input[1]	<=	data_buffer[1];
						PE_data_input[2]	<=	data_buffer[7];
						PE_data_input[3]	<=	data_buffer[13];
						PE_data_input[4]	<=	data_buffer[19];
						PE_data_input[5]	<=	data_buffer[25];
						PE_data_input[6]	<=	data_buffer[31];
						PE_data_input[7]	<=	data_buffer[37];
						PE_data_input[8]	<=	data_buffer[2];
					end
					else if(oversize_count == 'b100)
					begin
						PE_data_input[0]	<=	data_buffer[6];
						PE_data_input[1]	<=	data_buffer[12];
						PE_data_input[2]	<=	data_buffer[18];
						PE_data_input[3]	<=	data_buffer[24];
						PE_data_input[4]	<=	data_buffer[30];
						PE_data_input[5]	<=	data_buffer[36];
						PE_data_input[6]	<=	data_buffer[1];
						PE_data_input[7]	<=	data_buffer[7];
						PE_data_input[8]	<=	data_buffer[13];
					end
					else if(oversize_count == 'b101)
					begin
						PE_data_input[0]	<=	data_buffer[18];
						PE_data_input[1]	<=	data_buffer[24];
						PE_data_input[2]	<=	data_buffer[30];
						PE_data_input[3]	<=	data_buffer[36];
						PE_data_input[4]	<=	8'd0;
						PE_data_input[5]	<=	8'd0;
						PE_data_input[6]	<=	8'd0;
						PE_data_input[7]	<=	8'd0;
						PE_data_input[8]	<=	8'd0;
					end
				end
			end
			else if(kernel_size == 'd1)
			begin
				if(stride == 'd1)
				begin
					if(filter_parting_map_times == 'd9)
					begin
							PE_data_input[0]	<=	data_buffer[0];
							PE_data_input[1]	<=	data_buffer[6];
							PE_data_input[2]	<=	data_buffer[12];
							PE_data_input[3]	<=	data_buffer[18];
							PE_data_input[4]	<=	data_buffer[24];
							PE_data_input[5]	<=	data_buffer[30];
							PE_data_input[6]	<=	data_buffer[36];
							PE_data_input[7]	<=	data_buffer[42];
							PE_data_input[8]	<=	data_buffer[48];
					end
					else if(filter_parting_map_times == 'd4)
					begin
							PE_data_input[0]	<=	data_buffer[0];
							PE_data_input[1]	<=	data_buffer[6];
							PE_data_input[2]	<=	data_buffer[12];
							PE_data_input[3]	<=	data_buffer[18];
							PE_data_input[4]	<=	8'd0;
							PE_data_input[5]	<=	8'd0;
							PE_data_input[6]	<=	8'd0;
							PE_data_input[7]	<=	8'd0;
							PE_data_input[8]	<=	8'd0;
					end
					else if(filter_parting_map_times == 'd1)
					begin
							PE_data_input[0]	<=	data_buffer[0];
							PE_data_input[1]	<=	8'd0;
							PE_data_input[2]	<=	8'd0;
							PE_data_input[3]	<=	8'd0;
							PE_data_input[4]	<=	8'd0;
							PE_data_input[5]	<=	8'd0;
							PE_data_input[6]	<=	8'd0;
							PE_data_input[7]	<=	8'd0;
							PE_data_input[8]	<=	8'd0;
					end
				end
			end
		end
	end
	
	//psum
	//PE_data_pre_psum
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(PE_data_pre_psum[i])
				PE_data_pre_psum[i]	<=	16'b0;
			foreach(PE_data_pre_psum[i])
				max_pooling_buffer2[i]	<=	16'b0;
		end
		else if((act_cur_channel == 1'b0 && oversize_count == 1'b0) || cur_state == IDLE)
		begin
			foreach(PE_data_pre_psum[i])
				PE_data_pre_psum[i]	<=	16'b0;
		end
		else
		begin
			if(pooling_enable)
			begin
				if(pooling_delay == 1'b1)
				begin
					foreach(PE_data_pre_psum[i])
						PE_data_pre_psum[i] <= output_SRAM_DO[i];
				end
				else
				begin
					if(mem_access_col[0] == 1'b1 || PE_add_col == 'd49)
					begin
						foreach(max_pooling_buffer2[i])
							max_pooling_buffer2[i]	<=	output_SRAM_DO[i];
						foreach(max_pooling_buffer2[i])
							max_pooling_buffer3[i]	<=	max_pooling_buffer2[i];
					end
				end
			end
			else
			begin
				foreach(PE_data_pre_psum[i])
					PE_data_pre_psum[i] <= output_SRAM_DO[i];
			end
		end
	end
	
	//PE control
	always_ff @(posedge clk, posedge rst)
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
		else if(kernel_size == 'd3 || kernel_size == 'd1)
		begin
			if((mem_access_state == S1 && cur_state != IDLE) || (pooling_enable && PE_out_col!='b0 && PE_out_row!='b0))// && cur_state == S1)
			begin
				read_input_enable	<=	1'b1;
				read_weight_enable	<=	1'b1;
				read_psum_enable	<=	1'b1;
			end
			else
			begin
				read_input_enable	<=	1'b0;
				read_weight_enable	<=	1'b0;
				read_psum_enable	<=	1'b0;
				read_bias_enable	<=	1'b0;
				if_do_bias			<=	1'b0;
				if_do_activation	<=	2'b0;
			end
		end
		else if(kernel_size == 'd5 || kernel_size == 'd7)
		begin
			if(mem_access_state == S1 && cur_state != IDLE || mem_access_state == S2)// && cur_state == S1)
			begin
				read_input_enable	<=	1'b1;
				read_weight_enable	<=	1'b1;
				read_psum_enable	<=	1'b1;
			end
			else
			begin
				read_input_enable	<=	1'b0;
				read_weight_enable	<=	1'b0;
				read_psum_enable	<=	1'b0;
				read_bias_enable	<=	1'b0;
				if_do_bias			<=	1'b0;
				if_do_activation	<=	2'b0;
			end
		end
	end

	//pipeline state
	always_ff @(posedge clk, posedge rst)
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
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			mem_access_row	<=	5'd0;
			mem_data_row	<=	5'd0;
			PE_row			<=	5'd0;
			PE_mult_row		<=	5'd0;
			PE_add_row		<=	5'd0;
			PE_out_row		<=	5'd0;
			mem_access_col	<=	5'd0;
			mem_data_col	<=	5'd0;
			PE_col			<=	5'd0;
			PE_mult_col		<=	5'd0;
			PE_add_col		<=	5'd0;
			PE_out_col		<=	5'd0;
		end
		else 
		begin
			mem_access_row	<=	cur_row;
			mem_data_row	<=	mem_access_row;
			PE_row			<=	mem_data_row;
			PE_mult_row		<=	PE_row;
			PE_add_row		<=	PE_mult_row;
			PE_out_row		<=	PE_add_row;
			mem_access_col	<=	cur_col;
			mem_data_col	<=	mem_access_col;
			PE_col			<=	mem_data_col;
			PE_mult_col		<=	PE_col;
			PE_add_col		<=	PE_mult_col;
			PE_out_col		<=	PE_add_col;
		end 
	end

	//rst_PE_reg
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			rst_PE_reg	<=	1'b0;
		else if(cur_state == IDLE)
		begin
			if(pooling_enable)
			begin
				if(pooling_delay == 'b1)
					rst_PE_reg	<=	1'b1;
			end
			else
				rst_PE_reg	<=	1'b1;
		end
		else
			rst_PE_reg	<=	1'b0;
	end

	//PE * 32
	genvar i;
	generate
		for(i=0;i<32;i=i+1)
		begin: u_PE
			PE PE_i(
				.clk(clk),
				.rst(rst),
				.rst_reg(rst_PE_reg),
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
	
endmodule
