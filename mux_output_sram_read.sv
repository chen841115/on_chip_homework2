module mux_output_sram_read(
    output_sram_read_select,
    output_SRAM_AB,
    output_SRAM_AB_DMA,
    output_SRAM_AB_controller,
	output_SRAM_DO,
    output_SRAM_DO_DMA,
    output_SRAM_DO_controller,
	output_SRAM_OEN,
	output_SRAM_OEN_DMA,
	output_SRAM_OEN_controller,
	output_SRAM_CEN,
	output_SRAM_CEN_DMA,
	output_SRAM_CEN_controller
);

	input	output_sram_read_select;	//0->DMA 1->controller

    input	[11:0]	output_SRAM_AB_DMA			[0:31];
	input	[11:0]	output_SRAM_AB_controller	[0:31];
    output  logic	[11:0]	output_SRAM_AB		[0:31];	//output_SRAM_DO

	output	logic   [15:0]	output_SRAM_DO_DMA			[0:31];
	output	logic   [15:0]	output_SRAM_DO_controller	[0:31];
    input  	[15:0]	output_SRAM_DO		[0:31];

	input	output_SRAM_OEN_DMA;
	input	output_SRAM_OEN_controller;
	output	logic	output_SRAM_OEN;

	input	output_SRAM_CEN_DMA;
	input	output_SRAM_CEN_controller;
	output	logic	output_SRAM_CEN;

    always_comb
    begin
        integer i;
        for(i=0;i<32;i++)
        begin
            output_SRAM_AB[i] =	(output_sram_read_select)?output_SRAM_AB_controller[i]:output_SRAM_AB_DMA[i];
			//output_SRAM_DO[i] =	(output_sram_read_select)?output_SRAM_DO_controller[i]:output_SRAM_DO_DMA[i];
			if(output_sram_read_select)
				output_SRAM_DO_controller[i] = output_SRAM_DO[i];
			else
				output_SRAM_DO_DMA[i] = output_SRAM_DO[i];
		end

		output_SRAM_OEN	=	(output_sram_read_select)?output_SRAM_OEN_controller:output_SRAM_OEN_DMA;
		output_SRAM_CEN	=	(output_sram_read_select)?output_SRAM_CEN_controller:output_SRAM_CEN_DMA;
	end

endmodule