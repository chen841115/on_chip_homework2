`timescale 1 ns/1 ps
`include "controller.sv"
`include "output_SRAM.sv"
`include "weight_SRAM.sv"
`include "input_SRAM.sv"
`include "DRAM.v"
`include "ping_pong.sv"
`include "DMA.sv"
`include "buffer2sram_input.sv"
`include "transfer_controller.sv"
`include "mux_buffer.sv"
`include "mux_sram.sv"
`include "mux_weight_sram.sv"
`include "mux_output_sram_read.sv"

module top(
    clk,
    rst,
	run,
	kernel_size,
	kernel_num,
	stride,
	channel,
	map_size,
	ouput_map_size,
	pooling,
	//DRAM
	Q,
	CSn,
	WEn,
	RASn,
	CASn,
	A,
	D
);

    // Input Ports: clock and control signals
    input   clk;
    input	rst;
	input	run;
	input	[3:0]	kernel_size;
	input	[9:0]	kernel_num;
	input	[2:0]	stride;
	input	[10:0]	channel;
	input	[9:0]	map_size;
	input	[9:0]	ouput_map_size;
	input	[1:0]	pooling;
	//DRAM
	input	[31:0]	Q;				//Data Output
	output	logic	CSn;			//Chip Select
	output	logic	[3:0]	WEn;	//Write Enable
	output	logic	RASn;			//Row Address Select
	output	logic	CASn;			//Column Address Select
	output	logic	[12:0]	A;		//Address
	output	logic	[31:0]	D;		//Data Input

    //output_SRAM
	logic	[31:0]	output_SRAM_DI		[0:31];
	logic	[31:0]	output_SRAM_DO		[0:31];
	logic	[11:0]	output_SRAM_AA		[0:31];	//output_SRAM_DI
	logic	[11:0]	output_SRAM_AB		[0:31];	//output_SRAM_DO
	logic	output_SRAM_CEN;
	logic	output_SRAM_OEN;
	logic	output_SRAM_WEN				[0:31];
	//output_SRAM read controller/DMA
	logic	[11:0]	output_SRAM_AB_DMA			[0:31];
	logic	[11:0]	output_SRAM_AB_controller	[0:31];
	logic	[31:0]	output_SRAM_DO_DMA			[0:31];
	logic	[31:0]	output_SRAM_DO_controller	[0:31];
	logic	output_SRAM_OEN_DMA;
	logic	output_SRAM_OEN_controller;
	logic	output_sram_read_select;
	logic	output_SRAM_CEN_DMA;
	logic	output_SRAM_CEN_controller;
	//input_SRAM
	logic	[127:0]	input_SRAM_DI		[0:63];
	logic	[127:0]	input_SRAM_DO		[0:63];
	logic	[6:0]	input_SRAM_A		[0:63];
	logic	input_SRAM_CEN	[0:63];
	logic	input_SRAM_OEN	[0:63];
	logic	input_SRAM_WEN	[0:63]; 
	//input SRAM read/write
	logic	[6:0]	input_SRAM_A_read	[0:63];
	logic	[6:0]	input_SRAM_A_write	[0:63];
	logic	input_SRAM_CEN_read		[0:63];
	logic	input_SRAM_CEN_write	[0:63];
	logic	input_SRAM_rw_select	[0:63];		//0-> read 1->write
	//weight_SRAM
	logic	[287:0]	weight_SRAM_DI		[0:287];
	logic	[287:0]	weight_SRAM_DO		[0:287];
	logic	[6:0]	weight_SRAM_A		[0:287];
	logic	weight_SRAM_CEN		[0:287];
	logic	weight_SRAM_OEN		[0:287];
	logic	weight_SRAM_WEN		[0:287];
	//weight SRAM read/write
	logic	[6:0]	weight_SRAM_A_read		[0:287];
	logic	[6:0]	weight_SRAM_A_write		[0:287];
	logic	weight_SRAM_CEN_read	[0:287];
	logic	weight_SRAM_CEN_write	[0:287];
	logic	weight_SRAM_rw_select;		//0-> read 1->write
    //controller
	logic	controller_run;
	logic	[10:0]	act_cur_channel;
	logic	[10:0]	cur_channel;
    //logic   DMA_done;
	logic	[5:0]	row_end;
	logic	[5:0]	col_end;
    logic	tile_done;
	//input buffer
	logic	[127:0]	input_buffer_DI		[0:1];
	logic	[127:0]	input_buffer_DO		[0:1];
	logic	[6:0]	input_buffer_A		[0:1];
	logic	input_buffer_CEN	[0:1];
	logic	input_buffer_OEN	[0:1];
	logic	input_buffer_WEN	[0:1]; 
	//input buffer read/write
	logic	[6:0]	input_buffer_A_read		[0:1];
	logic	[6:0]	input_buffer_A_write	[0:1];
	logic	input_buffer_CEN_read	[0:1];
	logic	input_buffer_CEN_write	[0:1];
	logic	input_buffer_rw_select	[0:1];		//0-> read 1->write
	//weight buffer
	logic	[287:0]	weight_buffer_DI		[0:1];
	logic	[287:0]	weight_buffer_DO		[0:1];
	logic	[6:0]	weight_buffer_A			[0:1];
	logic	weight_buffer_CEN		[0:1];
	logic	weight_buffer_OEN		[0:1];
	logic	weight_buffer_WEN		[0:1];
	//weight buffer read/write
	logic	[6:0]	weight_buffer_A_read		[0:1];
	logic	[6:0]	weight_buffer_A_write	[0:1];
	logic	weight_buffer_CEN_read	[0:1];
	logic	weight_buffer_CEN_write	[0:1];
	logic	weight_rw_select;		//0-> read 1->write
	//DRAM
	// logic	[31:0]	Q;		//Data Output
	// logic	CSn;			//Chip Select
	// logic	[3:0]	WEn;	//Write Enable
	// logic	RASn;			//Row Address Select
	// logic	CASn;			//Column Address Select
	// logic	[10:0]	A;		//Address
	// logic	[31:0]	D;		//Data Input
	//DMA
	logic	[31:0]  DRAM_ADDR_start,DRAM_ADDR_end;
	logic	[6:0]	BUF_ADDR_start_write;
	logic	[6:0]	BUF_ADDR_end_write;
	logic	[15:0]	WEIGHT_SRAM_ADDR_start;
	logic	[15:0]	WEIGHT_SRAM_ADDR_end;
	logic	[17:0]	Output_SRAM_ADDR_start,Output_SRAM_ADDR_end;
	logic	DMA_start,DMA_done;
	logic	SRAM_type,DMA_buf_select;
	logic	DMA_type;		//0->read 1->write
	//signal for buffer to sram
	logic	input_SRAM_ready	[0:63];
	logic	[2:0]	controller_cur_state;
	logic	[5:0]	controller_cur_row;
	logic	transfer_controller_done;
	//buffer2sram_input
	logic	[7:0]	BUF_ADDR_start_read;
	logic	[7:0]	BUF_ADDR_end_read;
	logic	[12:0]	SRAM_ADDR_start_write;
	logic	buffer2sram_input_start;
	logic	buffer2sram_input_done;
	//pooling_enable
	logic	pooling_enable;
	//filter_parting_size1_times
	logic	[3:0]	filter_parting_map_times;
	logic	[3:0]	filter_parting_map_count;
	

    //assign  DMA_start	=   1'b1;
    //assign  row_end     =   6'd51;
    //assign  col_end     =   6'd51;

	// DRAM DRAM_1 (
    //     .CK(clk),  
    //     .Q(Q),
    //     .RST(rst),
    //     .CSn(CSn),
    //     .WEn(WEn),
    //     .RASn(RASn),
    //     .CASn(CASn),
    //     .A(A),
    //     .D(D)
    // );

	//mux_sram
	mux_sram mux_sram_1(
		.input_rw_select(input_SRAM_rw_select),
	    .input_SRAM_A(input_SRAM_A),
	    .input_SRAM_A_read(input_SRAM_A_read),
	    .input_SRAM_A_write(input_SRAM_A_write),
		.input_SRAM_CEN(input_SRAM_CEN),
	    .input_SRAM_CEN_read(input_SRAM_CEN_read),
	    .input_SRAM_CEN_write(input_SRAM_CEN_write)
	);

	mux_weight_sram mux_weight_sram_1(
	    .weight_SRAM_rw_select(weight_SRAM_rw_select),
	    .weight_SRAM_A(weight_SRAM_A),
	    .weight_SRAM_A_read(weight_SRAM_A_read),
	    .weight_SRAM_A_write(weight_SRAM_A_write),
		.weight_SRAM_CEN(weight_SRAM_CEN),
	    .weight_SRAM_CEN_read(weight_SRAM_CEN_read),
	    .weight_SRAM_CEN_write(weight_SRAM_CEN_write)
	);

	mux_buffer mux_buffer_1(
	    .rw_select(input_buffer_rw_select),
	    .input_buffer_A(input_buffer_A),
	    .input_buffer_A_read(input_buffer_A_read),
	    .input_buffer_A_write(input_buffer_A_write),
		.input_buffer_CEN(input_buffer_CEN),
	    .input_buffer_CEN_read(input_buffer_CEN_read),
	    .input_buffer_CEN_write(input_buffer_CEN_write)
	);

	mux_output_sram_read mux_output_sram_read_1(
	    .output_sram_read_select(output_sram_read_select),
	    .output_SRAM_AB(output_SRAM_AB),
	    .output_SRAM_AB_DMA(output_SRAM_AB_DMA),
	    .output_SRAM_AB_controller(output_SRAM_AB_controller),
		.output_SRAM_DO(output_SRAM_DO),
	    .output_SRAM_DO_DMA(output_SRAM_DO_DMA),
	    .output_SRAM_DO_controller(output_SRAM_DO_controller),
		.output_SRAM_OEN(output_SRAM_OEN),
		.output_SRAM_OEN_DMA(output_SRAM_OEN_DMA),
		.output_SRAM_OEN_controller(output_SRAM_OEN_controller),
		.output_SRAM_CEN(output_SRAM_CEN),
		.output_SRAM_CEN_DMA(output_SRAM_CEN_DMA),
		.output_SRAM_CEN_controller(output_SRAM_CEN_controller)
	);

    //controller
    controller controller_1(
        .clk(clk),
        .rst(rst),
        .controller_run(controller_run),
		.input_SRAM_ready(input_SRAM_ready),
        .kernel_size(kernel_size),
        .kernel_num(kernel_num),
        .row_end(row_end),
        .col_end(col_end),
        .stride(stride),
        .channel(channel),
        .tile_done(tile_done),
		.act_cur_channel(act_cur_channel),
		.cur_channel(cur_channel),
		.pooling_enable(pooling_enable),
        //SRAM
        //output_SRAM
        .output_SRAM_DI(output_SRAM_DI),
        .output_SRAM_DO(output_SRAM_DO_controller),
        .output_SRAM_AA(output_SRAM_AA),
        .output_SRAM_AB(output_SRAM_AB_controller),
        .output_SRAM_CEN(output_SRAM_CEN_controller),
        .output_SRAM_OEN(output_SRAM_OEN_controller),
        .output_SRAM_WEN(output_SRAM_WEN),
        //input_SRAM
        .input_SRAM_DO(input_SRAM_DO),
        .input_SRAM_A(input_SRAM_A_read),
        .input_SRAM_CEN(input_SRAM_CEN_read),
        .input_SRAM_OEN(input_SRAM_OEN),
        //weight_SRAM
        .weight_SRAM_DO(weight_SRAM_DO),
        .weight_SRAM_A(weight_SRAM_A_read),
        .weight_SRAM_CEN(weight_SRAM_CEN_read),
        .weight_SRAM_OEN(weight_SRAM_OEN),
        .weight_SRAM_WEN(),
		//bank_done
		.cur_row(controller_cur_row),
		.cur_state(controller_cur_state),
		//filter_parting_size1_times
		.filter_parting_map_times(filter_parting_map_times)
    );
	// assign	DRAM_ADDR_start	=	32'b10010000;
	// assign	DRAM_ADDR_end	=	32'b11001100;
	// assign	BUF_ADDR_start	=	32'b0;
	// assign	DMA_start	=	(DMA_done)?1'b0:1'b1;
	// assign	SRAM_type	=	1'b0;
	// assign	buf_select	=	1'b0;

	// assign	DRAM_ADDR_start	=	32'h200000;
	// assign	DRAM_ADDR_end	=	32'h200044;
	// assign	BUF_ADDR_start	=	7'b0;
	// assign	DMA_start	=	(DMA_done)?1'b0:1'b1;
	// assign	SRAM_type	=	1'b1;
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
		.buf_select(DMA_buf_select),
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
		.input_buffer_CEN(input_buffer_CEN_write),
		.input_buffer_WEN(input_buffer_WEN),
		.input_buffer_A(input_buffer_A_write),
		.input_buffer_DI(input_buffer_DI),
		//weight_SRAM access
	    .weight_SRAM_CEN_write(weight_SRAM_CEN_write),
	    .weight_SRAM_WEN(weight_SRAM_WEN),
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

	buffer2sram_input buffer2sram_input_1(
		.clk(clk),
		.rst(rst),
		.BUF_ADDR_start(BUF_ADDR_start_read),
		.BUF_ADDR_end(BUF_ADDR_end_read),
		.SRAM_ADDR_start(SRAM_ADDR_start_write),
		.buffer2sram_start(buffer2sram_input_start),
		.buffer2sram_done(buffer2sram_input_done),
		//input_buffer
		.input_buffer_DO(input_buffer_DO),
		.input_buffer_CEN_read(input_buffer_CEN_read),
		.input_buffer_A_read(input_buffer_A_read),
		.input_buffer_OEN(input_buffer_OEN),
		//input_sram
		.input_SRAM_DI(input_SRAM_DI),
		.input_SRAM_A_write(input_SRAM_A_write),
		.input_SRAM_CEN_write(input_SRAM_CEN_write),
		.input_SRAM_WEN(input_SRAM_WEN)  
	);

	transfer_controller transfer_controller_1(
	    .clk(clk),
	    .rst(rst),
	    .run(run),
		//controller
		.row_end(row_end),
		.col_end(col_end),
		.controller_run(controller_run),
		.act_cur_channel(act_cur_channel),
		.cur_channel(cur_channel),
		.pooling_enable(pooling_enable),
	    //DMA
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
		.DMA_type(DMA_type),
	    .DMA_buf_select(DMA_buf_select),
		.tile_done(tile_done),
		//buffer2sram_input
		.input_BUF_ADDR_start(BUF_ADDR_start_read),
		.input_BUF_ADDR_end(BUF_ADDR_end_read),
		.input_SRAM_ADDR_start(SRAM_ADDR_start_write),
		.input_buffer2sram_start(buffer2sram_input_start),
		.input_buffer2sram_done(buffer2sram_input_done),
	    //conv info
		.kernel_size(kernel_size),
	    .kernel_num(kernel_num),
		.stride(stride),
		.channel(channel),
		.map_size(map_size),
		.ouput_map_size(ouput_map_size),
		.pooling(pooling),
		//signal for buffer to sram
		.input_SRAM_ready(input_SRAM_ready),
		.controller_cur_row(controller_cur_row),
		.controller_cur_state(controller_cur_state),
		.transfer_controller_done(transfer_controller_done),
		//input_SRAM_rw_select input_buffer_rw_select
		.input_SRAM_rw_select(input_SRAM_rw_select),
		.input_buffer_rw_select(input_buffer_rw_select),
		.output_sram_read_select(output_sram_read_select),
		.weight_SRAM_rw_select(weight_SRAM_rw_select),
		//filter_parting_size1_times
		.filter_parting_map_times(filter_parting_map_times),
		.filter_parting_map_count(filter_parting_map_count)
	);

    //SRAM
    genvar i;
	//ping-pong SRAM
	//input_SRAM * 64
	generate
		for(i=0;i<64;i=i+1)
		begin: u_input_SRAM
			input_SRAM input_SRAM_i(
				.CLK(clk),
				.CEN(input_SRAM_CEN[i]),
				.WEN(input_SRAM_WEN[i]),
				.OEN(input_SRAM_OEN[i]),
				.A(input_SRAM_A[i]),
				.D(input_SRAM_DI[i]),
				.Q(input_SRAM_DO[i])
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

	//weight_SRAM * 288
	generate
		for(i=0;i<288;i=i+1)
		begin: u_weight_SRAM
			weight_SRAM weight_SRAM_i(
				.CLK(clk),
				.CEN(weight_SRAM_CEN[i]),
				.WEN(weight_SRAM_WEN[i]),
				.OEN(weight_SRAM_OEN[i]),
				.A(weight_SRAM_A[i]),
				.D(weight_SRAM_DI[i]),
				.Q(weight_SRAM_DO[i])
			);
		end
	endgenerate

	//buffer
	//input buffer
	generate
		for(i=0;i<2;i=i+1)
		begin: u_input_buf
			input_SRAM input_buf_i(
				.CLK(clk),
				.CEN(input_buffer_CEN[i]),
				.WEN(input_buffer_WEN[i]),
				.OEN(input_buffer_OEN[i]),
				.A(input_buffer_A[i]),
				.D(input_buffer_DI[i]),
				.Q(input_buffer_DO[i])
			);
		end
	endgenerate

	//weight buffer
	generate
		for(i=0;i<2;i=i+1)
		begin: u_weight_buf
			weight_SRAM weight_buf_i(
				.CLK(clk),
				.CEN(weight_buffer_CEN[i]),
				.WEN(weight_buffer_WEN[i]),
				.OEN(weight_buffer_OEN[i]),
				.A(weight_buffer_A[i]),
				.D(weight_buffer_DI[i]),
				.Q(weight_buffer_DO[i])
			);
		end
	endgenerate


endmodule