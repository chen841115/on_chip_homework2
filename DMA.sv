module DMA(
    clk,
    rst,
    DRAM_ADDR_start,
    DRAM_ADDR_end,
    BUF_ADDR_start,
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
    input_buffer_CEN,
    input_buffer_WEN,
    input_buffer_A,
    input_buffer_DI,
	//weight_SRAM access
    weight_SRAM_CEN_write,
    weight_SRAM_WEN,
    weight_SRAM_A_write,
    weight_SRAM_DI,
	//output_sram access
	output_SRAM_AB_DMA,
	output_SRAM_DO_DMA,
	output_SRAM_OEN_DMA,
	output_SRAM_CEN_DMA,
	//conv info
	kernel_size
);
    input   clk;
    input   rst;
    input   [31:0]  DRAM_ADDR_start;
    input   [31:0]  DRAM_ADDR_end;
    input   [6:0]	BUF_ADDR_start;
	input	[12:0]	WEIGHT_SRAM_ADDR_start;
	input	[12:0]	WEIGHT_SRAM_ADDR_end;
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
    output  logic   [11:0]  DRAM_A;

    //SRAM access
    output  logic	[127:0]	input_buffer_DI		[0:1];
	output  logic	[6:0]	input_buffer_A		[0:1];
	output  logic	input_buffer_CEN	[0:1];
	output  logic	input_buffer_WEN	[0:1]; 

	output  logic	[287:0]	weight_SRAM_DI		[0:31];
	output  logic	[6:0]	weight_SRAM_A_write	[0:31];
	output  logic	weight_SRAM_CEN_write		[0:31];
	output  logic	weight_SRAM_WEN				[0:31]; 

	//output_sram access
	output	logic	[11:0]	output_SRAM_AB_DMA	[0:31];
	input	[31:0]	output_SRAM_DO_DMA	[0:31];
	output	logic	output_SRAM_OEN_DMA;
	output	logic	output_SRAM_CEN_DMA;

	//conv info
	input	[3:0]	kernel_size;

	logic	[17:0]	cur_addr;


    logic   [3:0]   cur_state,next_state,pre_state;
    logic   load_done;
	logic	[31:0]	DRAM_addr;
	logic	[31:0]	next_DRAM_addr;
	logic	[6:0]	input_buf_A_predict;

    logic   [31:0]  buffer[0:8];
	logic	row_change;
	logic	read_end;
	//DRAM -> weight 
	logic	[3:0]	DRAM_data_weight_flag;
	logic	[3:0]	DRAM_data_weight_count;	

	assign	DRAM_CSn	=	1'b0;

	//input buffer
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_buffer_DI[0]	<=	128'b1;
			input_buffer_DI[1]	<=	128'b0;
		end
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(buf_select == 1'b0)
			begin
				if(cur_state == 4'b1010)
					input_buffer_DI[0]	<=	{buffer[0],buffer[1],buffer[2],buffer[3]};
			end
			else
			begin
				if(cur_state == 4'b1010)
					input_buffer_DI[1]	<=	{buffer[0],buffer[1],buffer[2],buffer[3]};
			end
		end
		else
		begin
			input_buffer_DI[0]	<=	128'b0;
			input_buffer_DI[1]	<=	128'b0;
		end
	end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_buffer_CEN[0]	<=	1'b1;
			input_buffer_CEN[1]	<=	1'b1;
		end
		else if(SRAM_type == 'b0 && DMA_type == 1'b0)
		begin
			if(buf_select == 1'b0)
			begin
				if(cur_state == 4'b1010)
					input_buffer_CEN[0]	<=	1'b0;
				else
					input_buffer_CEN[0]	<=	1'b1;
			end
			else
			begin
				if(cur_state == 4'b1010)
					input_buffer_CEN[1]	<=	1'b0;
				else
					input_buffer_CEN[1]	<=	1'b1;
			end
		end
		else
		begin
			input_buffer_CEN[0]	<=	1'b1;
			input_buffer_CEN[1]	<=	1'b1;
		end
	end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_buffer_WEN[0]	<=	1'b1;
			input_buffer_WEN[1]	<=	1'b1;
		end
		else if(SRAM_type == 'b0 && DMA_type == 1'b0)
		begin
			if(buf_select == 0)
			begin
				if(cur_state == 4'b1010)
					input_buffer_WEN[0]	<=	1'b0;
				else
					input_buffer_WEN[0]	<=	1'b1;
			end
			else
			begin
				if(cur_state == 4'b1010)
					input_buffer_WEN[1]	<=	1'b0;
				else
					input_buffer_WEN[1]	<=	1'b1;
			end
		end
		else
		begin
			input_buffer_WEN[0]	<=	1'b1;
			input_buffer_WEN[1]	<=	1'b1;
		end
	end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			input_buffer_A[0]	<=	6'b0;
			input_buffer_A[1]	<=	6'b0;
		end
		else if(SRAM_type == 'b0 && DMA_type == 1'b0)
		begin
			if(buf_select == 0)
			begin
				if(cur_state == 4'b0001)
				begin
					if(pre_state == 4'b0000)
						input_buffer_A[0]	<=	BUF_ADDR_start;
					else
						input_buffer_A[0]	<=	input_buffer_A[0] + 7'b1;
				end
			end
			else
			begin
				if(cur_state == 4'b0001)
				begin
					if(pre_state == 4'b0000)
						input_buffer_A[1]	<=	BUF_ADDR_start;
					else
						input_buffer_A[1]	<=	input_buffer_A[1] + 7'b1;
				end
			end
		end
		else
		begin
			input_buffer_A[0]	<=	6'b0;
			input_buffer_A[1]	<=	6'b0;
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
				weight_SRAM_DI[i]	<=	'b0;
			end
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(DRAM_data_weight_count	==	4'd9)
					weight_SRAM_DI[WEIGHT_SRAM_ADDR_start[11:7]]	<=	{buffer[0],buffer[1],buffer[2],buffer[3],buffer[4],buffer[5],buffer[6],buffer[7],buffer[8]};
			end
		end
		else
		begin
			integer	i;
			for(i=0;i<32;i++)
			begin
				weight_SRAM_DI[i]	<=	'b0;
			end
		end
	end
	//weight_SRAM_CEN_write
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer	i;
			for(i=0;i<32;i++)
			begin
				weight_SRAM_CEN_write[i]	<=	'b1;
			end
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			integer	i;
			for(i=0;i<32;i++)
			begin
				weight_SRAM_CEN_write[i]	<=	'b0;
			end
		end
	end
	//weight_SRAM_WEN
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
		begin
			integer	i;
			for(i=0;i<32;i++)
			begin
				weight_SRAM_WEN[i]	<=	'b1;
			end
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(DRAM_data_weight_count	==	4'd9)
				begin
					integer	i;
					for(i=0;i<32;i++)
					begin
						if(i == WEIGHT_SRAM_ADDR_start[11:7])
							weight_SRAM_WEN[i]	<=	'b0;
						else
							weight_SRAM_WEN[i]	<=	'b1;
					end
				end
				else
				begin
					integer	i;
					for(i=0;i<32;i++)
						weight_SRAM_WEN[i]	<=	'b1;
				end
			end
			else
			begin
				integer	i;
				for(i=0;i<32;i++)
				begin
					weight_SRAM_WEN[i]	<=	'b1;
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
			for(i=0;i<32;i++)
			begin
				weight_SRAM_A_write[i]	<=	'b0;
			end
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(DRAM_data_weight_count	==	4'd9)
					weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]]	<=	cur_addr[6:0];
			end
			else
			begin
				weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]]	<=	'b0;
			end
		end
		else if(cur_state == 4'b0000)
		begin
			integer	i;
			for(i=0;i<32;i++)
			begin
				weight_SRAM_A_write[i]	<=	'b0;
			end
		end
	end
	//DRAM_data_weight_flag
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			DRAM_data_weight_flag	<=	4'b0;
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0011)
			begin
				if(next_DRAM_addr[11:2] != 10'b0)
				begin
					DRAM_data_weight_flag[0]	<=	1'b1;
					DRAM_data_weight_flag[1]	<=	DRAM_data_weight_flag[0];
					DRAM_data_weight_flag[2]	<=	DRAM_data_weight_flag[1];
					DRAM_data_weight_flag[3]	<=	DRAM_data_weight_flag[2];
				end
				else
				begin
					DRAM_data_weight_flag[0]	<=	1'b0;
					DRAM_data_weight_flag[1]	<=	DRAM_data_weight_flag[0];
					DRAM_data_weight_flag[2]	<=	DRAM_data_weight_flag[1];
					DRAM_data_weight_flag[3]	<=	DRAM_data_weight_flag[2];
				end
			end
			else if(cur_state == 4'b0000)
			begin
				DRAM_data_weight_flag[0]	<=	1'b0;
				DRAM_data_weight_flag[1]	<=	1'b0;
				DRAM_data_weight_flag[2]	<=	1'b0;
				DRAM_data_weight_flag[3]	<=	1'b0;
				DRAM_data_weight_flag[4]	<=	1'b0;
				DRAM_data_weight_flag[5]	<=	1'b0;
				DRAM_data_weight_flag[6]	<=	1'b0;
				DRAM_data_weight_flag[7]	<=	1'b0;
				DRAM_data_weight_flag[8]	<=	1'b0;
			end
		end
	end
	always_ff @(posedge clk, posedge rst)
	begin
		if(rst)
			DRAM_data_weight_count	<=	4'd0;
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if(DRAM_data_weight_count	==	4'd9)
				begin
					if(DRAM_data_weight_flag[3] == 1'b1)
						DRAM_data_weight_count	<=	4'd1;
					else
						DRAM_data_weight_count	<=	4'd0;
				end
				else
				begin
					if(DRAM_data_weight_flag[3] == 1'b1)
						DRAM_data_weight_count	<=	DRAM_data_weight_count + 1'b1;
				end
			end
			else if(cur_state == 4'b0000)
				DRAM_data_weight_count	<=	4'd0;
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
			for(i=0;i<9;i++)
			begin
				buffer[i]	<=	32'd0;
			end
		end
		else if(SRAM_type == 1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0110)
				buffer[0]	<=	DRAM_Q;
			else if(cur_state == 4'b0111)
				buffer[1]	<=	DRAM_Q;
			else if(cur_state == 4'b1000)
				buffer[2]	<=	DRAM_Q;
			else if(cur_state == 4'b1001)
				buffer[3]	<=	DRAM_Q;
		end
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(kernel_size == 'd3)
			begin
				if(cur_state == 4'b0010||cur_state == 4'b0011)
				begin
					if(DRAM_data_weight_flag[3] == 1'b1)
					begin
						buffer[0]	<=	buffer[1];
						buffer[1]	<=	buffer[2];
						buffer[2]	<=	buffer[3];
						buffer[3]	<=	buffer[4];
						buffer[4]	<=	buffer[5];
						buffer[5]	<=	buffer[6];
						buffer[6]	<=	buffer[7];
						buffer[7]	<=	buffer[8];
						buffer[8]	<=	DRAM_Q;
					end
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
			if(cur_state == 4'b1010 && read_end == 1'b1)
				DMA_done = 1'b1;
			else
				DMA_done = 1'b0;
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
		end
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 4'b0011 && cur_addr == Output_SRAM_ADDR_end)
				DMA_done = 1'b1;
		end
		else
			DMA_done = 1'b0;
	end
	//
	always_ff @(posedge clk, posedge rst) 
	begin
		if(rst)
			read_end	<=	1'b0;
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010||cur_state == 4'b0011)
			begin
				if( weight_SRAM_A_write[WEIGHT_SRAM_ADDR_start[11:7]] == WEIGHT_SRAM_ADDR_end[6:0])
					read_end	<=	1'b1;
			end
		end
		else if(DRAM_addr == DRAM_ADDR_end && cur_state != 4'b0000)
			read_end	<=	1'b1;
		else if(cur_state	==	4'b0000)
			read_end	<=	1'b0;
	end

    //DRAM_RASn
    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst)
            DRAM_RASn   <=  1'b1;
		else if(SRAM_type==1'b0 && DMA_type == 1'b0)
		begin
			if(cur_state > 4'b0000 && cur_state < 4'b0110)
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
			if(cur_state > 4'b0001 && cur_state < 4'b0110)
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
			if(cur_state == 4'b0000 && DMA_start == 1'b1)
			begin
				DRAM_addr	<=	DRAM_ADDR_start;
			end
			else if(cur_state>4'b0001 && cur_state < 4'b0110)
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
			if(cur_state == 4'b0001)
				DRAM_A	<=	DRAM_addr[23:12];
			else if(cur_state>4'b0001 && cur_state < 4'b0110)
				DRAM_A	<=	{2'b0,DRAM_addr[11:2]};
			else if(DMA_done)
				DRAM_A	<=	12'b0;
		end
		else if(SRAM_type==1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0010)
				DRAM_A	<=	DRAM_addr[23:12];
			else if(cur_state == 4'b0011)
				DRAM_A	<=	{2'b0,DRAM_addr[11:2]};
			else if(DMA_done)
				DRAM_A	<=	12'b0;
		end
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 4'b0010)
				DRAM_A	<=	DRAM_addr[23:12];
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
		else if(SRAM_type == 1'b1 && DMA_type == 1'b0)
		begin
			if(cur_state == 4'b0001 || pre_state == 4'b0000)
				cur_addr[6:0]	<=	7'b0;
			else if(DRAM_data_weight_count	==	4'd9)
				cur_addr[6:0]	<=	cur_addr[6:0]	+	1'b1;
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
			output_SRAM_CEN_DMA	<=	'b1;
		else if(DMA_type == 1'b1)
		begin
			if(cur_state == 'b0001)
				output_SRAM_CEN_DMA	<=	'b0;
		end
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
			else if(cur_state == 4'b0010 && DRAM_addr[11:2] != 10'd1022)
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
					next_state = 4'b0100;
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