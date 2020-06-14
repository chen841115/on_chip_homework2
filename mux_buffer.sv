module mux_buffer(
    rw_select,
    input_buffer_A,
    input_buffer_A_read,
    input_buffer_A_write,
	input_buffer_CEN,
    input_buffer_CEN_read,
    input_buffer_CEN_write
);
    input   rw_select   [0:1];
    input	[6:0]	input_buffer_A_read		[0:1];
	input	[6:0]	input_buffer_A_write	[0:1];
    output  logic   [6:0]	input_buffer_A  [0:1];
	input	input_buffer_CEN_read	[0:1];
	input	input_buffer_CEN_write	[0:1];
    output  logic   input_buffer_CEN	[0:1];

    always_comb
    begin
        integer i;
        for(i=0;i<2;i++)
        begin
            input_buffer_A[i] =   (rw_select[i])?input_buffer_A_write[i]:input_buffer_A_read[i];
			input_buffer_CEN[i]=	(rw_select[i])?input_buffer_CEN_write[i]:input_buffer_CEN_read[i];
		end
    end

    // always_comb
    // begin
    //     if(rw_select)
    //     begin
    //         input_buffer_A[0]	=	input_buffer_A_write[0];
	// 		input_buffer_A[1]	=	input_buffer_A_write[1];
    //         end
	// 	else
	// 	begin
	// 		input_buffer_A[0]	=	input_buffer_A_read[0];
	// 		input_buffer_A[1]	=	input_buffer_A_read[1];
	// 	end
    // end

	// always_comb
    // begin
    //     if(rw_select)
    //     begin
	// 		input_buffer_CEN[0]	=	input_buffer_CEN_write[0];
	// 		input_buffer_CEN[1]	=	input_buffer_CEN_write[1];
    //     end
	// 	else
	// 	begin
    //         input_buffer_CEN[0]	=	input_buffer_CEN_read[0];
	// 		input_buffer_CEN[1]	=	input_buffer_CEN_read[1];
	// 	end
    // end

endmodule