`timescale 1ns/10ps
module PE (
	// Input Ports: clock and control signals
	clk,
	rst,
    rst_reg,
	read_input_enable,
	read_weight_enable,
	read_psum_enable,
    read_bias_enable,
	if_do_bias,
	if_do_activation,
	// Input Ports
	Input,
	Weight,
	Pre_psum,
	Bias,
    Psum_addr,
	// Output Ports
	Psum_out,
    output_sram_addr,
	PE_done
	);

    // Input Ports: clock and control signals
	input	clk;
    input	rst;
    input   rst_reg;
    input	read_input_enable;
    input	read_weight_enable;
    input	read_psum_enable;
    input	read_bias_enable;
    input	if_do_bias;
    input	[1:0]	if_do_activation; //0->no 1->relu 2->leaky relu
    // Input Ports
    input	signed  [7:0]	Input [0:8];
    input	signed  [7:0]	Weight [0:8];
    input	signed  [15:0]	Pre_psum;
    input	signed  [15:0]	Bias;
    input   [11:0]  Psum_addr;
    // Output Ports
    output	logic	signed  [15:0]	Psum_out;
    output	logic   [11:0]  output_sram_addr;
    output	logic   PE_done;
    // Inner Data
	//From SRAM
    logic	signed  [15:0]	reg_weight [0:8];
    logic	signed  [15:0]	reg_input [0:8];
    logic	signed  [15:0]	reg_pre_psum;
    logic	signed  [15:0]  reg_bias;

    logic	signed  [15:0]	psum_after_mul [0:8];   //psum_after_mul >>pipeline>> psum_befor_add
	logic	signed  [15:0]	psum_befor_add [0:8];
    logic   signed  [15:0]  pre_psum_befor_add;
    logic   signed  [19:0]	psum_after_add;   //24bit -> 16bit
    logic   signed  [19:0]	psum_after_bias;
    logic   signed  [19:0]	psum_after_activation;

    logic   [11:0]  mult_addr,add_addr;
    logic   mult_done,add_done;

    logic	[15:0]	counter;

	integer i;

    // PE : Multiply
    assign  psum_after_mul[0] = reg_input[0] * reg_weight[0];
    assign  psum_after_mul[1] = reg_input[1] * reg_weight[1];
    assign  psum_after_mul[2] = reg_input[2] * reg_weight[2];
    assign  psum_after_mul[3] = reg_input[3] * reg_weight[3];
    assign  psum_after_mul[4] = reg_input[4] * reg_weight[4];
    assign  psum_after_mul[5] = reg_input[5] * reg_weight[5];
    assign  psum_after_mul[6] = reg_input[6] * reg_weight[6];
    assign  psum_after_mul[7] = reg_input[7] * reg_weight[7];
    assign  psum_after_mul[8] = reg_input[8] * reg_weight[8];

    // PE : Add
    assign  psum_after_add =    psum_befor_add[0] + psum_befor_add[1] + psum_befor_add[2] + 
                				psum_befor_add[3] + psum_befor_add[4] + psum_befor_add[5] + 
							    psum_befor_add[6] + psum_befor_add[7] + psum_befor_add[8] + pre_psum_befor_add ;

    // Add Bias
    always_comb 
    begin
        if(if_do_bias)
            psum_after_bias = psum_after_add + reg_bias;
        else
            psum_after_bias = psum_after_add;
    end

    //acttivation
    always_comb 
    begin
        if(if_do_activation[0])
        begin
            if(psum_after_bias >= 0)
                psum_after_activation = psum_after_bias;
            else
                psum_after_activation = 32'd0;
        end
        else if(if_do_activation[1])
        begin
            if(psum_after_bias >= 0)
                psum_after_activation = psum_after_bias;
            else
                psum_after_activation = ($signed(psum_after_bias + 32'd15) >>> 4) + ($signed(psum_after_bias + 32'd31) >>> 5);
        end
        else
            psum_after_activation = psum_after_bias;
    end

    // output reg psum
	always_ff @(posedge clk, posedge rst) 
	begin
        if(rst) 
        	Psum_out	<=	32'd0;
        else 
            Psum_out    <=  psum_after_activation[15:0];
    end

    // SRAM to Reg
	always_ff @(posedge clk, posedge rst) 
	begin
        if(rst || rst_reg) 
		begin
        	foreach(reg_input[i])
				reg_input[i]    <=  32'd0;
        end
        else if(read_input_enable) 
		begin
			foreach(reg_input[i])
				reg_input[i]<=	Input[i];
        end
    end

	always_ff @(posedge clk, posedge rst) 
	begin
        if(rst || rst_reg) 
		begin
        	foreach(reg_weight[i])
				reg_weight[i]   <=	32'd0;
        end
        else if(read_weight_enable) 
		begin
			foreach(reg_weight[i])
				reg_weight[i]   <=	Weight[i];
        end
    end

	always_ff @(posedge clk, posedge rst) 
	begin
        if(rst || rst_reg) 
		begin
        	reg_pre_psum	<=	32'd0;
        end
        else if(read_psum_enable) 
		begin
			reg_pre_psum	<=	Pre_psum;
        end
    end

    always_ff @(posedge clk, posedge rst) 
	begin
        if(rst || rst_reg) 
		begin
        	reg_bias	<=	32'd0;
        end
        else if(read_bias_enable) 
		begin
			reg_bias	<=	Bias;
        end
    end

	//pipeline
	always_ff @(posedge clk, posedge rst) 
	begin
        if(rst) 
		begin
        	foreach(psum_befor_add[i])
				psum_befor_add[i]<=	32'd0;
        end
        else if(read_psum_enable) 
		begin
			foreach(psum_befor_add[i])
				psum_befor_add[i]	<=	psum_after_mul[i];
        end
    end

    //output_sram_addr pipeline
    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst) 
            mult_addr   <=  11'b0;
        else if(read_psum_enable) 
		begin
			mult_addr   <=  Psum_addr;
        end
    end
    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst) 
            add_addr   <=  11'b0;
        else if(read_psum_enable) 
		begin
			add_addr   <=  mult_addr;
        end
    end
    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst) 
            output_sram_addr   <=  11'b0;
        else if(read_psum_enable) 
		begin
			output_sram_addr   <=  add_addr;
        end
    end
    //pre_psum_befor_add pipeline
    always_ff @(posedge clk, posedge rst) 
    begin
        if(rst) 
            pre_psum_befor_add   <=  11'b0;
        else if(read_psum_enable) 
		begin
			pre_psum_befor_add   <=  reg_pre_psum;
        end
    end

    //PE_done pipeline
    always_ff @(posedge clk, posedge rst) 
	begin
        if(rst) 
		begin
        	mult_done   <=  1'b0;
            add_done    <=  1'b0;
            PE_done     <=  1'b0;
        end
        else if(read_psum_enable) 
		begin
			mult_done   <=  read_psum_enable;
            add_done    <=  mult_done;
            PE_done     <=  add_done;
        end
        else
        begin
        	mult_done   <=  1'b0;
            add_done    <=  1'b0;
            PE_done     <=  1'b0;
        end
    end

endmodule