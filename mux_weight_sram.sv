module mux_weight_sram(
    weight_SRAM_rw_select,
    weight_SRAM_A,
    weight_SRAM_A_read,
    weight_SRAM_A_write,
	weight_SRAM_CEN,
    weight_SRAM_CEN_read,
    weight_SRAM_CEN_write
);
    input   weight_SRAM_rw_select;
    input	[6:0]	weight_SRAM_A_read	    [0:287];
	input	[6:0]	weight_SRAM_A_write	    [0:287];
    output  logic   [6:0]   weight_SRAM_A	[0:287];
	input	weight_SRAM_CEN_read	[0:287];
	input	weight_SRAM_CEN_write	[0:287];
    output  logic   weight_SRAM_CEN	[0:287];

    always_comb
    begin
        integer i;
        for(i=0;i<288;i++)
        begin
            weight_SRAM_A[i] =   (weight_SRAM_rw_select)?weight_SRAM_A_write[i]:weight_SRAM_A_read[i];
			weight_SRAM_CEN[i]=	(weight_SRAM_rw_select)?weight_SRAM_CEN_write[i]:weight_SRAM_CEN_read[i];
		end
    end

endmodule