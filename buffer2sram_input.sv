module  buffer2sram_input(
	clk,
	rst,
	BUF_ADDR_start,
	BUF_ADDR_end,
	SRAM_ADDR_start,
	buffer2sram_start,
	buffer2sram_done,
	//input_buffer
	input_buffer_DO,
	input_buffer_CEN_read,
	input_buffer_A_read,
	input_buffer_OEN,
	//input_sram
	input_SRAM_DI,
	input_SRAM_A_write,
	input_SRAM_CEN_write,
	input_SRAM_WEN   
);
	input	clk;
	input	rst;
	input	[7:0]	BUF_ADDR_start;
	input	[7:0]	BUF_ADDR_end;
	input	[12:0]	SRAM_ADDR_start;
	input	buffer2sram_start;
	output  logic   buffer2sram_done;

	input   [31:0]	input_buffer_DO	[0:1];
	output  logic   [6:0]   input_buffer_A_read [0:1];
	output  logic   input_buffer_CEN_read   [0:1];
	output  logic   input_buffer_OEN    [0:1];

	output  logic   [31:0]	input_SRAM_DI	    [0:63];
	output  logic   [6:0]   input_SRAM_A_write  [0:63];
	output  logic   input_SRAM_CEN_write	[0:63];
	output  logic	input_SRAM_WEN	[0:63];

	logic	[3:0]	cur_state,next_state,pre_state,pre_sec_state;
	logic	[6:0]	next_SRAM_A;
	logic	buf_read_done;
	logic	buf_select;
	logic	[5:0]	sram_select;

	assign	buf_select	=	BUF_ADDR_start[7];
	assign	sram_select	=	SRAM_ADDR_start[12:7];


	always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            pre_state   <=  4'b0;
        else
            pre_state   <=  cur_state;
    end

	always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            pre_sec_state	<=  4'b0;
        else
            pre_sec_state	<=	pre_state;
    end

	always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            cur_state   <=  4'b0;
        else
            cur_state   <=  next_state;
    end

	always_comb
	begin
		case(cur_state)
			4'b0000:
				if(buffer2sram_start)
					next_state = 4'b0001;
				else
					next_state = 4'b0000;
			4'b0001:
					next_state = 4'b0010;
			4'b0010:
					next_state = 4'b0011;
			4'b0011:
					if(buf_read_done)
						next_state = 4'b0000;
					else
						next_state = 4'b0011;
			default:
					next_state = 4'b0000;
		endcase
	end

	//input_buffer_A_read
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_buffer_A_read[0]	<=	'b0;
			input_buffer_A_read[1]	<=	'b0;
		end
		else if(cur_state == 4'b0010)
		begin
			input_buffer_A_read[buf_select]	<=	BUF_ADDR_start[6:0];
		end
		else if(cur_state == 4'b0011)
		begin
			input_buffer_A_read[buf_select]	<=	input_buffer_A_read[buf_select]+'b1;
		end
		else
		begin
			input_buffer_A_read[0]	<=	'b0;
			input_buffer_A_read[1]	<=	'b0;
		end
	end

	//input_SRAM_A_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_SRAM_A_write[i])
				input_SRAM_A_write[i]	<=	'b0;
		end
		else if(cur_state == 4'b0011)
		begin
			if(pre_sec_state == 4'b0010 && pre_state == 4'b0011)
				input_SRAM_A_write[sram_select]	<=	SRAM_ADDR_start[6:0];
			else if(pre_sec_state == 4'b0011 && pre_state == 4'b0011)
				input_SRAM_A_write[sram_select]	<=	input_SRAM_A_write[sram_select] + 'b1;
		end
		else
		begin
			input_SRAM_A_write[0]	<=	'b0;
			input_SRAM_A_write[1]	<=	'b0;
		end
	end

	//buffer2sram_done
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			buf_read_done	<=	'b0;
		else if(cur_state == 4'b0011)
		begin
			if(input_buffer_A_read[buf_select]	==	BUF_ADDR_end[6:0])
				buf_read_done	<=	'b1;
		end
		else
			buf_read_done	<=	'b0;
	end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			buffer2sram_done	<=	'b0;
		end
		else
			buffer2sram_done	<=	buf_read_done;
	end

	//input_SRAM_DI
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_SRAM_DI[i])
				input_SRAM_DI[i]	<=	'b0;
		end
		else if(cur_state == 4'b0011)
		begin
			input_SRAM_DI[sram_select]	<=	input_buffer_DO[buf_select];
		end
	end

	//input_buffer_CEN_read
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_buffer_CEN_read[i])
				input_buffer_CEN_read[i]	<=	'b1;
		end
		else if(cur_state == 4'b0010)
			input_buffer_CEN_read[buf_select]	<=	'b0;
		else if(cur_state == 4'b0011)
			input_buffer_CEN_read[buf_select]	<=	'b0;
	end
	//input_buffer_OEN
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_buffer_OEN[i])
				input_buffer_OEN[i]	<=	'b1;
		end
		else if(cur_state == 4'b0010)
			input_buffer_OEN[buf_select]	<=	'b0;
		else if(cur_state == 4'b0011)
			input_buffer_OEN[buf_select]	<=	'b0;
		else 
		begin
			foreach(input_buffer_OEN[i])
				input_buffer_OEN[i]	<=	'b1;
		end	
	end

	//input_SRAM_CEN_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_SRAM_CEN_write[i])
				input_SRAM_CEN_write[i]	<=	'b1;
		end
		else if(cur_state == 4'b0011)
			input_SRAM_CEN_write[sram_select]	<=	'b0;
		else
		begin
			foreach(input_SRAM_CEN_write[i])
				input_SRAM_CEN_write[i]	<=	'b1;
		end
	end
	//input_SRAM_WEN
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			foreach(input_SRAM_WEN[i])
				input_SRAM_WEN[i]	<=	'b1;
		end
		else if(cur_state == 4'b0011 && pre_state != 4'b0010)
			input_SRAM_WEN[sram_select]	<=	'b0;
		else
		begin
			foreach(input_SRAM_WEN[i])
				input_SRAM_WEN[i]	<=	'b1;
		end
	end

endmodule