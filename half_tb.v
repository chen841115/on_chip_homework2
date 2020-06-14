`include "half.v"
module half_tb;
    reg a,b,c;
    wire d;

    half half_1(a,b,d);

    initial
    begin
        #10 a=0;b=0;
        #10 a=1;b=1;
        $finish;
    end

    initial begin
        $fsdbDumpfile("half_tb.fsdb");
        $fsdbDumpvars("+struct","+mda", half_tb);
    end
endmodule