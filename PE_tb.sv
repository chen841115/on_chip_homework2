`timescale 1ns/10ps
`define CYCLE 10
`include "PE.sv"
`define MAX 10000

module PE_tb;

	// Input Ports: clock and control signals
    logic   clk;
    logic   rst;
    logic   read_input_enable;
	logic   read_weight_enable;
	logic   read_psum_enable;
    logic   read_bias_enable;
	logic   if_do_bias;
	logic   [1:0]   if_do_activation;
	// Input Ports
	logic   signed  [31:0]  Input   [0:8];
	logic   signed  [31:0]  Weight  [0:8];
	logic   signed  [31:0]  Pre_psum;
	logic   signed  [31:0]  Bias;
	// Output Ports
	logic   signed  [31:0]   Psum_out;
	logic   PE_done;

    PE PE1(
        .clk(clk),
        .rst(rst),
        .read_input_enable(read_input_enable),
        .read_weight_enable(read_weight_enable),
        .read_psum_enable(read_psum_enable),
        .read_bias_enable(read_bias_enable),
        .if_do_bias(if_do_bias),
        .if_do_activation(if_do_activation),
        // Input Ports
        .Input(Input),
        .Weight(Weight),
        .Pre_psum(Pre_psum),
        .Bias(Bias),
        // Output Ports
        .Psum_out(Psum_out),
        .PE_done(PE_done)
    );

    always #(`CYCLE/2) clk = ~clk;  
    
    
    initial 
    begin
        clk = 0;
        rst = 1;
        read_input_enable = 1;
        read_weight_enable = 1;
        read_psum_enable = 1;
        read_bias_enable = 1; 
        if_do_bias = 1;
        if_do_activation = 2;

        Input[0] = 32'b00001111;
        Input[1] = 32'b01001111;
        Input[2] = 32'b01001011;
        Input[3] = 32'b10001111;
        Input[4] = 32'b10000000;
        Input[5] = 32'b00101111;
        Input[6] = 32'b01001111;
        Input[7] = 32'b00000000;
        Input[8] = 32'b10000000;

        Weight[0] = 32'b10001111;
        Weight[1] = 32'b01001111;
        Weight[2] = 32'b01001011;
        Weight[3] = 32'b00001111;
        Weight[4] = 32'b10000000;
        Weight[5] = 32'b00101111;
        Weight[6] = 32'b11001111;
        Weight[7] = 32'b00000000;
        Weight[8] = 32'b00001000;

        Pre_psum = 1;
        Bias = -1;

        #(`CYCLE*4) rst = 0;
        
        // #(`CYCLE) A = 5; // Row Address
        // #(`CYCLE) RASn = 0;
        // #(`CYCLE) A = 10; WEn = 4'b0000; D = 13; // Column Address
        // #(`CYCLE) CASn = 0;
        // #(`CYCLE) A = 11;	D = 14;
        // #(`CYCLE) RASn = 1; CASn = 1; WEn = 4'b1111; D = 0;
        // #(`CYCLE) A = 5; // Row Address
        // #(`CYCLE) RASn = 0;
        // #(`CYCLE) A = 10; // Column Address
        // #(`CYCLE) CASn = 0; 
        // #(`CYCLE) A = 11; // Column Address	
        // #(`CYCLE) RASn = 1; CASn = 1; WEn = 4'b1111; D = 0;	
        
        #(`CYCLE*500) $finish;
    end

    initial begin
        $fsdbDumpfile("PE_tb.fsdb");
        $fsdbDumpvars("+struct","+mda", PE_tb);
    end

endmodule
