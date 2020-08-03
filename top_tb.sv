`timescale 1ns/10ps
`define CYCLE 10
`include "top.sv"
`define MAX 10000
`define INPUT_START 'h0000
`define WEIGHT_START 'h100000
`define OUTPUT_START 'h180000
`define mem_word(addr){DRAM_1.Memory_byte3[addr],DRAM_1.Memory_byte2[addr],DRAM_1.Memory_byte1[addr],DRAM_1.Memory_byte0[addr]}

`define	outputSRAM0(i){top_1.u_output_SRAM[0].output_SRAM_i.Data[i]}
`define	outputSRAM1(i){top_1.u_output_SRAM[1].output_SRAM_i.Data[i]}
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
	logic	[1:0]	pooling;
	logic	run;

	//DRAM
	logic	[31:0]	Q;		//Data Output
	logic	CSn;			//Chip Select
	logic	[3:0]	WEn;	//Write Enable
	logic	RASn;			//Row Address Select
	logic	CASn;			//Column Address Select
	logic	[12:0]	A;		//Address
	logic	[31:0]	D;		//Data Input

	logic [31:0] GOLDEN[2800000];

	DRAM DRAM_1 (
        .CK(clk),  
        .Q(Q),
        .RST(rst),
        .CSn(CSn),
        .WEn(WEn),
        .RASn(RASn),
        .CASn(CASn),
        .A(A),
        .D(D)
    );

    string prog_path;
	integer gf, i, num, j,k, err, h;

    top top_1(
        .clk(clk),
        .rst(rst),
		.run(run),
        .kernel_size(kernel_size),
        .kernel_num(kernel_num),
        .stride(stride),
        .channel(channel),
		.map_size(map_size),
		.ouput_map_size(ouput_map_size),
		.pooling(pooling),
		//DRAM
		.Q(Q),
		.CSn(CSn),
		.WEn(WEn),
		.RASn(RASn),
		.CASn(CASn),
		.A(A),
		.D(D)
    );

    always #(`CYCLE/2) clk = ~clk;  
    
    
    initial 
    begin
        clk = 0;
        rst = 1;
        // kernel_size = 3;
        // stride = 1;
        // kernel_num = 16;
        // channel = 3;
		// map_size = 416;
		// ouput_map_size = 414;
		kernel_size = 5;
        stride = 1;
        kernel_num = 32;
        channel = 3;
		map_size = 52;
		ouput_map_size = 48;
		pooling = 0;
		run = 0;


        #(`CYCLE*4) rst = 0;
		run = 1; 
		prog_path ="/home/hsiao/bank64AI/on_chip_homework2/DRAM_INPUT/";

		// $readmemh({prog_path, "/test0.hex"}, DRAM_1.Memory_byte0);
        // $readmemh({prog_path, "/test1.hex"}, DRAM_1.Memory_byte1);
        // $readmemh({prog_path, "/test2.hex"}, DRAM_1.Memory_byte2);
        // $readmemh({prog_path, "/test3.hex"}, DRAM_1.Memory_byte3);
		$readmemh({prog_path, "model2/layer7/input0.hex"}, DRAM_1.Memory_byte0);
        $readmemh({prog_path, "model2/layer7/input1.hex"}, DRAM_1.Memory_byte1);
        $readmemh({prog_path, "model2/layer7/input2.hex"}, DRAM_1.Memory_byte2);
        $readmemh({prog_path, "model2/layer7/input3.hex"}, DRAM_1.Memory_byte3);
        #(`CYCLE*10) run = 0;
        //#(`CYCLE*5000) $finish;
    end

    initial begin
        $fsdbDumpfile("top_tb.fsdb");
        //$fsdbDumpvars("+struct","+mda", top_tb);
		$fsdbDumpvars(0,top_tb.top_1,"+struct","+mda");
		//$fsdbDumpvars("+struct","+mda", top_tb);
    end

	initial begin
        //#(`CYCLE*10000000)
		//#(`CYCLE*10000000)
		//#(`CYCLE*4100000)
		#(`CYCLE*600000)
		h = 48 * 48 * 32;
		//h = 48 * 2;//48 * 32 ;//*50 + 50*50*15;//*50*32;
		num = 0;
		gf = $fopen({prog_path, "model2/layer7/output.txt"}, "r");
		//gf = $fopen({prog_path, "model2/layer7/output_max_pooling.txt"}, "r");
        while (num < h)
        begin
            $fscanf(gf, "%d\n", GOLDEN[num]);
            num = num + 1;
        end

        // for(i=0;i<60;i++)
        // begin
        //     $display("%6h : %h",`INPUT_START + i,`mem_word(`INPUT_START + i));
        // end
		//$display("%h",`mem_word(1048576));
		// $display("\n");
		// for(i=0;i<60;i++)
        // begin
        //     $display("%6h : %h",`OUTPUT_START + i,`mem_word(`OUTPUT_START + i));
        // end
		$display("\n");
		// for(i=20700;i<20760;i++)
        // begin
        //     $display("%6h : %h",`OUTPUT_START + i,`mem_word(`OUTPUT_START + i));
        // end
		$display("\n");
		// for(i=170982;i<171042;i++)
        // begin
        //     $display("%6h : %h",`OUTPUT_START + i,`mem_word(`OUTPUT_START + i));
        // end
		$display("\n");
		//num = 414 * 414 + 414 * 414 * 2;
		num = 102 * 5 * 1 ;
		err = 0;
		for (i = 0; i < h; i++)
		begin
			if (`mem_word(`OUTPUT_START + i) !== GOLDEN[i])
			begin
				$display("DRAM[%8d] = %h, expect = %h", i, `mem_word(`OUTPUT_START + i), GOLDEN[i]);
				//$display("DRAM[%8d] = %4d, expect = %4d", i, `mem_word(`OUTPUT_START + i), GOLDEN[i]);
				err = err + 1;
			end
			else
			begin
				//$display("DRAM[%8d] = %h, pass", i, `mem_word(`OUTPUT_START + i));
			end
		end
		if (err == 0)
	    begin
	        $display("\n");
	        $display("\n");
	        $display("        ****************************               ");
	        $display("        **                        **       |\__||  ");
	        $display("        **  Congratulations !!    **      / O.O  | ");
	        $display("        **                        **    /_____   | ");
	        $display("        **  Simulation PASS!!     **   /^ ^ ^ \\  |");
	        $display("        **                        **  |^ ^ ^ ^ |w| ");
	        $display("        ****************************   \\m___m__|_|");
	        $display("\n");
	    end
	    else
	    begin
	    	$display("\n");
	        $display("\n");
	        $display("        ****************************               ");
	        $display("        **                        **       |\__||  ");
	        $display("        **  OOPS!!                **      / X,X  | ");
	        $display("        **                        **    /_____   | ");
	        $display("        **  Simulation Failed!!   **   /^ ^ ^ \\  |");
	        $display("        **                        **  |^ ^ ^ ^ |w| ");
	        $display("        ****************************   \\m___m__|_|");
	        $display("         Totally has %d errors                     ", err); 
	        $display("\n");
	    end
		i = 2570940;
		$display("%6h : %h",`OUTPUT_START + i,`mem_word(`OUTPUT_START + i));
		// for(i=0;i<60;i++)
        // begin
        //     $display("outputSRAM0[%6h] : %h",i,`outputSRAM0(i));
        // end

		// for(i=0;i<60;i++)
        // begin
        //     $display("outputSRAM1[%6h] : %h",i,`outputSRAM1(i));
        // end

        $finish;
    end

    initial
    begin
		prog_path ="/home/hsiao/bank64AI/on_chip_homework2/DRAM_INPUT/";
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
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[0].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[1].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[2].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[3].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[4].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[5].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[6].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[7].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[8].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[9].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[10].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[11].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[12].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[13].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[14].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[15].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[16].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[17].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[18].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[19].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[20].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[21].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[22].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[23].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[24].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[25].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[26].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[27].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[28].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[29].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[30].weight_SRAM_i.Data);
		// $readmemh({prog_path, "/weight_.hex"}, top_1.u_weight_SRAM[31].weight_SRAM_i.Data);
    end

endmodule
