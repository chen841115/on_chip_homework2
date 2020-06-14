`define OUTPUT_START 'h180000
module transfer_controller(
    clk,
    rst,
    run,
	//controller
	row_end,
	col_end,
	controller_run,
	cur_channel,
    //DMA
    DRAM_ADDR_start,
    DRAM_ADDR_end,
    BUF_ADDR_start,
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
	output_sram_read_select
);

    input   clk;
    input   rst;
    input   run;
	//controller
	output	logic	[5:0]	row_end;
	output	logic	[5:0]	col_end;
	output	logic	controller_run;
    //DMA
    output	logic	[31:0]	DRAM_ADDR_start;
    output	logic	[31:0]	DRAM_ADDR_end;
    output	logic	[6:0]	BUF_ADDR_start;
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
	output	logic	input_SRAM_ready	[0:51];
	input	[2:0]	controller_cur_state;
	input	[5:0]	controller_cur_row;
	output	logic	transfer_controller_done;
	//input_SRAM_rw_select input_buffer_rw_select
	output	logic	input_SRAM_rw_select	[0:51];
	output	logic	input_buffer_rw_select	[0:1];
	output	logic	output_sram_read_select;
	output	logic	DMA_type;

    //
    logic   [9:0]   map_col;
    logic   [9:0]   map_row;
    logic   [5:0]   col_length;
    logic   [5:0]   row_length;
	logic	[3:0]	cur_state,next_state,pre_state;
	logic	[9:0]	col_index,next_col_index;
	logic	[9:0]	row_index,next_row_index;
	logic	[5:0]	tile_col,tile_row;
	logic	buffer1_write_ready,buffer2_write_ready;
	output	logic	[9:0]	cur_channel;
	logic	[19:0]	map_addr_offset;
	logic	[21:0]	channal_addr_offset;
	// DMA_type = 1
	logic	[5:0]	output_sram_row_index;
	logic	[19:0]	output_sram_map_total_size;
	logic	[15:0]	cur_filter;

	logic	read_buf_select;

	assign	SRAM_type	=	1'b0;
	assign	tile_col	=	col_index	-	map_col;
	assign	tile_row	=	row_index	-	map_row;
	assign	row_end	=	row_length	-	1'b1;
	assign	col_end	=	col_length	-	1'b1;


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
			'b00:
				if(run)
					next_state	=	'b1;
				else
					next_state	=	'b0;
			'b01:
				next_state	=	'b10;
			'b10:
				if(~DMA_done)
					next_state	=	'b11;
				else
					next_state	=	'b10;
			'b11:
				if(DMA_done)
					next_state	=	'b100;
				else
					next_state	=	'b11;
			'b100:
				if(input_buffer2sram_done)
					next_state	=	'b110;
				else
					next_state	=	'b100;
			'b101:
				// if(tile_done)
				// 	next_state	=	'b001;
				if(tile_done)
				begin
					if(cur_channel	<	channel - 1'b1)
						next_state	=	'b010;
					else
						next_state	=	'b111;
				end
				else
					next_state	=	'b101;
			'b110:
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
			'b111:
				next_state	=	'b1000;
				//next_state	=	'b010;
			'b1000:
				if(DMA_done)
				begin
					if(output_sram_row_index >= 49)
						next_state	=	'b1010;
					else
						next_state	=	'b1001;
				end
				else
					next_state	=	'b1000;
			'b1001:
				if(cur_filter >= kernel_num)
					next_state	=	'b001;
				else if(~DMA_done)
					next_state	=	'b1000;
				else 
					next_state	=	'b1001;
			'b1010:
				next_state	=	'b1001;

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
	assign channal_addr_offset = cur_channel*map_size*map_size;
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			cur_channel	<=	1'b1;
		else if(cur_state == 4'b0010 && pre_state != 4'b0001)
			cur_channel	<=	cur_channel	+	1'b1;
		else if(cur_state == 4'b0001)
			cur_channel	<=	1'b0;
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
						if(map_col + 'd52 >= map_size)
						begin
							if(map_row + 'd52 >= map_size)
							begin
								transfer_controller_done	<=	1'b1;
								map_col	<=	10'b0;
								map_row <=	10'b0;
							end
							else
							begin
								map_col	<=	10'b0;
								map_row	<=	map_row	+	'd50;
							end
						end
						else
						begin
							map_col	<=	map_col	+	'd50;
							map_row	<=	map_row;
						end
					end
				end
			end
		end
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
			DRAM_ADDR_start	<=	((output_sram_map_total_size * cur_filter) + (output_sram_row_index * ouput_map_size) + `OUTPUT_START + map_col) << 2;
			DRAM_ADDR_end	<=	((output_sram_map_total_size * cur_filter) + (output_sram_row_index * ouput_map_size) + 'd49 + `OUTPUT_START + map_col) << 2;
		end
	end

	//col_length
	always_comb
	begin
		if(map_col + 'd52 >= map_size)
			col_length	=	map_size	-	map_col;
		else
			col_length	=	'd52;
	end
	//row_length
	always_comb
	begin
		if(map_row + 'd52 >= map_size)
			row_length	=	map_size	-	map_row;
		else
			row_length	=	'd52;
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

	//BUF_ADDR_start
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			BUF_ADDR_start	<=	7'b0;
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
				input_BUF_ADDR_end[6:0]		<=	(col_length>>2) - 1'b1;
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
        	for(i=0;i<52;i++)
				input_SRAM_rw_select[i]	<=	1'b1;
		end
		else if(cur_state == 'b100)
		begin
			integer i;
        	for(i=0;i<52;i++)
				input_SRAM_rw_select[i]	<=	1'b1;
		end
		else if(cur_state == 'b110)
		begin
			integer i;
        	for(i=0;i<52;i++)
				input_SRAM_rw_select[i]	<=	1'b0;
		end
		else
		begin
			integer i;
        	for(i=0;i<52;i++)
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
			Output_SRAM_ADDR_start[11:0]	<=	(output_sram_row_index * 'd50);
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
			Output_SRAM_ADDR_end[11:0]	<=	(output_sram_row_index * 'd50) + col_length - kernel_size;
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
			output_sram_row_index	<=	map_row;
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


endmodule