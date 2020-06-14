module DMA_controller(
    clk,
    rst,
    DRAM_ADDR_start,
    DRAM_ADDR_end,
    SRAM_ADDR_start,
    DMA_start,
    DMA_done,
    DMA_type,
    buf_select
);

    input   clk;
    input   rst;
    output	logic	[31:0]	DRAM_ADDR_start;
    output	logic	[31:0]	DRAM_ADDR_end;
    output	logic	[6:0]	SRAM_ADDR_start;
	output	logic	DMA_start;
	input	DMA_done;
	output	logic	SRAM_type;
	output	logic	buf_select;
