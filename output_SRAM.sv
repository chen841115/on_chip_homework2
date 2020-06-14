`timescale 1 ns/1 ps
module output_SRAM (
    QA,
    CLKA,
    CENA,
    WENA,
    AA,
    DA,
    OENA,
    QB,
    CLKB,
    CENB,
    WENB,
    AB,
    DB,
    OENB
);

    parameter  Words = 2880;
    parameter  Bits = 32;            
    parameter  AddressSize = 12;

    output  [Bits-1:0] QA;
    input   CLKA;
    input   CENA;
    input   WENA;
    input   [AddressSize-1:0] AA;
    input   [Bits-1:0] DA;
    input   OENA;

    output  [Bits-1:0] QB;
    input   CLKB;
    input   CENB;
    input   WENB;
    input   [AddressSize-1:0] AB;
    input   [Bits-1:0] DB;
    input   OENB;

    logic   [Bits-1:0] Data [Words];
    logic   [Bits-1:0] Data_out1;
    logic   [Bits-1:0] Data_out2;
    parameter Hi_Z_pattern = {Bits{1'bz}};

    assign  QA = Data_out1;
    assign  QB = Data_out2;

    always_ff @(posedge CLKA) 
    begin
        if(~CENA && ~WENA)
        begin
            Data[AA] <= DA;
        end
        if(~CENB && ~WENB)
        begin
            Data[AB] <= DB;
        end
    end

    always_ff @(posedge CLKA)
    begin
        if(~CENA && ~OENA)
        begin
            Data_out1 <= Data[AA];
        end
        else
            Data_out1 <= Hi_Z_pattern;
    end
    always_ff @(posedge CLKB)
    begin
        if(~CENB && ~OENB)
        begin
            Data_out2 <= Data[AB];
        end
        else
            Data_out2 <= Hi_Z_pattern;
    end


endmodule