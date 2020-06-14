`timescale 1ns/10ps

module ping_pong(
    clk,
    rst,
    ping_pong_select,
	input_SRAM_DO,
	input_SRAM_A,
	input_SRAM_CEN,
	input_SRAM_OEN,
	input_SRAM_WEN,
	input_SRAM_DO_con,
	input_SRAM_A_con,
	input_SRAM_CEN_con,
	input_SRAM_OEN_con,
	input_SRAM_WEN_con
);
    input   clk;
    input	rst;
    input   ping_pong_select;

	input	[127:0]	input_SRAM_DO	[0:15];
	output	[6:0]	input_SRAM_A    [0:15];
	output	input_SRAM_CEN	[0:15];
	output	input_SRAM_OEN	[0:15];
	output	input_SRAM_WEN	[0:15];

	output	[127:0]	input_SRAM_DO_con	[0:7];
	input	[6:0]	input_SRAM_A_con	[0:7];
	input	input_SRAM_CEN_con	[0:7];
	input	input_SRAM_OEN_con	[0:7];
	input	input_SRAM_WEN_con	[0:7];


	always_comb
	begin
		integer	i;
		if(ping_pong_select	==	1'b1)
		begin
			for(i=0;i<8;i++)
			begin
				input_SRAM_DO_con[i+8]	=	input_SRAM_DO[i];
				input_SRAM_A[i]		=	input_SRAM_A_con[i+8];
				input_SRAM_CEN[i]	=	input_SRAM_CEN_con[i+8];
				input_SRAM_OEN[i]	=	input_SRAM_OEN_con[i+8];
				input_SRAM_WEN[i]	=	input_SRAM_WEN_con[i+8];
			end
		end
		else
		begin
			for(i=0;i<8;i++)
			begin
				input_SRAM_DO_con[i]	=	input_SRAM_DO[i];
				input_SRAM_A[i]		=	input_SRAM_A_con[i];
				input_SRAM_CEN[i]	=	input_SRAM_CEN_con[i];
				input_SRAM_OEN[i]	=	input_SRAM_OEN_con[i];
				input_SRAM_WEN[i]	=	input_SRAM_WEN_con[i];
			end
		end
	end

endmodule
