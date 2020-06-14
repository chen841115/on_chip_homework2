`timescale 1ns/10ps
`include "input_SRAM.sv"

module input_SRAM_block(
    clk,
    rst,
    ping_pong_select,
    input_SRAM_DI,
	input_SRAM_DO,
	input_SRAM_A,
	input_SRAM_CEN,
	input_SRAM_OEN,
	input_SRAM_WEN
);

    input   clk;
    input	rst;
    input   ping_pong_select;
    input   [127:0]	input_SRAM_DI	[0:7];
	output  [127:0]	input_SRAM_DO	[0:7];
	input   [6:0]	input_SRAM_A    [0:7];
	input   input_SRAM_CEN	[0:7];
	input   input_SRAM_OEN	[0:7];
	input   input_SRAM_WEN	[0:7];


    //input_SRAM block A
	logic	[127:0]	input_SRAM_DI_A		[0:7];
	logic	[127:0]	input_SRAM_DO_A		[0:7];
	logic	[6:0]	input_SRAM_A_A		[0:7];
	logic	input_SRAM_CEN_A	[0:7];
	logic	input_SRAM_OEN_A	[0:7];
	logic	input_SRAM_WEN_A	[0:7]; 

    //input_SRAM block B
	logic	[127:0]	input_SRAM_DI_B		[0:7];
	logic	[127:0]	input_SRAM_DO_B		[0:7];
	logic	[6:0]	input_SRAM_A_B		[0:7];
	logic	input_SRAM_CEN_B	[0:7];
	logic	input_SRAM_OEN_B	[0:7];
	logic	input_SRAM_WEN_B	[0:7]; 

    always_comb
    begin
        if(rst)
        begin
            foreach(input_SRAM_DI[i])
                input_SRAM_DI_A[i]  =	input_SRAM_DI[i];
            foreach(input_SRAM_DO[i])
                input_SRAM_DO[i]	=	input_SRAM_DO_A[i];
            foreach(input_SRAM_A[i])
                input_SRAM_A_A[i]	=	input_SRAM_A[i];
            foreach(input_SRAM_CEN[i])
                input_SRAM_CEN_A[i]	=	input_SRAM_CEN[i];
            foreach(input_SRAM_OEN[i])
                input_SRAM_OEN_A[i]	=	input_SRAM_OEN[i];
            foreach(input_SRAM_WEN[i])
                input_SRAM_WEN_A[i]	=	input_SRAM_WEN[i];
        end
		else if(ping_pong_select)
		begin
			foreach(input_SRAM_DI[i])
                input_SRAM_DI_A[i]  =	input_SRAM_DI[i];
            foreach(input_SRAM_DO[i])
                input_SRAM_DO[i]	=	input_SRAM_DO_A[i];
            foreach(input_SRAM_A[i])
                input_SRAM_A_A[i]	=	input_SRAM_A[i];
            foreach(input_SRAM_CEN[i])
                input_SRAM_CEN_A[i]	=	input_SRAM_CEN[i];
            foreach(input_SRAM_OEN[i])
                input_SRAM_OEN_A[i]	=	input_SRAM_OEN[i];
            foreach(input_SRAM_WEN[i])
                input_SRAM_WEN_A[i]	=	input_SRAM_WEN[i];
		end
		else
		begin
			foreach(input_SRAM_DI[i])
                input_SRAM_DI_B[i]  =	input_SRAM_DI[i];
            foreach(input_SRAM_DO[i])
                input_SRAM_DO[i]	=	input_SRAM_DO_B[i];
            foreach(input_SRAM_A[i])
                input_SRAM_A_B[i]	=	input_SRAM_A[i];
            foreach(input_SRAM_CEN[i])
                input_SRAM_CEN_B[i]	=	input_SRAM_CEN[i];
            foreach(input_SRAM_OEN[i])
                input_SRAM_OEN_B[i]	=	input_SRAM_OEN[i];
            foreach(input_SRAM_WEN[i])
                input_SRAM_WEN_B[i]	=	input_SRAM_WEN[i];
		end
    end


	//SRAM
    genvar i;
    //input_SRAM * 8 block A
	generate
		for(i=0;i<8;i=i+1)
		begin: u_input_SRAM_A
			input_SRAM input_SRAM_i(
				.CLK(clk),
				.CEN(input_SRAM_CEN_A[i]),
				.WEN(input_SRAM_WEN_A[i]),
				.OEN(input_SRAM_OEN_A[i]),
				.A(input_SRAM_A_A[i]),
				.D(input_SRAM_DI_A[i]),
				.Q(input_SRAM_DO_A[i])
			);
		end
	endgenerate

    //input_SRAM * 8 block B
	generate
		for(i=0;i<8;i=i+1)
		begin: u_input_SRAM_B
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



endmodule