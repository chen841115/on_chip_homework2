`timescale 1ns/10ps
`define CYCLE 10
`include "top.sv"
`define MAX 10000
`define INPUT_START 'h0000
`define WEIGHT_START 'h100000
`define OUTPUT_START 'h180000
`define mem_word(addr){top_1.DRAM_1.Memory_byte3[addr],top_1.DRAM_1.Memory_byte2[addr],top_1.DRAM_1.Memory_byte1[addr],top_1.DRAM_1.Memory_byte0[addr]}

//`define mem_input(addr){controller_1.genblk1[0].input_SRAM_i.Data}

module top_tb;

	// Input Ports: clock and control signals
    logic   clk;
    logic   rst;
	logic	[3:0]	kernel_size;
	logic	[9:0]	kernel_num;
    logic   [2:0]   stride;
	logic	[9:0]	channel;
	logic	[9:0]	map_size;
	logic	[9:0]	ouput_map_size;
	logic	run;

    string prog_path;
	integer i;

    top top_1(
        .clk(clk),
        .rst(rst),
		.run(run),
        .kernel_size(kernel_size),
        .kernel_num(kernel_num),
        .stride(stride),
        .channel(channel),
		.map_size(map_size),
		.ouput_map_size(ouput_map_size)
    );

    always #(`CYCLE/2) clk = ~clk;  
    
    
    initial 
    begin
        clk = 0;
        rst = 1;
        kernel_size = 3;
        stride = 1;
        kernel_num = 16;
        channel = 3;
		map_size = 416;
		ouput_map_size = 414;
		run = 0;


        #(`CYCLE*4) rst = 0;
		run = 1; 
		prog_path ="/home/hsiao/on_chip_homework/DRAM_INPUT/";

		$readmemh({prog_path, "/test0.hex"}, top_1.DRAM_1.Memory_byte0);
        $readmemh({prog_path, "/test1.hex"}, top_1.DRAM_1.Memory_byte1);
        $readmemh({prog_path, "/test2.hex"}, top_1.DRAM_1.Memory_byte2);
        $readmemh({prog_path, "/test3.hex"}, top_1.DRAM_1.Memory_byte3);
        #(`CYCLE*10) run = 0;
        //#(`CYCLE*5000) $finish;
    end

    initial begin
        $fsdbDumpfile("top_tb.fsdb");
        $fsdbDumpvars("+struct","+mda", top_tb);
    end

	initial begin
        #(`CYCLE*300000)
        for(i=0;i<60;i++)
        begin
            $display("%6h : %h",`INPUT_START + i,`mem_word(`INPUT_START + i));
        end
		//$display("%h",`mem_word(1048576));
		for(i=0;i<60;i++)
        begin
            $display("%6h : %h",`OUTPUT_START + i,`mem_word(`OUTPUT_START + i));
        end
        $finish;
    end

    initial
    begin
		prog_path ="/home/hsiao/on_chip_homework/DRAM_INPUT/";
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[0].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[1].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[2].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[3].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[4].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[5].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[6].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[7].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[8].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[9].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[10].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[11].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[12].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[13].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[14].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[15].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[16].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[17].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[18].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[19].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[20].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[21].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[22].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[23].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[24].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[25].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[26].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[27].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[28].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[29].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[30].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, top_1.u_output_SRAM[31].output_SRAM_i.Data);
		$readmemh({prog_path, "/weight_0.hex"}, top_1.u_weight_SRAM[0].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[1].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[2].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[3].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[4].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[5].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[6].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[7].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[8].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[9].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[10].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[11].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[12].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[13].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[14].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[15].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[16].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[17].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[18].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[19].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[20].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[21].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[22].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[23].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[24].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[25].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[26].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[27].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[28].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[29].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[30].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, top_1.u_weight_SRAM[31].weight_SRAM_i.Data);
    end

endmodule
