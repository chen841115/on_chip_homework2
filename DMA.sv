module DMA(
    clk,
    rst,
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
    buf_select,
	DMA_type,
    //DRAM access
    DRAM_Q,
	DRAM_D,
    DRAM_CSn,
    DRAM_RASn,
    DRAM_CASn,
    DRAM_WEn,
    DRAM_A,
    //input_buffer access
    input_buffer_CEN_write,
    input_buffer_WEN_write,
    input_buffer_A_write,
    input_buffer_DI,
	//weight_SRAM access
    weight_SRAM_CEN_write,
    weight_SRAM_WEN_write,
    weight_SRAM_A_write,
    weight_SRAM_DI,
	//output_sram access
	output_SRAM_AB_DMA,
	output_SRAM_DO_DMA,
	output_SRAM_OEN_DMA,
	output_SRAM_CEN_DMA,
	//conv info
	kernel_size,
	//filter_parting_size1_times
	filter_parting_map_times,
	filter_parting_map_count
);
    input   clk;
    input   rst;
    input   [31:0]  DRAM_ADDR_start;
    input   [31:0]  DRAM_ADDR_end;
    input   [6:0]	BUF_ADDR_start;
	input   [6:0]	BUF_ADDR_end;
	input	[15:0]	WEIGHT_SRAM_ADDR_start;
	input	[15:0]	WEIGHT_SRAM_ADDR_end;
	input   [17:0]  Output_SRAM_ADDR_start;
    input   [17:0]  Output_SRAM_ADDR_end;
    input   DMA_start;
	input	DMA_type;	//0->read 1->write
    output  logic	DMA_done;
    input   SRAM_type;		//0->input 1->weight
    input   buf_select;

    //DRAM access
    input   [31:0]  DRAM_Q;
	output	logic	[31:0]	DRAM_D;
    output  logic   DRAM_CSn;
    output  logic   DRAM_RASn;
    output  logic   DRAM_CASn;
    output  logic   [3:0]   DRAM_WEn;
    output  logic   [12:0]  DRAM_A;

    //SRAM access
    output  logic	[31:0]	input_buffer_DI		[0:1];
	output  logic	[6:0]	input_buffer_A_write		[0:1];
	output  logic	input_buffer_CEN_write	[0:1];
	output  logic	input_buffer_WEN_write	[0:1]; 

	output  logic	[7:0]	weight_SRAM_DI		[0:287];
	output  logic	[6:0]	weight_SRAM_A_write	[0:287];
	output  logic	weight_SRAM_CEN_write		[0:287];
	output  logic	weight_SRAM_WEN_write				[0:287]; 

	//output_sram access
	output	logic	[11:0]	output_SRAM_AB_DMA	[0:31];
	input	[15:0]	output_SRAM_DO_DMA	[0:31];
	output	logic	output_SRAM_OEN_DMA;
	output	logic	output_SRAM_CEN_DMA;

	//conv info
	input	[3:0]	kernel_size;

	//filter_parting_size1_times
	input	[3:0]	filter_parting_map_times;
	input	[3:0]	filter_parting_map_count;

	logic	[17:0]	cur_addr;


    logic   [3:0]   cur_state,next_state,pre_state;
    logic   load_done;
	logic	[31:0]	DRAM_addr;
	logic	[31:0]	next_DRAM_addr;
	logic	[6:0]	input_buf_A_predict;

    logic   [7:0]  buffer	[0:48];
	logic	row_change;
	logic	read_end,read_end_predict,at_least_one;
	//DRAM -> weight 
	logic	[3:0]	DRAM_data_flag;
	logic	[7:0]	DRAM_data_count;	

	assign	DRAM_CSn	=	1'b0;

	//input buffer
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_buffer_DI[0]	<=	32'b0;
			input_buffer_DI[1]	<=	32'b0;
		end
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(DRAM_data_count	==	4'd4)
				begin
					if(buf_select == 1'b0)
						input_buffer_DI[0]	<=	{buffer[0],buffer[1],buffer[2],buffer[3]};
					else
						input_buffer_DI[1]	<=	{buffer[0],buffer[1],buffer[2],buffer[3]};
				end
			end
		end
		else
		begin
			input_buffer_DI[0]	<=	32'b0;
			input_buffer_DI[1]	<=	32'b0;
		end
	end
	//input_buffer_CEN_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_buffer_CEN_write[0]	<=	1'b1;
			input_buffer_CEN_write[1]	<=	1'b1;
		end
		else if(SRAM_type == 'b0 && DMA_type == 1'b0)
		begin
			if(buf_select == 1'b0)
				input_buffer_CEN_write[0]	<=	1'b0;
			else
				input_buffer_CEN_write[1]	<=	1'b0;
		end
		else
		begin
			input_buffer_CEN_write[0]	<=	1'b1;
			input_buffer_CEN_write[1]	<=	1'b1;
		end
	end
	//input_buffer_WEN_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_buffer_WEN_write[0]	<=	1'b1;
			input_buffer_WEN_write[1]	<=	1'b1;
		end
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(DRAM_data_count	==	4'd4)
				begin
					if(buf_select == 0)
						input_buffer_WEN_write[0]	<=	1'b0;
					else
						input_buffer_WEN_write[1]	<=	1'b0;
				end
				else
				begin
					input_buffer_WEN_write[0]	<=	1'b1;
					input_buffer_WEN_write[1]	<=	1'b1;
				end
			end
			else
			begin
				input_buffer_WEN_write[0]	<=	1'b1;
				input_buffer_WEN_write[1]	<=	1'b1;
			end
		end
		else
		begin
			input_buffer_WEN_write[0]	<=	1'b1;
			input_buffer_WEN_write[1]	<=	1'b1;
		end
	end
	//input_buffer_A_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_buffer_A_write[0]	<=	7'b0;
			input_buffer_A_write[1]	<=	7'b0;
		end
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(DRAM_data_count	==	4'd4)
				begin
					if(buf_select == 0)
						input_buffer_A_write[0]	<=	cur_addr[6:0];
					else
						input_buffer_A_write[1]	<=	cur_addr[6:0];
				end
			end
			else
			begin
				input_buffer_A_write[buf_select]	<=	7'b0;
			end
		end
		else
		begin
			input_buffer_A_write[0]	<=	7'b0;
			input_buffer_A_write[1]	<=	7'b0;
		end
	end

	//weight SRAM
	//weight_SRAM_DI
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer	i;
			for(i=0;i<32;i++)
			begin
				weight_SRAM_DI[i]	<=	8'b0;
			end
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(kernel_size == 'd3)
				begin
					if(DRAM_data_count	==	'd9)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[0];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[1];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[2];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[3];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	buffer[4];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	buffer[5];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	buffer[6];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	buffer[7];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	buffer[8];
					end
				end
				else if(kernel_size == 'd5)
				begin
					if(DRAM_data_count	==	'd23)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[2];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[7];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[12];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[17];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	buffer[22];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	buffer[3];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	buffer[8];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	buffer[13];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	buffer[18];
					end
						//weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]]	<=	{buffer[2],buffer[7],buffer[12],buffer[17],buffer[22],buffer[3],buffer[8],buffer[13],buffer[18]};
					else if(DRAM_data_count	==	'd24)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[22];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[3];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[8];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[13];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	buffer[18];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	buffer[23];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	buffer[4];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	buffer[9];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	buffer[14];
					end
						//weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]]	<=	{buffer[22],buffer[3],buffer[8],buffer[13],buffer[18],buffer[23],buffer[4],buffer[9],buffer[14]};
					else if(DRAM_data_count	==	'd25)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[18];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[23];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[4];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[9];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	buffer[14];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	buffer[19];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	buffer[24];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	8'd0;
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	8'd0;
					end
						//weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]]	<=	{buffer[18],buffer[23],buffer[4],buffer[9],buffer[14],buffer[19],buffer[24],32'b0,32'b0};
				end
				else if(kernel_size == 'd7)
				begin
					if(DRAM_data_count	==	'd44)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[5];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[12];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[19];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[26];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	buffer[33];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	buffer[40];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	buffer[47];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	buffer[6];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	buffer[13];
					end
					else if(DRAM_data_count	==	'd45)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[19];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[26];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[33];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[40];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	buffer[47];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	buffer[6];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	buffer[13];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	buffer[20];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	buffer[27];
					end
					else if(DRAM_data_count	==	'd46)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[33];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[40];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[47];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[6];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	buffer[13];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	buffer[20];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	buffer[27];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	buffer[34];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	buffer[41];
					end
					else if(DRAM_data_count	==	'd47)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[47];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[6];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[13];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[20];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	buffer[27];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	buffer[34];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	buffer[41];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	buffer[48];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	buffer[7];
					end
					else if(DRAM_data_count	==	'd48)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[13];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[20];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[27];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[34];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	buffer[41];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	buffer[48];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	buffer[7];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	buffer[14];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	buffer[21];
					end
					else if(DRAM_data_count	==	'd49)
					begin
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	buffer[27];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	buffer[34];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	buffer[41];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	buffer[48];
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	8'd0;
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	8'd0;
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	8'd0;
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	8'd0;
						weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	8'd0;
					end
						//weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]]	<=	{buffer[18],buffer[23],buffer[4],buffer[9],buffer[14],buffer[19],buffer[24],32'b0,32'b0};
				end
				else if(kernel_size == 'd1)
				begin
					if(filter_parting_map_times == 'd1)
					begin
						if(DRAM_data_count	==	'd1)
						begin
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7]]	<=	buffer[8];
						end
					end
					else if(filter_parting_map_times == 'd4)
					begin
						if(DRAM_data_count	==	'd4)
						begin
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7]]	<=	buffer[5];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd1]	<=	buffer[6];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd2]	<=	buffer[7];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd3]	<=	buffer[8];
						end
					end
					else if(filter_parting_map_times == 'd9)
					begin
						if(DRAM_data_count	==	'd9)
						begin
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7]]	<=	buffer[0];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd1]	<=	buffer[1];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd2]	<=	buffer[2];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd3]	<=	buffer[3];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd4]	<=	buffer[4];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd5]	<=	buffer[5];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd6]	<=	buffer[6];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd7]	<=	buffer[7];
							weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[15:7] + 'd8]	<=	buffer[8];
						end
					end
				end
			end
		end
		else
		begin
			integer	i;
			for(i=0;i<288;i++)
			begin
				weight_SRAM_DI[i]	<=	8'b0;
			end
		end
	end
	//weight_SRAM_CEN_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer	i;
			for(i=0;i<288;i++)
			begin
				weight_SRAM_CEN_write[i]	<=	1'b1;
			end
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			integer	i;
			for(i=0;i<288;i++)
			begin
				weight_SRAM_CEN_write[i]	<=	1'b0;
			end
		end
	end
	//weight_SRAM_WEN_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer	i;
			for(i=0;i<288;i++)
			begin
				weight_SRAM_WEN_write[i]	<=	1'b1;
			end
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(kernel_size == 'd3)
				begin
					if(DRAM_data_count	==	4'd9)
					begin
						integer	i;
						for(i=0;i<32;i++)
						begin
							if(i == WEIGHT_SRAM_ADDR_start[11:7])
							begin
								weight_SRAM_WEN_write[i*'d9 + 'd0]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd1]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd2]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd3]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd4]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd5]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd6]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd7]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd8]	<=	1'b0;
							end
								//weight_SRAM_WEN_write[i]	<=	'b0;
							else
							begin
								weight_SRAM_WEN_write[i*'d9 + 'd0]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd1]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd2]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd3]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd4]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd5]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd6]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd7]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd8]	<=	1'b1;
							end
						end
					end
					else
					begin
						integer	i;
						for(i=0;i<288;i++)
							weight_SRAM_WEN_write[i]	<=	1'b1;
					end
				end
				else if(kernel_size == 'd5)
				begin
					//if((DRAM_data_count=='d23 || DRAM_data_count=='d24||DRAM_data_count=='d25) && DRAM_data_flag[3] == 1'b1)
					if((DRAM_data_count=='d23&&DRAM_data_flag[3]==1'b1)||(DRAM_data_count=='d24&&DRAM_data_flag[3]==1'b1)||(DRAM_data_count=='d25))
					begin
						integer	i;
						for(i=0;i<32;i++)
						begin
							if(i == WEIGHT_SRAM_ADDR_start[11:7])
							begin
								weight_SRAM_WEN_write[i*'d9 + 'd0]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd1]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd2]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd3]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd4]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd5]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd6]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd7]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd8]	<=	1'b0;
							end
								//weight_SRAM_WEN_write[i]	<=	'b0;
							else
							begin
								weight_SRAM_WEN_write[i*'d9 + 'd0]	<=	'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd1]	<=	'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd2]	<=	'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd3]	<=	'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd4]	<=	'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd5]	<=	'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd6]	<=	'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd7]	<=	'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd8]	<=	'b1;
							end
						end
					end
					else
					begin
						integer	i;
						for(i=0;i<288;i++)
							weight_SRAM_WEN_write[i]	<=	'b1;
					end
				end
				else if(kernel_size == 'd7)
				begin
					//if((DRAM_data_count=='d23 || DRAM_data_count=='d24||DRAM_data_count=='d25) && DRAM_data_flag[3] == 1'b1)
					if((DRAM_data_count=='d44&&DRAM_data_flag[3]==1'b1)||(DRAM_data_count=='d45&&DRAM_data_flag[3]==1'b1)||(DRAM_data_count=='d46&&DRAM_data_flag[3]==1'b1)||
						(DRAM_data_count=='d47&&DRAM_data_flag[3]==1'b1)||(DRAM_data_count=='d48&&DRAM_data_flag[3]==1'b1)||(DRAM_data_count=='d49))
					begin
						integer	i;
						for(i=0;i<32;i++)
						begin
							if(i == WEIGHT_SRAM_ADDR_start[11:7])
							begin
								weight_SRAM_WEN_write[i*'d9 + 'd0]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd1]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd2]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd3]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd4]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd5]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd6]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd7]	<=	1'b0;
								weight_SRAM_WEN_write[i*'d9 + 'd8]	<=	1'b0;
							end
								//weight_SRAM_WEN_write[i]	<=	'b0;
							else
							begin
								weight_SRAM_WEN_write[i*'d9 + 'd0]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd1]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd2]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd3]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd4]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd5]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd6]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd7]	<=	1'b1;
								weight_SRAM_WEN_write[i*'d9 + 'd8]	<=	1'b1;
							end
						end
					end
					else
					begin
						integer	i;
						for(i=0;i<288;i++)
							weight_SRAM_WEN_write[i]	<=	'b1;
					end
				end
				else if(kernel_size == 'd1)
				begin
					if(filter_parting_map_times == 'd1)
					begin
						if(DRAM_data_count == 'd1)
						begin
							integer	i;
							for(i=0;i<288;i++)
							begin
								if(i == WEIGHT_SRAM_ADDR_start[15:7] && read_end_predict == 'b0)
								begin
									weight_SRAM_WEN_write[i]	<=	1'b0;
								end
								else
								begin
									weight_SRAM_WEN_write[i]	<=	1'b1;
									
								end
							end
						end
						else
						begin
							integer	i;
							for(i=0;i<288;i++)
								weight_SRAM_WEN_write[i]	<=	1'b1;
						end
					end
					else if(filter_parting_map_times == 'd4)
					begin
						if(DRAM_data_count == 'd4)
						begin
							integer	i;
							for(i=0;i<288;i++)
							begin
								if(read_end_predict == 'b0 && (i == WEIGHT_SRAM_ADDR_start[15:7]||i == WEIGHT_SRAM_ADDR_start[15:7]+'d1||
																i == WEIGHT_SRAM_ADDR_start[15:7]+'d2||i == WEIGHT_SRAM_ADDR_start[15:7]+'d3))
								begin
									weight_SRAM_WEN_write[i]	<=	1'b0;
								end
								else
								begin
									weight_SRAM_WEN_write[i]	<=	1'b1;
									
								end
							end
						end
						else
						begin
							integer	i;
							for(i=0;i<288;i++)
								weight_SRAM_WEN_write[i]	<=	1'b1;
						end
					end
					else if(filter_parting_map_times == 'd9)
					begin
						if(DRAM_data_count == 'd9)
						begin
							integer	i;
							for(i=0;i<288;i++)
							begin
								if(read_end_predict == 'b0 && (i == WEIGHT_SRAM_ADDR_start[15:7]||i == WEIGHT_SRAM_ADDR_start[15:7]+'d1||
																i == WEIGHT_SRAM_ADDR_start[15:7]+'d2||i == WEIGHT_SRAM_ADDR_start[15:7]+'d3||
																i == WEIGHT_SRAM_ADDR_start[15:7]+'d4||i == WEIGHT_SRAM_ADDR_start[15:7]+'d5||
																i == WEIGHT_SRAM_ADDR_start[15:7]+'d6||i == WEIGHT_SRAM_ADDR_start[15:7]+'d7||
																i == WEIGHT_SRAM_ADDR_start[15:7]+'d8))
								begin
									weight_SRAM_WEN_write[i]	<=	1'b0;
								end
								else
								begin
									weight_SRAM_WEN_write[i]	<=	1'b1;
									
								end
							end
						end
						else
						begin
							integer	i;
							for(i=0;i<288;i++)
								weight_SRAM_WEN_write[i]	<=	1'b1;
						end
					end
				end
			end
			else
			begin
				integer	i;
				for(i=0;i<288;i++)
				begin
					weight_SRAM_WEN_write[i]	<=	1'b1;
				end
			end
		end
	end
	//weight_SRAM_A_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer	i;
			for(i=0;i<288;i++)
			begin
				weight_SRAM_A_write[i]	<=	'b1111111;
			end
			at_least_one	<=	'b0;
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(kernel_size == 'd3)
				begin
					if(DRAM_data_count	==	4'd9)
					begin
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	cur_addr[6:0];
						at_least_one	<=	'b1;
					end
				end
				else if(kernel_size == 'd5)
				begin
					if(DRAM_data_count=='d23||DRAM_data_count=='d24||DRAM_data_count=='d25)
					begin
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	cur_addr[6:0];
						at_least_one	<=	'b1;
					end
				end
				else if(kernel_size == 'd7)
				begin
					if(DRAM_data_count=='d44 || DRAM_data_count=='d45 || DRAM_data_count=='d46 || DRAM_data_count=='d47 || DRAM_data_count=='d48 || DRAM_data_count=='d49)
					begin
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	cur_addr[6:0];
						weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	cur_addr[6:0];
						at_least_one	<=	'b1;
					end
				end
				else if(kernel_size == 'd1)
				begin
					if(filter_parting_map_times == 'd1)
					begin
						if(DRAM_data_count	==	'd1)
						begin
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7]]	<=	cur_addr[6:0];
							at_least_one	<=	'b1;
						end
					end
					else if(filter_parting_map_times == 'd4)
					begin
						if(DRAM_data_count	==	'd4)
						begin
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7]]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd1]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd2]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd3]	<=	cur_addr[6:0];
							at_least_one	<=	'b1;
						end
					end
					else if(filter_parting_map_times == 'd9)
					begin
						if(DRAM_data_count	==	'd9)
						begin
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7]]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd1]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd2]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd3]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd4]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd5]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd6]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd7]	<=	cur_addr[6:0];
							weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7] + 'd8]	<=	cur_addr[6:0];
							at_least_one	<=	'b1;
						end
					end
				end
			end
			else
			begin
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd0]	<=	'b1111111;
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd1]	<=	'b1111111;
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd2]	<=	'b1111111;
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd3]	<=	'b1111111;
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd4]	<=	'b1111111;
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd5]	<=	'b1111111;
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd6]	<=	'b1111111;
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd7]	<=	'b1111111;
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9 + 'd8]	<=	'b1111111;
			end
		end
		else if(cur_state == 4'b0000)
		begin
			integer	i;
			for(i=0;i<288;i++)
			begin
				weight_SRAM_A_write[i]	<=	'b1111111;
			end
			at_least_one	<=	'b0;
		end
	end
	//DRAM_data_flag
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			DRAM_data_flag	<=	4'b0;
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0011 || (cur_state == 4'b0010 && pre_state != 4'b0001))
			begin
				if(next_DRAM_addr[11:2] != 10'b0)
				begin
					DRAM_data_flag[0]	<=	1'b1;
					DRAM_data_flag[1]	<=	DRAM_data_flag[0];
					DRAM_data_flag[2]	<=	DRAM_data_flag[1];
					DRAM_data_flag[3]	<=	DRAM_data_flag[2];
				end
				else
				begin
					DRAM_data_flag[0]	<=	1'b0;
					DRAM_data_flag[1]	<=	DRAM_data_flag[0];
					DRAM_data_flag[2]	<=	DRAM_data_flag[1];
					DRAM_data_flag[3]	<=	DRAM_data_flag[2];
				end
			end
			else if(cur_state == 4'b0000)
			begin
				DRAM_data_flag[0]	<=	1'b0;
				DRAM_data_flag[1]	<=	1'b0;
				DRAM_data_flag[2]	<=	1'b0;
				DRAM_data_flag[3]	<=	1'b0;
			end
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0011 || (cur_state == 4'b0010 && pre_state != 4'b0001))
			begin
				if(next_DRAM_addr[11:2] != 10'b0)
				begin
					DRAM_data_flag[0]	<=	1'b1;
					DRAM_data_flag[1]	<=	DRAM_data_flag[0];
					DRAM_data_flag[2]	<=	DRAM_data_flag[1];
					DRAM_data_flag[3]	<=	DRAM_data_flag[2];
				end
				else
				begin
					DRAM_data_flag[0]	<=	1'b0;
					DRAM_data_flag[1]	<=	DRAM_data_flag[0];
					DRAM_data_flag[2]	<=	DRAM_data_flag[1];
					DRAM_data_flag[3]	<=	DRAM_data_flag[2];
				end
			end
			else if(cur_state == 4'b0000)
			begin
				DRAM_data_flag[0]	<=	1'b0;
				DRAM_data_flag[1]	<=	1'b0;
				DRAM_data_flag[2]	<=	1'b0;
				DRAM_data_flag[3]	<=	1'b0;
			end
		end
	end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			DRAM_data_count	<=	'd0;
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(DRAM_data_count	==	'd4)
				begin
					if(DRAM_data_flag[3] == 1'b1)
						DRAM_data_count	<=	'd1;
					else
						DRAM_data_count	<=	'd0;
				end
				else
				begin
					if(DRAM_data_flag[3] == 1'b1)
						DRAM_data_count	<=	DRAM_data_count + 1'b1;
				end
			end
			else if(cur_state == 4'b0000)
				DRAM_data_count	<=	'd0;
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(kernel_size == 'd3)
				begin
					if(DRAM_data_count	==	'd9)
					begin
						if(DRAM_data_flag[3] == 1'b1)
							DRAM_data_count	<=	4'd1;
						else
							DRAM_data_count	<=	4'd0;
					end
					else
					begin
						if(DRAM_data_flag[3] == 1'b1)
							DRAM_data_count	<=	DRAM_data_count + 1'b1;
					end
				end
				else if(kernel_size == 'd5)
				begin
					if(DRAM_data_count	==	'd25)
					begin
						if(DRAM_data_flag[3] == 1'b1)
							DRAM_data_count	<=	'd1;
						else
							DRAM_data_count	<=	'd0;
					end
					else
					begin
						if(DRAM_data_flag[3] == 1'b1)
							DRAM_data_count	<=	DRAM_data_count + 1'b1;
					end
				end
				else if(kernel_size == 'd7)
				begin
					if(DRAM_data_count	==	'd49)
					begin
						if(DRAM_data_flag[3] == 1'b1)
							DRAM_data_count	<=	'd1;
						else
							DRAM_data_count	<=	'd0;
					end
					else
					begin
						if(DRAM_data_flag[3] == 1'b1)
							DRAM_data_count	<=	DRAM_data_count + 1'b1;
					end
				end
				else if(kernel_size == 'd1)
				begin
					if(DRAM_data_count	==	filter_parting_map_times)
					begin
						if(DRAM_data_flag[3] == 1'b1)
							DRAM_data_count	<=	'd1;
						else
							DRAM_data_count	<=	'd0;
					end
					else
					begin
						if(DRAM_data_flag[3] == 1'b1)
							DRAM_data_count	<=	DRAM_data_count + 1'b1;
					end
				end
			end
			else if(cur_state == 4'b0000)
				DRAM_data_count	<=	'd0;
		end
	end


	//DRAM_WEn
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			DRAM_WEn	=	4'b1111;
		else if(DMA_type == 1'b1)
		begin
			if(cur_state >= 4'b0010)
				DRAM_WEn	=	4'b0000;
			else
				DRAM_WEn	=	4'b1111;
		end
		else
			DRAM_WEn	=	4'b1111;
	end

    always_ff @(posedge clk, posedge rst) 
    begin
		if(rst)
		begin
			integer	i;
			for(i=0;i<25;i++)
			begin
				buffer[i]	<=	8'd0;
			end
		end
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(DRAM_data_flag[3] == 1'b1)
				begin
					buffer[0]	<=	buffer[1];
					buffer[1]	<=	buffer[2];
					buffer[2]	<=	buffer[3];
					buffer[3]	<=	DRAM_Q[7:0];
				end
			end
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(kernel_size == 'd3)
			begin
				if(cur_state == 4'b0010||cur_state == 4'b0011)
				begin
					if(DRAM_data_flag[3] == 1'b1)
					begin
						buffer[0]	<=	buffer[1];
						buffer[1]	<=	buffer[2];
						buffer[2]	<=	buffer[3];
						buffer[3]	<=	buffer[4];
						buffer[4]	<=	buffer[5];
						buffer[5]	<=	buffer[6];
						buffer[6]	<=	buffer[7];
						buffer[7]	<=	buffer[8];
						buffer[8]	<=	DRAM_Q[7:0];
					end
				end
				else if(cur_state == 4'b0000)
				begin
					buffer[0]	<=	8'd0;
					buffer[1]	<=	8'd0;
					buffer[2]	<=	8'd0;
					buffer[3]	<=	8'd0;
					buffer[4]	<=	8'd0;
					buffer[5]	<=	8'd0;
					buffer[6]	<=	8'd0;
					buffer[7]	<=	8'd0;
					buffer[8]	<=	8'd0;
				end
			end
			else if(kernel_size == 'd5)
			begin
				if(cur_state == 4'b0010||cur_state == 4'b0011)
				begin
					if(DRAM_data_flag[3] == 1'b1)
					begin
						buffer[0]	<=	buffer[1];
						buffer[1]	<=	buffer[2];
						buffer[2]	<=	buffer[3];
						buffer[3]	<=	buffer[4];
						buffer[4]	<=	buffer[5];
						buffer[5]	<=	buffer[6];
						buffer[6]	<=	buffer[7];
						buffer[7]	<=	buffer[8];
						buffer[8]	<=	buffer[9];
						buffer[9]	<=	buffer[10];
						buffer[10]	<=	buffer[11];
						buffer[11]	<=	buffer[12];
						buffer[12]	<=	buffer[13];
						buffer[13]	<=	buffer[14];
						buffer[14]	<=	buffer[15];
						buffer[15]	<=	buffer[16];
						buffer[16]	<=	buffer[17];
						buffer[17]	<=	buffer[18];
						buffer[18]	<=	buffer[19];
						buffer[19]	<=	buffer[20];
						buffer[20]	<=	buffer[21];
						buffer[21]	<=	buffer[22];
						buffer[22]	<=	buffer[23];
						buffer[23]	<=	buffer[24];
						buffer[24]	<=	DRAM_Q[7:0];
					end
				end
				else if(cur_state == 4'b0000)
				begin
					buffer[0]	<=	8'd0;
					buffer[1]	<=	8'd0;
					buffer[2]	<=	8'd0;
					buffer[3]	<=	8'd0;
					buffer[4]	<=	8'd0;
					buffer[5]	<=	8'd0;
					buffer[6]	<=	8'd0;
					buffer[7]	<=	8'd0;
					buffer[8]	<=	8'd0;
					buffer[9]	<=	8'd0;
					buffer[10]	<=	8'd0;
					buffer[11]	<=	8'd0;
					buffer[12]	<=	8'd0;
					buffer[13]	<=	8'd0;
					buffer[14]	<=	8'd0;
					buffer[15]	<=	8'd0;
					buffer[16]	<=	8'd0;
					buffer[17]	<=	8'd0;
					buffer[18]	<=	8'd0;
					buffer[19]	<=	8'd0;
					buffer[20]	<=	8'd0;
					buffer[21]	<=	8'd0;
					buffer[22]	<=	8'd0;
					buffer[23]	<=	8'd0;
					buffer[24]	<=	8'd0;
				end
			end
			else if(kernel_size == 'd7)
			begin
				if(cur_state == 4'b0010||cur_state == 4'b0011)
				begin
					if(DRAM_data_flag[3] == 1'b1)
					begin
						buffer[0]	<=	buffer[1];
						buffer[1]	<=	buffer[2];
						buffer[2]	<=	buffer[3];
						buffer[3]	<=	buffer[4];
						buffer[4]	<=	buffer[5];
						buffer[5]	<=	buffer[6];
						buffer[6]	<=	buffer[7];
						buffer[7]	<=	buffer[8];
						buffer[8]	<=	buffer[9];
						buffer[9]	<=	buffer[10];
						buffer[10]	<=	buffer[11];
						buffer[11]	<=	buffer[12];
						buffer[12]	<=	buffer[13];
						buffer[13]	<=	buffer[14];
						buffer[14]	<=	buffer[15];
						buffer[15]	<=	buffer[16];
						buffer[16]	<=	buffer[17];
						buffer[17]	<=	buffer[18];
						buffer[18]	<=	buffer[19];
						buffer[19]	<=	buffer[20];
						buffer[20]	<=	buffer[21];
						buffer[21]	<=	buffer[22];
						buffer[22]	<=	buffer[23];
						buffer[23]	<=	buffer[24];
						buffer[24]	<=	buffer[25];
						buffer[25]	<=	buffer[26];
						buffer[26]	<=	buffer[27];
						buffer[27]	<=	buffer[28];
						buffer[28]	<=	buffer[29];
						buffer[29]	<=	buffer[30];
						buffer[30]	<=	buffer[31];
						buffer[31]	<=	buffer[32];
						buffer[32]	<=	buffer[33];
						buffer[33]	<=	buffer[34];
						buffer[34]	<=	buffer[35];
						buffer[35]	<=	buffer[36];
						buffer[36]	<=	buffer[37];
						buffer[37]	<=	buffer[38];
						buffer[38]	<=	buffer[39];
						buffer[39]	<=	buffer[40];
						buffer[40]	<=	buffer[41];
						buffer[41]	<=	buffer[42];
						buffer[42]	<=	buffer[43];
						buffer[43]	<=	buffer[44];
						buffer[44]	<=	buffer[45];
						buffer[45]	<=	buffer[46];
						buffer[46]	<=	buffer[47];
						buffer[47]	<=	buffer[48];
						buffer[48]	<=	DRAM_Q[7:0];
					end
				end
				else if(cur_state == 4'b0000)
				begin
					buffer[0]	<=	8'd0;
					buffer[1]	<=	8'd0;
					buffer[2]	<=	8'd0;
					buffer[3]	<=	8'd0;
					buffer[4]	<=	8'd0;
					buffer[5]	<=	8'd0;
					buffer[6]	<=	8'd0;
					buffer[7]	<=	8'd0;
					buffer[8]	<=	8'd0;
					buffer[9]	<=	8'd0;
					buffer[10]	<=	8'd0;
					buffer[11]	<=	8'd0;
					buffer[12]	<=	8'd0;
					buffer[13]	<=	8'd0;
					buffer[14]	<=	8'd0;
					buffer[15]	<=	8'd0;
					buffer[16]	<=	8'd0;
					buffer[17]	<=	8'd0;
					buffer[18]	<=	8'd0;
					buffer[19]	<=	8'd0;
					buffer[20]	<=	8'd0;
					buffer[21]	<=	8'd0;
					buffer[22]	<=	8'd0;
					buffer[23]	<=	8'd0;
					buffer[24]	<=	8'd0;
					buffer[25]	<=	8'd0;
					buffer[26]	<=	8'd0;
					buffer[27]	<=	8'd0;
					buffer[28]	<=	8'd0;
					buffer[29]	<=	8'd0;
					buffer[30]	<=	8'd0;
					buffer[31]	<=	8'd0;
					buffer[32]	<=	8'd0;
					buffer[33]	<=	8'd0;
					buffer[34]	<=	8'd0;
					buffer[35]	<=	8'd0;
					buffer[36]	<=	8'd0;
					buffer[37]	<=	8'd0;
					buffer[38]	<=	8'd0;
					buffer[39]	<=	8'd0;
					buffer[40]	<=	8'd0;
					buffer[41]	<=	8'd0;
					buffer[42]	<=	8'd0;
					buffer[43]	<=	8'd0;
					buffer[44]	<=	8'd0;
					buffer[45]	<=	8'd0;
					buffer[46]	<=	8'd0;
					buffer[47]	<=	8'd0;
					buffer[48]	<=	8'd0;
				end
			end
			else if(kernel_size == 'd1)
			begin
				if(cur_state == 4'b0010||cur_state == 4'b0011)
				begin
					if(DRAM_data_flag[3] == 1'b1)
					begin
						buffer[0]	<=	buffer[1];
						buffer[1]	<=	buffer[2];
						buffer[2]	<=	buffer[3];
						buffer[3]	<=	buffer[4];
						buffer[4]	<=	buffer[5];
						buffer[5]	<=	buffer[6];
						buffer[6]	<=	buffer[7];
						buffer[7]	<=	buffer[8];
						buffer[8]	<=	DRAM_Q[7:0];
					end
				end
				else if(cur_state == 4'b0000)
				begin
					buffer[0]	<=	8'd0;
					buffer[1]	<=	8'd0;
					buffer[2]	<=	8'd0;
					buffer[3]	<=	8'd0;
					buffer[4]	<=	8'd0;
					buffer[5]	<=	8'd0;
					buffer[6]	<=	8'd0;
					buffer[7]	<=	8'd0;
					buffer[8]	<=	8'd0;
				end
			end
		end
    end

	//DMA_done
	always_comb
	begin
		if(rst)
			DMA_done = 1'b0;
		else if(SRAM_type==1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(read_end == 1'b1)
					DMA_done = 1'b1;
				else
					DMA_done = 1'b0;
			end
			else
				DMA_done	<=	1'b0;
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(read_end == 1'b1)
					DMA_done = 1'b1;
				else
					DMA_done = 1'b0;
			end
			else
				DMA_done	<=	1'b0;
		end
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 4'b0011 && cur_addr == Output_SRAM_ADDR_end)
				DMA_done = 1'b1;
		end
		else
			DMA_done = 1'b0;
	end
	//read_end
	// always_ff @(posedge clk, posedge rst) 
	// begin
	// 	if(rst)
	// 		read_end	<=	1'b0;
	// 	else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
	// 	begin
	// 		if(cur_state == 4'b0010||cur_state == 4'b0011)
	// 		begin
	// 			if( input_buffer_A_write[buf_select] == BUF_ADDR_end)
	// 				read_end	<=	1'b1;
	// 		end
	// 		else
	// 			read_end	<=	1'b0;
	// 	end
	// 	else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
	// 	begin
	// 		if(cur_state == 4'b0010||cur_state == 4'b0011)
	// 		begin
	// 			if( weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7]] == WEIGHT_SRAM_ADDR_end[6:0])
	// 				read_end	<=	1'b1;
	// 		end
	// 		else
	// 			read_end	<=	1'b0;
	// 	end
	// 	else if(DRAM_addr == DRAM_ADDR_end && cur_state != 4'b0000)
	// 		read_end	<=	1'b1;
	// 	else if(cur_state	==	4'b0000)
	// 		read_end	<=	1'b0;
	// end
	always_comb 
	begin
		if(rst)
			read_end_predict	=	1'b0;
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if( input_buffer_A_write[buf_select] == BUF_ADDR_end)
					read_end_predict	=	1'b1;
			end
			else
				read_end_predict	=	1'b0;
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(kernel_size == 'd1)
				begin
					if( weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[15:7]] == WEIGHT_SRAM_ADDR_end[6:0] && at_least_one =='b1)
						read_end_predict	=	1'b1;
				end
				else
				begin
					if( weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]*'d9] == WEIGHT_SRAM_ADDR_end[6:0] && at_least_one =='b1)
						read_end_predict	=	1'b1;
				end
			end
			else
				read_end_predict	=	1'b0;
		end
		else if(DRAM_addr == DRAM_ADDR_end && cur_state != 4'b0000)
			read_end_predict	=	1'b1;
		else if(cur_state	==	4'b0000)
			read_end_predict	=	1'b0;
	end
	always_ff @(posedge clk, posedge rst) 
	begin
		read_end	<=	read_end_predict;
	end


    //DRAM_RASn
    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            DRAM_RASn   <=  1'b1;
		else if(SRAM_type==1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0001)
				DRAM_RASn   <=  1'b1;
			else if(cur_state > 4'b0001 && cur_state < 4'b1011)
            	DRAM_RASn   <=  1'b0;
			else
				DRAM_RASn   <=  1'b1;
		end
		else if(SRAM_type==1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0001)
				DRAM_RASn   <=  1'b1;
			else if(cur_state > 4'b0001 && cur_state < 4'b1011)
            	DRAM_RASn   <=  1'b0;
			else
				DRAM_RASn   <=  1'b1;
		end
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 4'b0001)
				DRAM_RASn   <=  1'b1;
			else if(cur_state > 4'b0001)
				DRAM_RASn   <=  1'b0;
			else
				DRAM_RASn   <=  1'b1;
		end
    end
	//DRAM_CASn
    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            DRAM_CASn   <=  1'b1;
		else if(SRAM_type==1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state > 4'b0010 && cur_state < 4'b1011)
				DRAM_CASn   <=  1'b0;
			else
				DRAM_CASn   <=  1'b1;
		end
		else if(SRAM_type==1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state > 4'b0010 && cur_state < 4'b1011)
				DRAM_CASn   <=  1'b0;
			else
				DRAM_CASn   <=  1'b1;
		end
		else if(DMA_type == 1'b1)
		begin
			if(cur_state <= 4'b0010)
				DRAM_CASn   <=  1'b1;
			else if(cur_state == 4'b0011)
				DRAM_CASn   <=  1'b0;
			else
				DRAM_CASn   <=  1'b1;
		end
    end
    //DRAM_A predict
    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            DRAM_addr	<=	'b0;
		else if(SRAM_type==1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0001 && pre_state == 4'b0000)
			begin
				DRAM_addr	<=	DRAM_ADDR_start;
			end
			else if(cur_state == 4'b0011)
			begin
				DRAM_addr	<=	DRAM_addr + 3'b100;
			end
			else if(DMA_done)
				DRAM_addr	<=	'b0;
		end
		else if(SRAM_type==1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0001 && pre_state == 4'b0000)
			begin
				DRAM_addr	<=	DRAM_ADDR_start;
			end
			else if(cur_state == 4'b0011)
			begin
				DRAM_addr	<=	DRAM_addr + 3'b100;
			end
			else if(DMA_done)
				DRAM_addr	<=	'b0;
		end
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 4'b0001 && pre_state == 4'b0000)
				DRAM_addr	<=	DRAM_ADDR_start;
			else if(cur_state == 4'b0011)
				DRAM_addr	<=	DRAM_addr + 3'b100;
			else if(DMA_done)
				DRAM_addr	<=	'b0;
		end
    end
	//DRAM_A
	always_ff @(posedge clk, posedge rst) 
    begin
		if(rst)
			DRAM_A	<=	11'b0;
		else if(SRAM_type==1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010)
				DRAM_A	<=	DRAM_addr[24:12];
			else if(cur_state == 4'b0011)
				DRAM_A	<=	{2'b0,DRAM_addr[11:2]};
			else if(DMA_done)
				DRAM_A	<=	12'b0;
		end
		else if(SRAM_type==1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010)
				DRAM_A	<=	DRAM_addr[24:12];
			else if(cur_state == 4'b0011)
				DRAM_A	<=	{2'b0,DRAM_addr[11:2]};
			else if(DMA_done)
				DRAM_A	<=	12'b0;
		end
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 4'b0010)
				DRAM_A	<=	DRAM_addr[24:12];
			else if(cur_state == 4'b0011)
				DRAM_A	<=	{2'b0,DRAM_addr[11:2]};
			else if(DMA_done)
				DRAM_A	<=	12'b0;
		end
	end


    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            pre_state   <=  4'b0;
        // else if(DMA_start == 1'b0)
        //     pre_state   <=  4'b0;
        else
            pre_state   <=  cur_state;
    end

    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            cur_state   <=  4'b0;
        // else if(DMA_start == 1'b0)
        //     cur_state   <=  4'b0;
        else
            cur_state   <=  next_state;
    end

	//next_DRAM_addr
	assign next_DRAM_addr = DRAM_addr + 3'b100;
	// always_ff @(posedge clk, posedge rst)
	// begin
	// 	if(rst)
	// 		next_DRAM_addr	<=	32'b0;
	// 	else if(cur_state == 4'b0010)
	// 		next_DRAM_addr	<=	DRAM_addr + 3'b100;
	// end

	//output sram access
	//cur_addr
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			cur_addr	<=	'b0;
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0001 || pre_state == 4'b0000)
				cur_addr[6:0]	<=	7'b0;
			else if(DRAM_data_count	==	'd4)
				cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0001 || pre_state == 4'b0000)
				cur_addr[6:0]	<=	7'b0;
			else if(kernel_size == 'd3)
			begin
				if(DRAM_data_count	==	'd9)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
			end
			else if(kernel_size == 'd5)
			begin
				if(DRAM_data_count	==	'd23 && DRAM_data_flag[3] == 1'b1)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				else if(DRAM_data_count	==	'd24 && DRAM_data_flag[3] == 1'b1)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				else if(DRAM_data_count	==	'd25)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				// if(DRAM_data_flag[3] == 1'b1)
				// begin
				// 	if(DRAM_data_count	==	'd23)
				// 		cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				// 	else if(DRAM_data_count	==	'd24)
				// 		cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				// 	else if(DRAM_data_count	==	'd25)
				// 		cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				// end
			end
			else if(kernel_size == 'd7)
			begin
				if(DRAM_data_count	==	'd44 && DRAM_data_flag[3] == 1'b1)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				else if(DRAM_data_count	==	'd45 && DRAM_data_flag[3] == 1'b1)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				else if(DRAM_data_count	==	'd46 && DRAM_data_flag[3] == 1'b1)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				else if(DRAM_data_count	==	'd47 && DRAM_data_flag[3] == 1'b1)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				else if(DRAM_data_count	==	'd48 && DRAM_data_flag[3] == 1'b1)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;	
				else if(DRAM_data_count	==	'd49)
					cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
			end
			else if(kernel_size == 'd1)
			begin
				if(filter_parting_map_times == 'd1)
				begin
					if(DRAM_data_count	==	'd1)
						cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				end
				else if(filter_parting_map_times == 'd4)
				begin
					if(DRAM_data_count	==	'd4)
						cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				end
				else if(filter_parting_map_times == 'd9)
				begin
					if(DRAM_data_count	==	'd9)
						cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
				end
			end
		end
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 4'b0001 || pre_state == 4'b0000)
				cur_addr	<=	Output_SRAM_ADDR_start;
			else if(cur_state == 4'b0011)
				cur_addr	<=	cur_addr + 1'b1;
			else
				cur_addr	<=	cur_addr;
		end
	end
	//output_SRAM_OEN_DMA
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			output_SRAM_OEN_DMA	<=	'b1;
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 'b0001)
				output_SRAM_OEN_DMA	<=	'b0;
		end
		else
			output_SRAM_OEN_DMA	<=	'b1;
	end
	//output_SRAM_CEN_DMA
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			output_SRAM_CEN_DMA	<=	'b0;
		// else if(DMA_type == 1'b1)
		// begin
		// 	if(cur_state == 'b0001)
		// 		output_SRAM_CEN_DMA	<=	'b0;
		// end
		else
			output_SRAM_CEN_DMA	<=	'b0;
	end
	//output_SRAM_AB_DMA
	// always_ff @(posedge clk, posedge rst)
	// begin
	// 	if(rst)
	// 	begin
	// 		integer	i;
	// 		for(i=0;i<32;i++)
	// 		begin
	// 			output_SRAM_AB_DMA[i]	<=	12'b0;
	// 		end
	// 	end
	// 	else if(DMA_type == 1'b1)
	// 	begin
	// 		if(cur_state == 'b0001)
	// 			output_SRAM_AB_DMA[cur_addr[17:12]]	<=	cur_addr;
	// 	end
	// 	else
	// 		output_SRAM_AB_DMA[cur_addr[17:12]]	<=	'b0;
	// end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer	i;
			for(i=0;i<32;i++)
			begin
				output_SRAM_AB_DMA[i]	<=	12'b0;
			end
		end
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 'b0001)
			begin
				if(pre_state == 'b0000)
					output_SRAM_AB_DMA[Output_SRAM_ADDR_start[17:12]]	<=	Output_SRAM_ADDR_start;
				else
					output_SRAM_AB_DMA[Output_SRAM_ADDR_start[17:12]]	<=	output_SRAM_AB_DMA[Output_SRAM_ADDR_start[17:12]];
			end
			else if(cur_state == 4'b0010  && DRAM_addr[11:2] != 10'd1023)//&& DRAM_addr[11:2] != 10'd1022)
				output_SRAM_AB_DMA[Output_SRAM_ADDR_start[17:12]]	<=	output_SRAM_AB_DMA[Output_SRAM_ADDR_start[17:12]] + 1'b1;
			else if(cur_state == 4'b0011 && DRAM_addr[11:2] != 10'd1022)
				output_SRAM_AB_DMA[Output_SRAM_ADDR_start[17:12]]	<=	output_SRAM_AB_DMA[Output_SRAM_ADDR_start[17:12]] + 1'b1;
			else
				output_SRAM_AB_DMA[Output_SRAM_ADDR_start[17:12]]	<=	output_SRAM_AB_DMA[Output_SRAM_ADDR_start[17:12]];
		end
		else
			output_SRAM_AB_DMA[cur_addr[17:12]]	<=	'b0;
	end
	//output_SRAM_DO_DMA -> DRAM_D
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			DRAM_D	<=	'b0;
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 4'b0010 || cur_state == 4'b0011)
				DRAM_D	<=	output_SRAM_DO_DMA[cur_addr[17:12]];
			else
				DRAM_D	<=	'b0;
		end
	end

    always_comb 
    begin
        if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			case(cur_state)
				4'b0000: 
					if(DMA_start)
						next_state = 4'b0001;
					else
						next_state = 4'b0000;
				4'b0001:
					next_state = 4'b0010;
				4'b0010:
					next_state = 4'b0011;
				4'b0011:
					if(DMA_done)
						next_state = 4'b0000;
					else if(next_DRAM_addr[11:2] == 10'b0)
						next_state = 4'b0010;
					else
						next_state = 4'b0011;
				4'b0100:
					next_state = 4'b0101;
				4'b0101:
					next_state = 4'b0110;
				4'b0110:
					next_state = 4'b0111;
				4'b0111:
					next_state = 4'b1000;
				4'b1000:
					next_state = 4'b1001;
				4'b1001:
					next_state = 4'b1010;
				4'b1010:
					if(DMA_done)
						next_state = 4'b0000;
					else
						next_state = 4'b0001;
				default:
					next_state = 4'b0000;
			endcase
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			case(cur_state)
				4'b0000: 
					if(DMA_start)
						next_state = 4'b0001;
					else
						next_state = 4'b0000;
				4'b0001:
					next_state = 4'b0010;
				4'b0010:
					next_state = 4'b0011;
				4'b0011:
					if(DMA_done)
						next_state = 4'b0000;
					else if(next_DRAM_addr[11:2] == 10'b0)
						next_state = 4'b0010;
					else
						next_state = 4'b0011;
				4'b0100:
					next_state = 4'b0101;
				4'b0101:
					next_state = 4'b0110;
				4'b0110:
					next_state = 4'b0111;
				4'b0111:
					next_state = 4'b1000;
				4'b1000:
					next_state = 4'b1001;
				4'b1001:
					next_state = 4'b1010;
				4'b1010:
					next_state = 4'b1011;
				4'b1011:
					next_state = 4'b1100;
				4'b1100:
					next_state = 4'b1101;
				4'b1101:
					next_state = 4'b1110;
				4'b1110:
					next_state = 4'b1111;
				4'b1111:
					if(DMA_done)
						next_state = 4'b0000;
					else
						next_state = 4'b0001;
				default:
					next_state = 4'b000;
			endcase
		end
		else if(DMA_type == 1'b1)
		begin
			case(cur_state)
				4'b0000: 
					if(DMA_start)
						next_state = 4'b0001;
					else
						next_state = 4'b0000;
				4'b0001:
					next_state = 4'b0010;
				4'b0010:
					next_state = 4'b0011;
				4'b0011:
					if(DMA_done)
						next_state = 4'b0000;
					else if(next_DRAM_addr[11:2] == 10'b0)
						next_state = 4'b0010;
					else
						next_state = 4'b0011;
				default:
					next_state = 4'b0000;
			endcase
		end
		else
			next_state = 4'b0000;
    end

endmodule