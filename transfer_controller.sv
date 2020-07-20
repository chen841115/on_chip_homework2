`define WEIGHT_START 'h100000
`define OUTPUT_START 'h180000
module transfer_controller(
    clk,
    rst,
    run,
	//controller
	row_end,
	col_end,
	controller_run,
	act_cur_channel,
	cur_channel,
    //DMA
    DRAM_ADDR_start,
    DRAM_ADDR_end,
    BUF_ADDR_start,
	BUF_ADDR_end,
	WEIGHT_SRAM_ADDR_start,
	WEIGHT_SRAM_ADDR_end,
	Output_SRAM_ADDR_start,
	Output_SRAM_ADDR_end,
    DMA_start,
    DMA_done,
    SRAM_type,
	DMA_type,
    DMA_buf_select,
	tile_done,
	//buffer2sram_input
	input_BUF_ADDR_start,
	input_BUF_ADDR_end,
	input_SRAM_ADDR_start,
	input_buffer2sram_start,
	input_buffer2sram_done,
    //conv info
	kernel_size,
    kernel_num,
	stride,
	channel,
	map_size,
	ouput_map_size,
	//signal for buffer to sram
	input_SRAM_ready,
	controller_cur_row,
	controller_cur_state,
	transfer_controller_done,
	//input_SRAM_rw_select input_buffer_rw_select
	input_SRAM_rw_select,
	input_buffer_rw_select,
	output_sram_read_select,
	weight_SRAM_rw_select
);

    input   clk;
    input   rst;
    input   run;
	//controller
	output	logic	[5:0]	row_end;
	output	logic	[5:0]	col_end;
	output	logic	controller_run;
	output	logic	[9:0]	act_cur_channel;
	output	[9:0]	cur_channel;
    //DMA
    output	logic	[31:0]	DRAM_ADDR_start;
    output	logic	[31:0]	DRAM_ADDR_end;
    output	logic	[6:0]	BUF_ADDR_start;
	output	logic	[6:0]	BUF_ADDR_end;
	output	logic	[12:0]	WEIGHT_SRAM_ADDR_start;
	output	logic	[12:0]	WEIGHT_SRAM_ADDR_end;
	output	logic	[17:0]	Output_SRAM_ADDR_start;
	output	logic	[17:0]	Output_SRAM_ADDR_end;
	output	logic	DMA_start;
	input	DMA_done;
	output	logic	SRAM_type;
	output	logic	DMA_buf_select;
	input	tile_done;
	//buffer2sram_input
	output	logic	[7:0]	input_BUF_ADDR_start;
	output	logic	[7:0]	input_BUF_ADDR_end;
	output	logic	[12:0]	input_SRAM_ADDR_start;
	output	logic	input_buffer2sram_start;
	input	input_buffer2sram_done;
    //conv info
	input	[3:0]	kernel_size;
    input	[9:0]	kernel_num;
	input	[2:0]	stride;
	input	[9:0]	channel;
	input	[9:0]	map_size;
	input	[9:0]	ouput_map_size;	
	//signal for buffer to sram
	output	logic	input_SRAM_ready	[0:63];
	input	[2:0]	controller_cur_state;
	input	[5:0]	controller_cur_row;
	output	logic	transfer_controller_done;
	//input_SRAM_rw_select input_buffer_rw_select
	output	logic	input_SRAM_rw_select	[0:63];
	output	logic	input_buffer_rw_select	[0:1];
	output	logic	output_sram_read_select;
	output	logic	weight_SRAM_rw_select;
	output	logic	DMA_type;

    //
    logic   [9:0]   map_col;
    logic   [9:0]   map_row;
    logic   [6:0]   col_length;
    logic   [6:0]   row_length;
	logic	[3:0]	cur_state,next_state,pre_state;
	logic	[9:0]	col_index,next_col_index;
	logic	[9:0]	row_index,next_row_index;
	logic	[6:0]	tile_col,tile_row;
	logic	buffer1_write_ready,buffer2_write_ready;
	logic	[9:0]	cur_channel;
	logic	[19:0]	map_addr_offset;
	logic	[21:0]	channal_addr_offset;
	// DMA_type = 1
	logic	[5:0]	output_sram_row_index;
	logic	[19:0]	output_sram_map_total_size;
	logic	[15:0]	cur_filter;
	//filter_parting_cur_state
	logic	[2:0]	filter_parting_cur_state;
	logic	[2:0]	filter_parting_next_state;
	logic	[2:0]	filter_parting_pre_state;
	logic	[9:0]	filter_index;
	logic	[6:0]	filter_parting;
	logic	[6:0]	filter_limit;
	logic	[15:0]	one_filter_size;
	logic	[9:0]	filter_channel;
	logic	[9:0]	filter_channel_length;
	logic	transfer_controller_run;

	logic	read_buf_select;

	//assign	SRAM_type	=	1'b0;
	assign	tile_col	=	col_index	-	map_col;
	assign	tile_row	=	row_index	-	map_row;
	assign	row_end	=	row_length	-	1'b1;
	assign	col_end	=	col_length	-	1'b1;
	assign	one_filter_size	=	kernel_size * kernel_size * channel;
	assign	act_cur_channel	=	cur_channel + filter_channel;	

	//filter_parting
	//filter_parting_cur_state
	always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            filter_parting_cur_state   <=  3'b0;
        else
            filter_parting_cur_state   <=  filter_parting_next_state;
    end
	always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            filter_parting_pre_state   <=  3'b0;
        else
            filter_parting_pre_state   <=  filter_parting_cur_state;
    end

	always_comb
	begin
		case(filter_parting_cur_state)
			3'b000:
				if(run)
					filter_parting_next_state	=	3'b001;
				else
					filter_parting_next_state	=	3'b000;
			3'b001:
				filter_parting_next_state	=	3'b010;
			3'b010:
				if(~DMA_done)
					filter_parting_next_state	=	3'b011;
				else
					filter_parting_next_state	=	3'b010;
			3'b011:
				if(DMA_done)
					filter_parting_next_state	=	3'b100;
				else
					filter_parting_next_state	=	3'b011;
			3'b100:
				if(filter_parting < filter_limit - 1'b1)
					filter_parting_next_state	=	3'b010;
				else
					filter_parting_next_state	=	3'b101;
			3'b101:
				if(transfer_controller_done)
					filter_parting_next_state	=	3'b110;
				else
					filter_parting_next_state	=	3'b101;
			3'b110:
				if(filter_index + 6'd32 >= kernel_num)
					filter_parting_next_state	=	3'b111;
				else
					filter_parting_next_state	=	3'b001;
			3'b111:
				filter_parting_next_state	=	3'b000;
			default:
				filter_parting_next_state	=	3'b000;
		endcase
	end

	//filter_index
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			filter_index	<=	10'b0;
		else if(filter_parting_cur_state == 3'b001)
		begin
			if(filter_parting_pre_state == 3'b000)
				filter_index	<=	10'b0;
			else 
				filter_index	<=	filter_index + 6'd32;
		end
	end

	//filter_parting
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			filter_parting	<=	6'b0;
		else if(cur_state == 'b0111)
		begin
			if(kernel_size == 'd3)
			begin
				if(filter_channel + 8'd128 >= channel)
					filter_parting	<=	filter_parting;
				else
					filter_parting	<=	6'b0;
			end
			else if(kernel_size == 'd5)
			begin
				if(filter_channel + 'd42 >= channel)
					filter_parting	<=	filter_parting;
				else
					filter_parting	<=	6'b0;
			end
		end
		else if(cur_state == 'b1011 && pre_state != 'b0111)
			filter_parting	<=	filter_parting + 1'b1;
		else if(filter_parting_cur_state == 3'b001)
			filter_parting	<=	6'b0;
		else if(filter_parting_cur_state == 3'b010 && filter_parting_pre_state != 3'b001)
			filter_parting	<=	filter_parting + 1'b1;
	end

	//filter_limit
	always_comb
	begin
		if(filter_index + 6'd32 < kernel_num)
			filter_limit	=	6'd32;
		else 
			filter_limit	=	kernel_num - filter_index;
	end

	//WEIGHT_SRAM_ADDR_start
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			WEIGHT_SRAM_ADDR_start	<=	'b0;
		else if(cur_state == 'b1100)
		begin
			WEIGHT_SRAM_ADDR_start[6:0]	<=	7'b0;
			if(kernel_size == 'd3)
				WEIGHT_SRAM_ADDR_start[12:7]<=	filter_parting;
			else if(kernel_size == 'd5)
				WEIGHT_SRAM_ADDR_start[12:7]<=	filter_parting;
		end
		else if(filter_parting_cur_state == 3'b011)
		begin
			WEIGHT_SRAM_ADDR_start[6:0]	<=	7'b0;
			if(kernel_size == 'd3)
				WEIGHT_SRAM_ADDR_start[12:7]<=	filter_parting;
			else if(kernel_size == 'd5)
				WEIGHT_SRAM_ADDR_start[12:7]<=	filter_parting;
		end
	end
	//WEIGHT_SRAM_ADDR_end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			WEIGHT_SRAM_ADDR_end	<=	'b0;
		else if(cur_state == 'b1100)
		begin
			if(kernel_size == 'd3)
			begin
				WEIGHT_SRAM_ADDR_end[6:0]	<=	filter_channel_length - 1'b1;
				WEIGHT_SRAM_ADDR_end[12:7]	<=	filter_parting;
			end
			else if(kernel_size == 'd5)
			begin
				WEIGHT_SRAM_ADDR_end[6:0]	<=	(filter_channel_length * 'd3) - 1'b1;
				WEIGHT_SRAM_ADDR_end[12:7]	<=	filter_parting;
			end
		end
		else if(filter_parting_cur_state == 3'b011)
		begin
			if(kernel_size == 'd3)
			begin
				WEIGHT_SRAM_ADDR_end[6:0]	<=	filter_channel_length - 1'b1;
				WEIGHT_SRAM_ADDR_end[12:7]	<=	filter_parting;
			end
			else if(kernel_size == 'd5)
			begin
				WEIGHT_SRAM_ADDR_end[6:0]	<=	(filter_channel_length * 'd3) - 1'b1;
				WEIGHT_SRAM_ADDR_end[12:7]	<=	filter_parting;
			end
		end
	end
	//transfer_controller_run
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			transfer_controller_run	<=	1'b0;
		else if(filter_parting_cur_state == 3'b101 &&filter_parting_pre_state == 3'b100)
			transfer_controller_run	<=	1'b1;
		else 
			transfer_controller_run	<=	1'b0;
	end
	//filter_channel
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			filter_channel	<=	'b0;
		else if(cur_state == 4'b0111)
		begin
			if(pre_state == 4'b0001)
				filter_channel	<=	'b0;
			else if(pre_state == 4'b0101)
			begin
				if(kernel_size == 'd3)
				begin
					if(filter_channel + 8'd128 >= channel)
						filter_channel	<=	filter_channel;
					else
						filter_channel	<=	filter_channel	+	8'd128 ;
				end
				else if(kernel_size == 'd5)
				begin
					if(filter_channel + 'd42 >= channel)
						filter_channel	<=	filter_channel;
					else
						filter_channel	<=	filter_channel	+	'd42 ;
				end
			end
		end

	end
	//filter_parting END

	//filter_channel_length
	always_comb
	begin
		if(kernel_size == 'd3)
		begin
			if(filter_channel + 8'd128 >= channel)
				filter_channel_length	=	channel - filter_channel;
			else
				filter_channel_length	=	8'd128;
		end
		else if(kernel_size == 'd5)
		begin
			if(filter_channel + 'd42 >= channel)
				filter_channel_length	=	channel - filter_channel;
			else
				filter_channel_length	=	'd42;
		end
	end

	//controller_run
	always_ff @(posedge clk, posedge rst) 
    begin
		if(rst)
			controller_run	<=	1'b0;
		else if(cur_state == 'b101 && pre_state == 'b110)
			controller_run	<=	1'b1;
		else
			controller_run	<=	1'b0;
	end

	//output_sram_read_select
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			output_sram_read_select	<=	1'b1;
		else if(cur_state == 'b101)
			output_sram_read_select	<=	1'b1;
		else if(cur_state == 'b1000)
			output_sram_read_select	<=	1'b0;
	end

	//state
	always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            cur_state   <=  'b0;
        else
            cur_state   <=  next_state;
    end

	always_comb
	begin
		case(cur_state)
			'b0000:
				if(transfer_controller_run)
					next_state	=	'b1;
				else
					next_state	=	'b0;
			'b0001:
				if(filter_channel != 10'd0)
					next_state	=	'b0111;
				else
					next_state	=	'b10;
			'b0010:
				if(transfer_controller_done == 1'b1)
					next_state	=	'b0;
				else if(~DMA_done)
					next_state	=	'b11;
				else
					next_state	=	'b10;
			'b0011:
				if(DMA_done)
					next_state	=	'b100;
				else
					next_state	=	'b11;
			'b0100:
				if(input_buffer2sram_done)
					next_state	=	'b110;
				else
					next_state	=	'b100;
			'b0101:
				// if(tile_done)
				// 	next_state	=	'b001;
				if(tile_done)
				begin
					if(cur_channel	<	filter_channel_length - 1'b1)
						next_state	=	'b010;
					else
						next_state	=	'b111;
				end
				else
					next_state	=	'b101;
			'b0110:
				if(row_index >=  map_row + row_length - 1'b1)
				begin
					if(~tile_done)
						next_state	=	'b101;	//test
					else
						next_state	=	'b110;
				end
				else if(~DMA_done)
					next_state	=	'b11;
				else
					next_state	=	'b110;
			'b0111:
				if(kernel_size == 'd3)
				begin
					if(filter_channel + 8'd128 >= channel)
						next_state	=	'b1000;
					else
						next_state	=	'b1011;
				end
				else if(kernel_size == 'd5)
				begin
					if(filter_channel + 'd42 >= channel)
						next_state	=	'b1000;
					else
						next_state	=	'b1011;
				end
				
				//next_state	=	'b010;
			'b1000:
				if(DMA_done)
				begin
					if(output_sram_row_index >= row_length - kernel_size)
						next_state	=	'b1010;
					else
						next_state	=	'b1001;
				end
				else
					next_state	=	'b1000;
			'b1001:
				if(cur_filter >= ((kernel_num > 6'd32)?6'd32:kernel_num))
					next_state	=	'b001;
				else if(~DMA_done)
					next_state	=	'b1000;
				else 
					next_state	=	'b1001;
			'b1010:
				next_state	=	'b1001;
			//weight DRAM
			'b1011:
				if(~DMA_done)
					next_state	=	'b1100;
				else
					next_state	=	'b1011;
			'b1100:
				if(DMA_done)
					next_state	=	'b1101;
				else
					next_state	=	'b1100;
			'b1101:
				if(filter_parting < filter_limit - 1'b1)
					next_state	=	'b1011;
				else
					next_state	=	'b0010;
		endcase
	end



	always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            pre_state   <=  'b0;
        else
            pre_state   <=  cur_state;
    end

	//channal_addr_offset
	//cur_channel
	// always_ff @(posedge clk, posedge rst)
	// begin
	// 	if(rst)
	// 		channal_addr_offset	<=	1'b0;
	// 	else if(cur_state == 'b0010)
	// 		channal_addr_offset	<=	channal_addr_offset + map_size*map_size;
	// end
	assign channal_addr_offset = (cur_channel+filter_channel)*map_size*map_size;
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			cur_channel	<=	1'b1;
		else if(cur_state == 4'b0010 && pre_state != 4'b0001 && pre_state != 4'b1101)
			cur_channel	<=	cur_channel	+	1'b1;
		else if(cur_state == 4'b0001)
			cur_channel	<=	1'b0;
		else if(cur_state == 4'b1101)
		begin
			if(filter_parting < filter_limit - 1'b1)
				cur_channel	<=	cur_channel;
			else
				cur_channel	<=	1'b0;
		end
	end

	//buffer_write_ready
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			buffer1_write_ready	<=	1'b1;
	end

	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			buffer2_write_ready	<=	1'b1;
	end

	//map col/row
    always_ff @(posedge clk, posedge rst)
    begin
        if(rst)
        begin
            map_col	<=	10'b0;
            map_row <=	10'b0;
			transfer_controller_done	<=	1'b0;
        end
		else if(cur_state == 'b001)
		begin
			if(pre_state == 'b0)
			begin
				map_col	<=	10'b0;
            	map_row <=	10'b0;
				transfer_controller_done	<=	1'b0;
			end
			else
			begin
				if(kernel_size == 'd3)
				begin
					if(stride == 'd1)
					begin
						if(filter_channel != 10'd0)
						begin
							map_col	<=	map_col;
							map_row	<=	map_row;
						end
						else if(map_col + 'd64 >= map_size)
						begin
							if(map_row + 'd64 >= map_size)
							begin
								transfer_controller_done	<=	1'b1;
								map_col	<=	10'b0;
								map_row <=	10'b0;
							end
							else
							begin
								map_col	<=	10'b0;
								map_row	<=	map_row	+	'd62;
							end
						end
						else
						begin
							map_col	<=	map_col	+	'd62;
							map_row	<=	map_row;
						end
					end
				end
				else if(kernel_size == 'd5)
				begin
					if(stride == 'd1)
					begin
						if(filter_channel != 10'd0)
						begin
							map_col	<=	map_col;
							map_row	<=	map_row;
						end
						else if(map_col + 'd64 >= map_size)
						begin
							if(map_row + 'd64 >= map_size)
							begin
								transfer_controller_done	<=	1'b1;
								map_col	<=	10'b0;
								map_row <=	10'b0;
							end
							else
							begin
								map_col	<=	10'b0;
								map_row	<=	map_row	+	'd60;
							end
						end
						else
						begin
							map_col	<=	map_col	+	'd60;
							map_row	<=	map_row;
						end
					end
				end
			end
		end
		else if(cur_state == 'b0000)
			transfer_controller_done	<=	1'b0;
    end

	assign	map_addr_offset	=	row_index * map_size;
	//DRAM_ADDR_start
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			DRAM_ADDR_start	<=	32'b0;
			DRAM_ADDR_end	<=	32'b0;
		end
		else if(cur_state == 'b11)
		begin
			// DRAM_ADDR_start	<=	(col_index + (row_index<<5) + (row_index<<4) + (row_index<<2)) << 2 ;
			// DRAM_ADDR_end	<=	(col_index + (row_index<<5) + (row_index<<4) + (row_index<<2) + col_length - 1'b1) << 2 ;
			DRAM_ADDR_start	<=	(col_index + map_addr_offset + channal_addr_offset) << 2 ;
			DRAM_ADDR_end	<=	(col_index + map_addr_offset + channal_addr_offset + col_length - 1'b1) << 2 ;
		end
		else if(cur_state == 'b1000)
		begin
			DRAM_ADDR_start	<=	((output_sram_map_total_size * (cur_filter + filter_index)) + 
								((output_sram_row_index + map_row) * ouput_map_size) + `OUTPUT_START + map_col) << 2;
			if(kernel_size == 'd3)
				DRAM_ADDR_end	<=	((output_sram_map_total_size * (cur_filter + filter_index)) + 
									((output_sram_row_index + map_row) * ouput_map_size) + 'd61 + `OUTPUT_START + map_col) << 2;
			else if(kernel_size == 'd5)
				DRAM_ADDR_end	<=	((output_sram_map_total_size * (cur_filter + filter_index)) + 
									((output_sram_row_index + map_row) * ouput_map_size) + 'd59 + `OUTPUT_START + map_col) << 2;
		end
		else if(cur_state == 'b1100)
		begin
			DRAM_ADDR_start	<=	(((filter_index + filter_parting)*one_filter_size) + 
								kernel_size*kernel_size*filter_channel + `WEIGHT_START) << 2;
			DRAM_ADDR_end	<=	(((filter_index + filter_parting)*one_filter_size) + 
								`WEIGHT_START + (kernel_size*kernel_size*(filter_channel+filter_channel_length)) - 1'b1) << 2;
		end
		else if(filter_parting_cur_state == 3'b011)
		begin
			DRAM_ADDR_start	<=	(((filter_index + filter_parting)*one_filter_size) + `WEIGHT_START) << 2;
			DRAM_ADDR_end	<=	(((filter_index + filter_parting)*one_filter_size) + `WEIGHT_START + 
								(kernel_size*kernel_size*filter_channel_length) - 1'b1) << 2;
		end
	end

	//col_length
	always_comb
	begin
		if(map_col + 'd64 >= map_size)
			col_length	=	map_size	-	map_col;
		else
			col_length	=	'd64;
	end
	//row_length
	always_comb
	begin
		if(map_row + 'd64 >= map_size)
			row_length	=	map_size	-	map_row;
		else
			row_length	=	'd64;
	end

	//col_index row_index
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			col_index	<=	6'b0;
			row_index	<=	6'b0;
		end
		else if(cur_state == 'b10)
		begin
			col_index	<=	map_col;
			row_index	<=	map_row;
		end
		else if(cur_state == 'b110)
		begin
			col_index	<=	col_index;
			if(row_index >=  map_row + row_length - 1'b1)
				row_index	<=	row_index;
			else
				row_index	<=	row_index + 'b1;
		end
	end

	always_comb
	begin
		if(cur_state == 'b1)
			next_row_index	=	map_row;
		else if(cur_state == 'b100)
		begin
			next_row_index	=	next_row_index	+	'b1;
		end
	end

	//BUF_ADDR_start BUF_ADDR_end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			BUF_ADDR_start	<=	7'b0;
			BUF_ADDR_end	<=	7'b0;
		end
		else if(cur_state == 4'b0011)
		begin
			BUF_ADDR_end	<=	((col_length + 2'd3) >> 2) - 'b1;
		end
	end

	//DMA_start
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			DMA_start	<=	'b0;
		else if(cur_state == 'b011)
		begin
			if(pre_state == 'b010 || pre_state == 'b110)	//DMA_start 1 cycle
				DMA_start	<=	'b1;
			else
				DMA_start	<=	'b0;
		end
		else if(cur_state == 'b1000)
		begin
			if(pre_state != 'b1000)
				DMA_start	<=	'b1;
			else
				DMA_start	<=	'b0;
		end
		else if(cur_state == 'b1100 && pre_state != 'b1100)
			DMA_start	<=	'b1;
		else if(filter_parting_cur_state == 3'b011 && filter_parting_pre_state != 3'b011)
			DMA_start	<=	'b1;
		else
			DMA_start	<=	'b0;
	end

	//DMA_buf_select
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			DMA_buf_select	<=	'b1;
		else if(cur_state == 'b011)
		begin
			if(pre_state == 'b010)
				DMA_buf_select	<=	(DMA_buf_select)?0:1;
			else
				DMA_buf_select	<=	DMA_buf_select;
		end
	end

	//read_buf_select
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			read_buf_select	<=	'b1;
		else if(cur_state == 'b100)
		begin
			if(pre_state == 'b011)
				read_buf_select	<=	(read_buf_select)?0:1;
			else
				read_buf_select	<=	read_buf_select;
		end
	end

	//input_BUF_ADDR_start
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_BUF_ADDR_start	<=	7'b0;
			input_BUF_ADDR_end		<=	7'b0;
		end
		else if(cur_state == 'b100)
		begin
			if(pre_state == 'b011)
			begin
				input_BUF_ADDR_start[7]	<=	DMA_buf_select;
				input_BUF_ADDR_start[6:0]	<=	6'b0;
				input_BUF_ADDR_end[7]	<=	DMA_buf_select;
				input_BUF_ADDR_end[6:0]		<=	((col_length + 2'd3)>>2) - 1'b1;
			end
		end
	end

	//input_buffer2sram_start
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			input_buffer2sram_start	<=	'b0;
		else if(cur_state == 'b100)
		begin
			if(pre_state == 'b011)
				input_buffer2sram_start	<=	'b1;
			else
				input_buffer2sram_start	<=	'b0;
		end
		else
			input_buffer2sram_start	<=	'b0;
	end

	//input_SRAM_ADDR_start
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			input_SRAM_ADDR_start	<=	'b0;
		else if(cur_state == 'b100)
		begin
			if(pre_state == 'b011)
			begin
				input_SRAM_ADDR_start[12:7]	<=	tile_row;
				input_SRAM_ADDR_start[6:0]	<=	7'b0;
			end
			else
			begin
				input_SRAM_ADDR_start	<=	input_SRAM_ADDR_start;
			end
		end
		else
			input_SRAM_ADDR_start	<=	'b0;
	end

	//input_SRAM_rw_select input_buffer_rw_select
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer i;
        	for(i=0;i<2;i++)
				input_buffer_rw_select[i]	<=	1'b0;
		end
		else if(cur_state == 'b011)
		begin
			integer i;
        	for(i=0;i<2;i++)
				input_buffer_rw_select[i]	<=	1'b1;
		end
		else if(cur_state == 'b100)
		begin
			integer i;
        	for(i=0;i<2;i++)
				input_buffer_rw_select[i]	<=	1'b0;
		end
		else
		begin
			integer i;
        	for(i=0;i<2;i++)
				input_buffer_rw_select[i]	<=	1'b0;
		end
	end

	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer i;
        	for(i=0;i<64;i++)
				input_SRAM_rw_select[i]	<=	1'b1;
		end
		else if(cur_state == 'b100)
		begin
			integer i;
        	for(i=0;i<64;i++)
				input_SRAM_rw_select[i]	<=	1'b1;
		end
		else if(cur_state == 'b110)
		begin
			integer i;
        	for(i=0;i<64;i++)
				input_SRAM_rw_select[i]	<=	1'b0;
		end
		else
		begin
			integer i;
        	for(i=0;i<64;i++)
				input_SRAM_rw_select[i]	<=	1'b0;
		end
	end

	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			DMA_type	<=	1'b0;
		else if(cur_state == 'b011)
			DMA_type	<=	1'b0;
		else if(cur_state == 'b1000)
			DMA_type	<=	1'b1;
		else
			DMA_type	<=	1'b0;
	end

	//DMA ouput sram to DRAM
	assign	output_sram_map_total_size	=	ouput_map_size * ouput_map_size;
	//Output_SRAM_ADDR_start
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			Output_SRAM_ADDR_start	<=	'b0;
		else if(cur_state == 'b1000)
		begin
			Output_SRAM_ADDR_start[17:12]	<=	cur_filter;
			Output_SRAM_ADDR_start[11:0]	<=	(output_sram_row_index * 'd62);
		end
	end
	//Output_SRAM_ADDR_end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			Output_SRAM_ADDR_end	<=	'b0;
		else if(cur_state == 'b1000)
		begin
			Output_SRAM_ADDR_end[17:12]	<=	cur_filter;
			Output_SRAM_ADDR_end[11:0]	<=	(output_sram_row_index * 'd62) + col_length - kernel_size;
		end
	end
	//output_sram_row_index
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			output_sram_row_index	<=	'b0;
		else if(cur_state == 'b1001)
		begin
			if(pre_state != 'b1001 && pre_state != 'b1010)
				output_sram_row_index	<=	output_sram_row_index + 'b1;
			else
				output_sram_row_index	<=	output_sram_row_index;
		end
		else if(cur_state == 'b1000)
			output_sram_row_index	<=	output_sram_row_index;
		else
			output_sram_row_index	<=	'b0;
	end
	//cur_filter
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			cur_filter	<=	'b0;
		else if(cur_state == 'b1010)
			cur_filter	<=	cur_filter + 'b1;
		else if(cur_state == 'b1000 || cur_state == 'b1001)
			cur_filter	<=	cur_filter;
		else if(cur_state == 'b0111)
			cur_filter	<=	'b0;
	end

	//SRAM_type
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			SRAM_type	<=	1'b0;
		else if(filter_parting_cur_state == 3'b011)
			SRAM_type	<=	1'b1;
		else if(cur_state == 'b1100)
			SRAM_type	<=	1'b1;
		else 
			SRAM_type	<=	1'b0;
	end

	//weight_SRAM_rw_select
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			weight_SRAM_rw_select	<=	1'b0;
		else if(filter_parting_cur_state == 3'b011)
			weight_SRAM_rw_select	<=	1'b1;
		else if(cur_state == 'b1100)
			weight_SRAM_rw_select	<=	1'b1;
		else
			weight_SRAM_rw_select	<=	1'b0;
	end

endmodule