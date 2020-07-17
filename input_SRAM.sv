`timescale 1 ns/1 ps
module input_SRAM (
    Q,
    CLK,
    CEN,
    WEN,
    A,
    D,
    OEN
);

    parameter  Words = 16;
    parameter  Bits = 128;            
    parameter  AddressSize = 7;

    output  [Bits-1:0] Q;
    input   CLK;
    input   CEN;
    input   WEN;
    input   [AddressSize-1:0] A;
    input   [Bits-1:0] D;
    input   OEN;

    logic   [Bits-1:0] Data [Words];
    logic   [Bits-1:0] Data_out;
    parameter Hi_Z_pattern = {Bits{1'bz}};

    assign  Q = Data_out;

    always_ff @(posedge CLK) 
    begin
        if(~CEN && ~WEN)
        begin
            Data[A] <= D;
        end
    end

    always_ff @(posedge CLK)
    begin
        if(~CEN && ~OEN)
        begin
            Data_out <= Data[A];
        end
        else
            Data_out <= Hi_Z_pattern;
    end


endmodule