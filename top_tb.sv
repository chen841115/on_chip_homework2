`timescale 1ns/10ps
`define CYCLE 10
`include "top.sv"
`define MAX 10000
`define INPUT_START 'h0000
`define WEIGHT_START 'h100000
`define OUTPUT_START 'h180000
`define mem_word(addr){DRAM_1.Memory_byte1[addr],DRAM_1.Memory_byte0[addr]}

`define	outputSRAM0(i){top_1.u_output_SRAM[0].output_SRAM_i.Data[i]}
`define	outputSRAM1(i){top_1.u_output_SRAM[1].output_SRAM_i.Data[i]}
//`define mem_input(addr){controller_1.genblk1[0].input_SRAM_i.Data}

module top_tb;

	// Input Ports: clock and control signals
    logic   clk;
    logic   rst;
	logic	[3:0]	kernel_size;
	logic	[9:0]	kernel_num;
    logic   [2:0]   stride;
	logic	[10:0]	channel;
	logic	[9:0]	map_size;
	logic	[9:0]	ouput_map_size;
	logic	[1:0]	pooling;
	logic	run;

	//DMA address start end
	logic   [31:0]  DRAM_ADDR_start;
    logic   [31:0]  DRAM_ADDR_end;
    logic   [6:0]	BUF_ADDR_start_write;
	logic   [6:0]	BUF_ADDR_end_write;
	logic	[15:0]	WEIGHT_SRAM_ADDR_start;
	logic	[15:0]	WEIGHT_SRAM_ADDR_end;
	logic   [17:0]  Output_SRAM_ADDR_start;
    logic   [17:0]  Output_SRAM_ADDR_end;
	//DMA address signal
	logic   DMA_start;
	logic	DMA_type;	//0->read 1->write
	logic   SRAM_type;		//0->input 1->weight
    logic   buf_select;
	logic	DMA_done;
	logic	[3:0]	filter_parting_map_times;
	logic	[3:0]	filter_parting_map_count;
	//DMA data wire
	logic	[2015:0]	weight_SRAM_A_write_w;
	logic	[287:0]	weight_SRAM_CEN_write_w;
	logic	[287:0]	weight_SRAM_WEN_write_w;
	logic	[13:0]	input_buffer_A_write_w;
	logic	[1:0]	input_buffer_WEN_write_w;
	logic	[1:0]	input_buffer_CEN_write_w;
	logic	[511:0]	output_SRAM_DO_DMA_w;
	logic	[383:0]	output_SRAM_AB_DMA_w;	//output_SRAM_DO
	logic	output_SRAM_CEN_DMA_w;
	logic	output_SRAM_OEN_DMA_w;
	//DMA data
	logic	[6:0]	weight_SRAM_A_write		[0:287];
	logic	weight_SRAM_CEN_write	[0:287];
	logic	weight_SRAM_WEN_write	[0:287];
	logic	[6:0]	input_buffer_A_write	[0:1];
	logic	input_buffer_CEN_write	[0:1];
	logic	input_buffer_WEN_write	[0:1];
	logic	[15:0]	output_SRAM_DO_DMA			[0:31];
	logic	[11:0]	output_SRAM_AB_DMA			[0:31];	//output_SRAM_DO
	logic	output_SRAM_CEN_DMA;
	logic	output_SRAM_OEN_DMA;

	//DRAM
	logic	[31:0]	Q;		//Data Output
	logic	CSn;			//Chip Select
	logic	[3:0]	WEn;	//Write Enable
	logic	RASn;			//Row Address Select
	logic	CASn;			//Column Address Select
	logic	[12:0]	A;		//Address
	logic	[31:0]	D;		//Data Input

	//SRAM
	//input_SRAM
	logic	[31:0]	input_SRAM_DI		[0:63];
	logic	[31:0]	input_SRAM_DO		[0:63];
	logic	[6:0]	input_SRAM_A		[0:63];
	logic	input_SRAM_CEN	[0:63];
	logic	input_SRAM_OEN	[0:63];
	logic	input_SRAM_WEN	[0:63]; 
	//output_SRAM
	logic	[15:0]	output_SRAM_DI		[0:31];
	logic	[15:0]	output_SRAM_DO		[0:31];
	logic	[11:0]	output_SRAM_AA		[0:31];	//output_SRAM_DI
	logic	[11:0]	output_SRAM_AB		[0:31];	//output_SRAM_DO
	logic	output_SRAM_CEN;
	logic	output_SRAM_OEN;
	logic	output_SRAM_WEN				[0:31];
	//weight_SRAM
	logic	[7:0]	weight_SRAM_DI		[0:287];
	logic	[7:0]	weight_SRAM_DO		[0:287];
	logic	[6:0]	weight_SRAM_A		[0:287];
	logic	weight_SRAM_CEN		[0:287];
	logic	weight_SRAM_OEN		[0:287];
	logic	weight_SRAM_WEN		[0:287];
	//input buffer
	logic	[31:0]	input_buffer_DI		[0:1];
	logic	[31:0]	input_buffer_DO		[0:1];
	logic	[6:0]	input_buffer_A		[0:1];
	logic	input_buffer_CEN	[0:1];
	logic	input_buffer_OEN	[0:1];
	logic	input_buffer_WEN	[0:1];

	//wire
	//input_SRAM
	logic	[2047:0]	input_SRAM_DI_w;
	logic	[2047:0]	input_SRAM_DO_w;
	logic	[447:0]	input_SRAM_A_w;
	logic	[63:0]	input_SRAM_CEN_w;
	logic	[63:0]	input_SRAM_OEN_w;
	logic	[63:0]	input_SRAM_WEN_w; 
	//output_SRAM
	logic	[511:0]	output_SRAM_DI_w;
	logic	[511:0]	output_SRAM_DO_w;
	logic	[383:0]	output_SRAM_AA_w;	//output_SRAM_DI
	logic	[383:0]	output_SRAM_AB_w;	//output_SRAM_DO
	logic	output_SRAM_CEN_w;
	logic	output_SRAM_OEN_w;
	logic	[31:0]	output_SRAM_WEN_w;
	//weight_SRAM
	//logic	[9215:0]	weight_SRAM_DI_w;
	logic	[2303:0]	weight_SRAM_DO_w;
	logic	[2015:0]	weight_SRAM_A_w;
	logic	[287:0]	weight_SRAM_CEN_w;
	logic	[287:0]	weight_SRAM_OEN_w;
	logic	[287:0]	weight_SRAM_WEN_w;
	//input buffer
	//logic	[255:0]	input_buffer_DI_w;
	logic	[63:0]	input_buffer_DO_w;
	logic	[13:0]	input_buffer_A_w;
	logic	[1:0]	input_buffer_CEN_w;
	logic	[1:0]	input_buffer_OEN_w;
	logic	[1:0]	input_buffer_WEN_w;

	logic [15:0] GOLDEN[2800000];

	DRAM DRAM_1 (
        .CK(clk),  
        .Q(Q),
        .RST(rst),
        .CSn(CSn),
        .WEn(WEn),
        .RASn(RASn),
        .CASn(CASn),
        .A(A),
        .D(D)
    );
	

    string prog_path;
	integer gf, i, num, j,k, err, h, T;
	

    top top_1(
        .clk(clk),
        .rst(rst),
		.run(run),
        .kernel_size(kernel_size),
        .kernel_num(kernel_num),
        .stride(stride),
        .channel(channel),
		.map_size(map_size),
		.ouput_map_size(ouput_map_size),
		.pooling(pooling),
		//DMA
		.DRAM_ADDR_start(DRAM_ADDR_start),
		.DRAM_ADDR_end(DRAM_ADDR_end),
		.BUF_ADDR_start_write(BUF_ADDR_start_write),
		.BUF_ADDR_end_write(BUF_ADDR_end_write),
		.WEIGHT_SRAM_ADDR_start(WEIGHT_SRAM_ADDR_start),
		.WEIGHT_SRAM_ADDR_end(WEIGHT_SRAM_ADDR_end),
		.Output_SRAM_ADDR_start(Output_SRAM_ADDR_start),
		.Output_SRAM_ADDR_end(Output_SRAM_ADDR_end),
		.DMA_start(DMA_start),
		.DMA_done(DMA_done),
		.SRAM_type(SRAM_type),
		.buf_select(buf_select),
		.DMA_type(DMA_type),
		.filter_parting_map_times(filter_parting_map_times),
		.filter_parting_map_count(filter_parting_map_count),
		//DMA data
		.weight_SRAM_A_write_w(weight_SRAM_A_write_w),
		.weight_SRAM_CEN_write_w(weight_SRAM_CEN_write_w),
		.weight_SRAM_WEN_write_w(weight_SRAM_WEN_write_w),
		.input_buffer_A_write_w(input_buffer_A_write_w),
		.input_buffer_WEN_write_w(input_buffer_WEN_write_w),
		.input_buffer_CEN_write_w(input_buffer_CEN_write_w),
		.output_SRAM_DO_DMA_w(output_SRAM_DO_DMA_w),
		.output_SRAM_AB_DMA_w(output_SRAM_AB_DMA_w),
		.output_SRAM_CEN_DMA_w(output_SRAM_CEN_DMA_w),
		.output_SRAM_OEN_DMA_w(output_SRAM_OEN_DMA_w),
		//DRAM
		// .Q(Q),
		// .CSn(CSn),
		// .WEn(WEn),
		// .RASn(RASn),
		// .CASn(CASn),
		// .A(A),
		// .D(D),
		//SRAM
		//input_SRAM
		.input_SRAM_DI_w(input_SRAM_DI_w),
		.input_SRAM_DO_w(input_SRAM_DO_w),
		.input_SRAM_A_w(input_SRAM_A_w),
		.input_SRAM_CEN_w(input_SRAM_CEN_w),
		.input_SRAM_OEN_w(input_SRAM_OEN_w),
		.input_SRAM_WEN_w(input_SRAM_WEN_w),
		//output_SRAM
		.output_SRAM_DI_w(output_SRAM_DI_w),
		.output_SRAM_DO_w(output_SRAM_DO_w),
		.output_SRAM_AA_w(output_SRAM_AA_w),	//output_SRAM_DI
		.output_SRAM_AB_w(output_SRAM_AB_w),	//output_SRAM_DO
		.output_SRAM_CEN_w(output_SRAM_CEN_w),
		.output_SRAM_OEN_w(output_SRAM_OEN_w),
		.output_SRAM_WEN_w(output_SRAM_WEN_w),
		//weight_SRAM
		//.weight_SRAM_DI_w(weight_SRAM_DI_w),
		.weight_SRAM_DO_w(weight_SRAM_DO_w),
		.weight_SRAM_A_w(weight_SRAM_A_w),
		.weight_SRAM_CEN_w(weight_SRAM_CEN_w),
		.weight_SRAM_OEN_w(weight_SRAM_OEN_w),
		.weight_SRAM_WEN_w(weight_SRAM_WEN_w),
		//input buffer
		//.input_buffer_DI_w(input_buffer_DI_w),
		.input_buffer_DO_w(input_buffer_DO_w),
		.input_buffer_A_w(input_buffer_A_w),
		.input_buffer_CEN_w(input_buffer_CEN_w),
		.input_buffer_OEN_w(input_buffer_OEN_w),
		.input_buffer_WEN_w(input_buffer_WEN_w)
    );

	//DMA
	DMA	DMA_1(
		.clk(clk),
		.rst(rst),
		.DRAM_ADDR_start(DRAM_ADDR_start),
		.DRAM_ADDR_end(DRAM_ADDR_end),
		.BUF_ADDR_start(BUF_ADDR_start_write),
		.BUF_ADDR_end(BUF_ADDR_end_write),
		.WEIGHT_SRAM_ADDR_start(WEIGHT_SRAM_ADDR_start),
		.WEIGHT_SRAM_ADDR_end(WEIGHT_SRAM_ADDR_end),
		.Output_SRAM_ADDR_start(Output_SRAM_ADDR_start),
		.Output_SRAM_ADDR_end(Output_SRAM_ADDR_end),
		.DMA_start(DMA_start),
		.DMA_done(DMA_done),
		.SRAM_type(SRAM_type),
		.buf_select(buf_select),
		.DMA_type(DMA_type),
		//DRAM
		.DRAM_Q(Q),
		.DRAM_D(D),
		.DRAM_CSn(CSn),
		.DRAM_RASn(RASn),
		.DRAM_CASn(CASn),
		.DRAM_WEn(WEn),
		.DRAM_A(A),
		//input buffer
		.input_buffer_CEN_write(input_buffer_CEN_write),
		.input_buffer_WEN_write(input_buffer_WEN_write),
		.input_buffer_A_write(input_buffer_A_write),
		.input_buffer_DI(input_buffer_DI),
		//weight_SRAM access
	    .weight_SRAM_CEN_write(weight_SRAM_CEN_write),
	    .weight_SRAM_WEN_write(weight_SRAM_WEN_write),
	    .weight_SRAM_A_write(weight_SRAM_A_write),
	    .weight_SRAM_DI(weight_SRAM_DI),
		//output_sram access
		.output_SRAM_AB_DMA(output_SRAM_AB_DMA),
		.output_SRAM_DO_DMA(output_SRAM_DO_DMA),
		.output_SRAM_OEN_DMA(output_SRAM_OEN_DMA),
		.output_SRAM_CEN_DMA(output_SRAM_CEN_DMA),
		//conv info
		.kernel_size(kernel_size),
		//filter_parting_size1_times
		.filter_parting_map_times(filter_parting_map_times),
		.filter_parting_map_count(filter_parting_map_count)
	);

	always_comb
	begin
		integer U;
		for(U=0;U<64;U++)
		begin
			input_SRAM_DO_w[(U*32)+:32]	=	input_SRAM_DO[U];
			input_SRAM_DI[U]	=	input_SRAM_DI_w[(U*32)+:32];
			input_SRAM_A[U]		=	input_SRAM_A_w[(U*7)+:7];
			input_SRAM_CEN[U]	=	input_SRAM_CEN_w[U];
			input_SRAM_OEN[U]	=	input_SRAM_OEN_w[U];
			input_SRAM_WEN[U]	=	input_SRAM_WEN_w[U];
		end
		for(U=0;U<32;U++)
		begin
			output_SRAM_DO_w[(U*16)+:16]	=	output_SRAM_DO[U];
			output_SRAM_DI[U]	=	output_SRAM_DI_w[(U*16)+:16];
			output_SRAM_AA[U]	=	output_SRAM_AA_w[(U*12)+:12];
			output_SRAM_AB[U]	=	output_SRAM_AB_w[(U*12)+:12];
			output_SRAM_WEN[U]	=	output_SRAM_WEN_w[U];
			//DMA
			output_SRAM_DO_DMA[U]	=	output_SRAM_DO_DMA_w[(U*16)+:16];
			output_SRAM_AB_DMA_w[(U*12)+:12]	=	output_SRAM_AB_DMA[U];
		end
		output_SRAM_CEN	=	output_SRAM_CEN_w;
		output_SRAM_OEN	=	output_SRAM_OEN_w;
		//DMA
		output_SRAM_CEN_DMA_w	=	output_SRAM_CEN_DMA;
		output_SRAM_OEN_DMA_w	=	output_SRAM_OEN_DMA;
		for(U=0;U<288;U++)
		begin
			weight_SRAM_DO_w[(U*8)+:8]	=	weight_SRAM_DO[U];
			//weight_SRAM_DI[U]	=	weight_SRAM_DI_w[(U*32)+:32];
			weight_SRAM_A[U]	=	weight_SRAM_A_w[(U*7)+:7];
			weight_SRAM_CEN[U]	=	weight_SRAM_CEN_w[U];
			weight_SRAM_OEN[U]	=	weight_SRAM_OEN_w[U];
			weight_SRAM_WEN[U]	=	weight_SRAM_WEN_w[U];
			//DMA data
			weight_SRAM_A_write_w[(U*7)+:7]	=	weight_SRAM_A_write[U];
			weight_SRAM_CEN_write_w[U]	=	weight_SRAM_CEN_write[U];
			weight_SRAM_WEN_write_w[U]	=	weight_SRAM_WEN_write[U];
		end
		for(U=0;U<2;U++)
		begin
			input_buffer_DO_w[(U*32)+:32]	=	input_buffer_DO[U];
			//input_buffer_DI[U]	=	input_buffer_DI_w[(U*128)+:128];
			input_buffer_A[U]		=	input_buffer_A_w[(U*7)+:7];
			input_buffer_CEN[U]	=	input_buffer_CEN_w[U];
			input_buffer_OEN[U]	=	input_buffer_OEN_w[U];
			input_buffer_WEN[U]	=	input_buffer_WEN_w[U];
			//DMA data
			input_buffer_A_write_w[(U*7)+:7]	=	input_buffer_A_write[U];
			input_buffer_WEN_write_w[U]	=	input_buffer_WEN_write[U];
			input_buffer_CEN_write_w[U]	=	input_buffer_CEN_write[U];
		end
	end


	//SRAM
    genvar gen_i;
	//ping-pong SRAM
	//input_SRAM * 64
	generate
		for(gen_i=0;gen_i<64;gen_i=gen_i+1)
		begin: u_input_SRAM
			input_SRAM input_SRAM_i(
				.CLK(clk),
				.CEN(input_SRAM_CEN[gen_i]),
				.WEN(input_SRAM_WEN[gen_i]),
				.OEN(input_SRAM_OEN[gen_i]),
				.A(input_SRAM_A[gen_i]),
				.D(input_SRAM_DI[gen_i]),
				.Q(input_SRAM_DO[gen_i])
			);
		end
	endgenerate

    //output_SRAM * 32
	generate
		for(gen_i=0;gen_i<32;gen_i=gen_i+1)
		begin: u_output_SRAM
			output_SRAM output_SRAM_i(
				// A
				.CLKA(clk),
				.CENA(output_SRAM_CEN),
				.WENA(output_SRAM_WEN[gen_i]),
				.OENA(1'b1),
				.AA(output_SRAM_AA[gen_i]),
				.DA(output_SRAM_DI[gen_i]),
				.QA(),
				// B
				.CLKB(clk),
				.CENB(output_SRAM_CEN),
				.WENB(1'b1),
				.OENB(output_SRAM_OEN),
				.AB(output_SRAM_AB[gen_i]),
				.DB(),
				.QB(output_SRAM_DO[gen_i])
			);
		end
	endgenerate

	//weight_SRAM * 288
	generate
		for(gen_i=0;gen_i<288;gen_i=gen_i+1)
		begin: u_weight_SRAM
			weight_SRAM weight_SRAM_i(
				.CLK(clk),
				.CEN(weight_SRAM_CEN[gen_i]),
				.WEN(weight_SRAM_WEN[gen_i]),
				.OEN(weight_SRAM_OEN[gen_i]),
				.A(weight_SRAM_A[gen_i]),
				.D(weight_SRAM_DI[gen_i]),
				.Q(weight_SRAM_DO[gen_i])
			);
		end
	endgenerate

	//buffer
	//input buffer
	generate
		for(gen_i=0;gen_i<2;gen_i=gen_i+1)
		begin: u_input_buf
			input_SRAM input_buf_i(
				.CLK(clk),
				.CEN(input_buffer_CEN[gen_i]),
				.WEN(input_buffer_WEN[gen_i]),
				.OEN(input_buffer_OEN[gen_i]),
				.A(input_buffer_A[gen_i]),
				.D(input_buffer_DI[gen_i]),
				.Q(input_buffer_DO[gen_i])
			);
		end
	endgenerate


    always #(`CYCLE/2) clk = ~clk;  
    
    integer	test_num = 17; 
    initial 
    begin
        clk = 0;
        rst = 1;

		if(test_num == 11)
		begin
			kernel_size = 3;
	        stride = 1;
	        kernel_num = 16;
	        channel = 3;
			map_size = 416;
			ouput_map_size = 414;
		end
		else if(test_num == 15)
		begin
			kernel_size = 3;
		    stride = 1;
		    kernel_num = 32;
		    channel = 256;
			map_size = 52;
			ouput_map_size = 50;
		end
		else if(test_num == 17)
		begin
			kernel_size = 3;
		    stride = 1;
		    kernel_num = 32;
		    channel = 3;
			map_size = 52;
			ouput_map_size = 50;
		end
		else if(test_num == 18)
		begin
			kernel_size = 3;
		    stride = 1;
		    kernel_num = 64;
		    channel = 512;
			map_size = 15;
			ouput_map_size = 13;
		end
		else if(test_num == 19)
		begin
			kernel_size = 3;
		    stride = 1;
		    kernel_num = 64;
		    channel = 3;
			map_size = 15;
			ouput_map_size = 13;
		end
		else if(test_num == 111)
		begin
			kernel_size = 3;
		    stride = 2;
		    kernel_num = 1;
		    channel = 3;
			map_size = 51;
			ouput_map_size = 25;
		end
		else if(test_num == 112)
		begin
			kernel_size = 3;
		    stride = 2;
		    kernel_num = 64;
		    channel = 256;
			map_size = 51;
			ouput_map_size = 25;
		end
		else if(test_num == 114)
		begin
			kernel_size = 3;
		    stride = 2;
		    kernel_num = 32;
		    channel = 3;
			map_size = 52;
			ouput_map_size = 25;
		end
		else if(test_num == 21)
		begin
			kernel_size = 5;
	        stride = 1;
	        kernel_num = 16;
	        channel = 3;
			map_size = 416;
			ouput_map_size = 412;
		end
		else if(test_num == 22)
		begin
			kernel_size = 5;
	        stride = 1;
	        kernel_num = 64;
	        channel = 32;
			map_size = 104;
			ouput_map_size = 100;
		end
		else if(test_num == 23)
		begin
			kernel_size = 5;
	        stride = 1;
	        kernel_num = 128;
	        channel = 64;
			map_size = 52;
			ouput_map_size = 48;
		end
		else if(test_num == 27)
		begin
			kernel_size = 5;
	        stride = 1;
	        kernel_num = 32;
	        channel = 3;
			map_size = 52;
			ouput_map_size = 48;
		end
		else if(test_num == 28)
		begin
			kernel_size = 5;
	        stride = 2;
	        kernel_num = 64;
	        channel = 45;
			map_size = 53;
			ouput_map_size = 25;
		end
		else if(test_num == 210)
		begin
			kernel_size = 5;
	        stride = 2;
	        kernel_num = 64;
	        channel = 3;
			map_size = 74;
			ouput_map_size = 35;
		end
		else if(test_num == 31)
		begin
			kernel_size = 1;
	        stride = 1;
	        kernel_num = 32;
	        channel = 4;
			map_size = 26;
			ouput_map_size = 26;
		end
		else if(test_num == 32)
		begin
			kernel_size = 1;
	        stride = 1;
	        kernel_num = 256;
	        channel = 128;
			map_size = 26;
			ouput_map_size = 26;
		end
		else if(test_num == 33)
		begin
			kernel_size = 1;
	        stride = 1;
	        kernel_num = 256;
	        channel = 128;
			map_size = 13;
			ouput_map_size = 13;
		end
		else if(test_num == 34)
		begin
			kernel_size = 1;
	        stride = 1;
	        kernel_num = 64;
	        channel = 512;
			map_size = 26;
			ouput_map_size = 26;
		end
		else if(test_num == 35)
		begin
			kernel_size = 1;
	        stride = 1;
	        kernel_num = 256;
	        channel = 1024;
			map_size = 13;
			ouput_map_size = 13;
		end
		else if(test_num == 41)
		begin
			kernel_size = 7;
	        stride = 1;
	        kernel_num = 32;
	        channel = 25;
			map_size = 56;
			ouput_map_size = 50;
		end
		else if(test_num == 43)
		begin
			kernel_size = 7;
	        stride = 1;
	        kernel_num = 32;
	        channel = 3;
			map_size = 56;
			ouput_map_size = 50;
		end
		else if(test_num == 46)
		begin
			kernel_size = 7;
		    stride = 2;
		    kernel_num = 1;
		    channel = 3;
			map_size = 55;
			ouput_map_size = 25;
		end
		else if(test_num == 47)
		begin
			kernel_size = 7;
		    stride = 2;
		    kernel_num = 64;
		    channel = 25;
			map_size = 55;
			ouput_map_size = 25;
		end
		else if(test_num == 48)
		begin
			kernel_size = 7;
		    stride = 2;
		    kernel_num = 64;
		    channel = 3;
			map_size = 262;
			ouput_map_size = 128;
		end

		pooling = 0;
		run = 0;
        #(`CYCLE*4) rst = 0;
		run = 1;
        #(`CYCLE*10) run = 0;
        //#(`CYCLE*5000) $finish;
    end

    initial begin
        $fsdbDumpfile("top_tb.fsdb");
        $fsdbDumpvars("+struct","+mda", top_tb);
		$fsdbDumpvars(0,top_tb.top_1,"+struct","+mda");
		$fsdbDumpvars("+struct","+mda", top_tb);
    end

	initial begin
//	        $display("\n");
//	        $display("\n");
//	        $display("        ****************************               ");
//	        $display("        **                        **       |\__||  ");
//	        $display("        **  Congratulations !!    **      / O.O  | ");
//	        $display("        **                        **    /_____   | ");
//	        $display("        **  Simulation PASS!!     **   /^ ^ ^ \\  |");
//	        $display("        **                        **  |^ ^ ^ ^ |w| ");
//	        $display("        ****************************   \\m___m__|_|");
//	        $display("\n");
		#(`CYCLE*4)
		case(test_num)
			11	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model1/layer1";
				h = 414 * 414 * 16;
				T = 8000000;
			end
			15	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model1/layer5";
				h = 50 * 50 * 32;
				T = 6000000;
			end
			17	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model1/layer7";
				h = 50 * 50 * 32;
				T = 600000;
			end
			18	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model1/layer8";
				h = 13 * 13 * 64;
				T = 2000000;
			end
			19	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model1/layer9";
				h = 13 * 13 * 64;
				T = 1000000;
			end
			111	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model1/layer11";
				h = 25 * 25 * 1;
				T = 100000;
			end
			112	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model1/layer12";
				h = 25 * 25 * 64;
				T = 3000000;
			end
			114	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model1/layer14";
				h = 25 * 25 * 32;
				T = 60000;
			end
			21	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model2/layer1";
				h = 412 * 412 * 16;
				T = 10000000;
			end
			22	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model2/layer2";
				h = 100 * 100 * 64;
				T = 10000000;
			end
			23	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model2/layer3";
				h = 48 * 48 * 128;
				T = 10000000;
			end
			27	:	
			begin
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model2/layer7";
				h = 48 * 48 * 32;
				T = 800000;
			end
			28	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model2/layer8";
				h = 25 * 25 * 64;
				T = 6000000;
			end
			210	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model2/layer10";
				h = 35 * 35 * 64;
				T = 1000000;
			end
			31	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model3_size_0/layer1";
				h = 26 * 26 * 32;
				T = 200000;
			end
			32	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model3_size_0/layer2";
				h = 26 * 26 * 256;
				T = 2000000;
			end
			33	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model3_size_0/layer3";
				h = 13 * 13 * 256;
				T = 900000;
			end
			34	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model3_size_0/layer4";
				h = 26 * 26 * 64;
				T = 2000000;
			end
			35	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model3_size_0/layer5";
				h = 13 * 13 * 256;
				T = 8000000;
			end
			41	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model4_size_7/layer1";
				h = 50 * 50 * 32;
				T = 6000000;
			end
			43	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model4_size_7/layer3";
				h = 50 * 50 * 32;
				T = 1000000;
			end
			46	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model4_size_7/layer6";
				h = 25 * 25 * 1;
				T = 1000000;
			end
			47	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model4_size_7/layer7";
				h = 25 * 25 * 64;
				T = 5000000;
			end
			48	:
			begin	
				prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model4_size_7/layer8";
				h = 128 * 128 * 64;
				T = 10000000;
			end
			default: prog_path ="/home/hsiao/bank64AI/backup_20201119/on_chip_homework2/DRAM_INPUT/model1/layer1";
		endcase
		$readmemh({prog_path, "/input0.hex"}, DRAM_1.Memory_byte0);
    	$readmemh({prog_path, "/input1.hex"}, DRAM_1.Memory_byte1);
    	$readmemh({prog_path, "/input2.hex"}, DRAM_1.Memory_byte2);
    	$readmemh({prog_path, "/input3.hex"}, DRAM_1.Memory_byte3);
        // $readmemh({"./input0.hex"}, DRAM_1.Memory_byte0);
        // $readmemh({"./input1.hex"}, DRAM_1.Memory_byte1);
        // $readmemh({"./input2.hex"}, DRAM_1.Memory_byte2);
        // $readmemh({"./input3.hex"}, DRAM_1.Memory_byte3);
        //#(`CYCLE*10000000)
		//#(`CYCLE*10000000)
		//#(`CYCLE*4100000)
		
		#(`CYCLE*T)
		//h = 50 * 50 * 32;
		num = 0;
		h	=	3000;
		
		gf = $fopen({prog_path, "/output.txt"}, "r");
		//gf = $fopen({"./output.txt"}, "r");
		//gf = $fopen({prog_path, "model1/layer7/output.txt"}, "r");
        while (num < h)
        begin
            $fscanf(gf, "%d\n", GOLDEN[num]);
            num = num + 1;
        end

        // for(i=0;i<60;i++)
        // begin
        //     $display("%6h : %h",`INPUT_START + i,`mem_word(`INPUT_START + i));
        // end
		//$display("%h",`mem_word(1048576));
		// $display("\n");
		// for(i=0;i<60;i++)
        // begin
        //     $display("%6h : %h",`OUTPUT_START + i,`mem_word(`OUTPUT_START + i));
        // end
		$display("\n");
		$display("test_num : %d\n",test_num);
		$display("check    : %d\n",h);
		err = 0;
		for (i = 0; i < h; i++)
		begin
			if (`mem_word(`OUTPUT_START + i) !== GOLDEN[i])
			begin
				$display("DRAM[%8d] = %h, expect = %h", i, `mem_word(`OUTPUT_START + i), GOLDEN[i]);
				//$display("DRAM[%8d] = %4d, expect = %4d", i, `mem_word(`OUTPUT_START + i), GOLDEN[i]);
				err = err + 1;
			end
			else
			begin
				//$display("DRAM[%8d] = %h, pass", i, `mem_word(`OUTPUT_START + i));
			end
		end
		if (err == 0)
	    begin
	        $display("\n");
	        $display("\n");
	        $display("        ****************************               ");
	        $display("        **                        **       |\__||  ");
	        $display("        **  Congratulations !!    **      / O.O  | ");
	        $display("        **                        **    /_____   | ");
	        $display("        **  Simulation PASS!!     **   /^ ^ ^ \\  |");
	        $display("        **                        **  |^ ^ ^ ^ |w| ");
	        $display("        ****************************   \\m___m__|_|");
	        $display("\n");
	    end
	    else
	    begin
	    	$display("\n");
	        $display("\n");
	        $display("        ****************************               ");
	        $display("        **                        **       |\__||  ");
	        $display("        **  OOPS!!                **      / X,X  | ");
	        $display("        **                        **    /_____   | ");
	        $display("        **  Simulation Failed!!   **   /^ ^ ^ \\  |");
	        $display("        **                        **  |^ ^ ^ ^ |w| ");
	        $display("        ****************************   \\m___m__|_|");
	        $display("         Totally has %d errors                     ", err); 
	        $display("\n");
	    end
		i = 2570940;
		$display("%6h : %h",`OUTPUT_START + i,`mem_word(`OUTPUT_START + i));
		// for(i=0;i<60;i++)
        // begin
        //     $display("outputSRAM0[%6h] : %h",i,`outputSRAM0(i));
        // end

		// for(i=0;i<60;i++)
        // begin
        //     $display("outputSRAM1[%6h] : %h",i,`outputSRAM1(i));
        // end

        $finish;
    end

    initial
    begin
		prog_path ="/home/hsiao/bank64AI/on_chip_homework2/DRAM_INPUT/";
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[0].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[1].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[2].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[3].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[4].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[5].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[6].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[7].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[8].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[9].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[10].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[11].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[12].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[13].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[14].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[15].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[16].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[17].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[18].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[19].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[20].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[21].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[22].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[23].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[24].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[25].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[26].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[27].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[28].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[29].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[30].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_output_SRAM[31].output_SRAM_i.Data);
        // $readmemh({"./output.hex"}, u_output_SRAM[0].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[1].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[2].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[3].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[4].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[5].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[6].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[7].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[8].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[9].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[10].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[11].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[12].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[13].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[14].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[15].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[16].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[17].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[18].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[19].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[20].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[21].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[22].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[23].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[24].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[25].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[26].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[27].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[28].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[29].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[30].output_SRAM_i.Data);
		// $readmemh({"./output.hex"}, u_output_SRAM[31].output_SRAM_i.Data);

		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[0].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[1].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[2].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[3].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[4].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[5].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[6].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[7].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[8].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[9].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[10].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[11].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[12].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[13].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[14].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[15].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[16].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[17].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[18].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[19].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[20].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[21].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[22].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[23].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[24].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[25].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[26].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[27].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[28].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[29].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[30].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[31].weight_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[0].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[1].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[2].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[3].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[4].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[5].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[6].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[7].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[8].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[9].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[10].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[11].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[12].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[13].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[14].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[15].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[16].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[17].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[18].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[19].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[20].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[21].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[22].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[23].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[24].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[25].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[26].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[27].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[28].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[29].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[30].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[31].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[32].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[33].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[34].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[35].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[36].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[37].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[38].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[39].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[40].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[41].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[42].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[43].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[44].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[45].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[46].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[47].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[48].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[49].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[50].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[51].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[52].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[53].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[54].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[55].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[56].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[57].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[58].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[59].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[60].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[61].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[62].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, u_input_SRAM[63].input_SRAM_i.Data);
	end

endmodule
