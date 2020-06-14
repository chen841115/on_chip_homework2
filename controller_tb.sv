`timescale 1ns/10ps
`define CYCLE 10
`include "controller.sv"
`define MAX 10000

//`define mem_input(addr){controller_1.genblk1[0].input_SRAM_i.Data}

module controller_tb;

	// Input Ports: clock and control signals
    logic   clk;
    logic   rst;
	logic   DMA_done;
	logic	[3:0]	kernel_size;
	logic	[9:0]	kernel_num;
	logic	[5:0]	row_end;
	logic	[5:0]	col_end;
    logic   [2:0]   stride;
	logic	[9:0]	channel;
	logic	tile_done;

    string prog_path;

    controller controller_1(
        .clk(clk),
        .rst(rst),
        .DMA_done(DMA_done),
        .kernel_size(kernel_size),
        .kernel_num(kernel_num),
        .row_end(row_end),
        .col_end(col_end),
        .stride(stride),
        .channel(channel),
        .tile_done(tile_done)
    );

    always #(`CYCLE/2) clk = ~clk;  
    
    
    initial 
    begin
        clk = 0;
        rst = 1;
        kernel_size = 3;
        row_end = 51;
        col_end = 51;
        stride = 1;
        kernel_num = 64;
        channel = 3;

        DMA_done = 0;

        #(`CYCLE*4) rst = 0;DMA_done = 1;
        
        #(`CYCLE*5000) $finish;
    end

    initial begin
        $fsdbDumpfile("controller_tb.fsdb");
        $fsdbDumpvars("+struct","+mda", controller_tb);
    end

    initial
    begin
        prog_path ="/home/hsiao/CU_RTL/AI_on_chip/";
        $readmemh({prog_path, "/input.hex"}, controller_1.u_input_SRAM[0].input_SRAM_i.Data);
		$readmemh({prog_path, "/input.hex"}, controller_1.u_input_SRAM[1].input_SRAM_i.Data);
		$readmemh({prog_path, "/input.hex"}, controller_1.u_input_SRAM[2].input_SRAM_i.Data);
		$readmemh({prog_path, "/input.hex"}, controller_1.u_input_SRAM[3].input_SRAM_i.Data);
		$readmemh({prog_path, "/input.hex"}, controller_1.u_input_SRAM[4].input_SRAM_i.Data);
		$readmemh({prog_path, "/input.hex"}, controller_1.u_input_SRAM[5].input_SRAM_i.Data);
		$readmemh({prog_path, "/input.hex"}, controller_1.u_input_SRAM[6].input_SRAM_i.Data);
		$readmemh({prog_path, "/input.hex"}, controller_1.u_input_SRAM[7].input_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[0].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[1].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[2].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[3].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[4].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[5].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[6].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[7].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[8].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[9].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[10].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[11].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[12].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[13].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[14].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[15].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[16].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[17].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[18].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[19].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[20].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[21].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[22].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[23].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[24].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[25].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[26].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[27].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[28].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[29].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[30].output_SRAM_i.Data);
		$readmemh({prog_path, "/output.hex"}, controller_1.u_output_SRAM[31].output_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[0].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[1].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[2].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[3].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[4].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[5].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[6].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[7].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[8].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[9].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[10].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[11].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[12].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[13].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[14].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[15].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[16].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[17].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[18].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[19].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[20].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[21].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[22].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[23].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[24].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[25].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[26].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[27].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[28].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[29].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[30].weight_SRAM_i.Data);
		$readmemh({prog_path, "/weight.hex"}, controller_1.u_weight_SRAM[31].weight_SRAM_i.Data);
    end

endmodule
