`timescale 1ns/10ps
`define CYCLE 10
`include "SRAM2RW2880x16.v"
`define MAX 10000

module SRAM2RW2880x16_test;

	logic	[15:0]	QA;
    logic	CLKA;
    logic	CENA;
    logic	WENA;
    logic	[11:0]	AA;
    logic	[15:0]	DA;
    logic	OENA;

	logic	[15:0]	QB;
    logic	CLKB;
    logic	CENB;
    logic	WENB;
    logic	[11:0]	AB;
    logic	[15:0]	DB;
    logic	OENB;

    SRAM2RW2880x16 SRAM2RW2880x16_1(
        .QA(QA),
        .CLKA(CLKA),
        .CENA(CENA),
        .WENA(WENA),
        .AA(AA),
        .DA(DA),
        .OENA(OENA),
		.QB(QB),
        .CLKB(CLKB),
        .CENB(CENB),
        .WENB(WENB),
        .AB(AB),
        .DB(DB),
        .OENB(OENB)
    );

    always #(`CYCLE/2) CLKA = ~CLKA;  
	always #(`CYCLE/2) CLKB = ~CLKB;  
    
    
    initial 
    begin
        CLKA = 0;
        CENA = 0;
        WENA = 0;
        DA = 8'h0;
        OENA = 1;
        AA = 0;
		#(`CYCLE*0.75)
        #(`CYCLE) DA = 8'hf;
        #(`CYCLE) WENA = 1; OENA = 0; DA = 8'h0;
        #(`CYCLE) WENA = 0; OENA = 1; DA = 8'haa;
        #(`CYCLE) WENA = 1; OENA = 0; DA = 8'h0;
        #(`CYCLE) WENA = 0; OENA = 1; DA = 8'hf1;
        #(`CYCLE) WENA = 1; OENA = 0; DA = 8'h0;

        
        
        #(`CYCLE*50) $finish;
    end

    initial begin
        $fsdbDumpfile("SRAM2RW2880x16_test.fsdb");
        $fsdbDumpvars("+struct","+mda", SRAM2RW2880x16_test);
    end

endmodule
