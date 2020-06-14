module mux_sram(
    input_rw_select,
    input_SRAM_A,
    input_SRAM_A_read,
    input_SRAM_A_write,
	input_SRAM_CEN,
    input_SRAM_CEN_read,
    input_SRAM_CEN_write
);
    input   input_rw_select [0:51];
    input	[6:0]	input_SRAM_A_read	    [0:51];
	input	[6:0]	input_SRAM_A_write	    [0:51];
    output  logic   [6:0]   input_SRAM_A    [0:51];
	input	input_SRAM_CEN_read	[0:51];
	input	input_SRAM_CEN_write	[0:51];
    output  logic   input_SRAM_CEN	[0:51];

    always_comb
    begin
        integer i;
        for(i=0;i<52;i++)
        begin
            input_SRAM_A[i] =   (input_rw_select[i])?input_SRAM_A_write[i]:input_SRAM_A_read[i];
			input_SRAM_CEN[i]=	(input_rw_select[i])?input_SRAM_CEN_write[i]:input_SRAM_CEN_read[i];
		end
    end

endmodule