module mux_sram(
    input_rw_select,
    input_SRAM_A,
    input_SRAM_A_read,
    input_SRAM_A_write,
	input_SRAM_CEN,
    input_SRAM_CEN_read,
    input_SRAM_CEN_write,
    input_SRAM_WEN,
    input_SRAM_WEN_write
);
    input   input_rw_select [0:63];
    input	[6:0]	input_SRAM_A_read	    [0:63];
	input	[6:0]	input_SRAM_A_write	    [0:63];
    output  logic   [6:0]   input_SRAM_A    [0:63];
	input	input_SRAM_CEN_read	[0:63];
	input	input_SRAM_CEN_write	[0:63];
    output  logic   input_SRAM_CEN	[0:63];
    input	input_SRAM_WEN_write	[0:63];
    output  logic   input_SRAM_WEN	[0:63];

    always_comb
    begin
        integer i;
        for(i=0;i<64;i++)
        begin
            input_SRAM_A[i] =   (input_rw_select[i])?input_SRAM_A_write[i]:input_SRAM_A_read[i];
			input_SRAM_CEN[i]=	(input_rw_select[i])?input_SRAM_CEN_write[i]:input_SRAM_CEN_read[i];
            input_SRAM_WEN[i]=	(input_rw_select[i])?input_SRAM_WEN_write[i]:1'b1;
		end
    end

endmodule