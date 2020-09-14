#!/bin/bash
case "$1" in
	compile)
		gcc gen_input.c
		./a.out
		g++ gen_weight.cpp
		./a.out
		g++ gen_output.cpp
		./a.out 0 0;;
    input)
        objcopy input.hex -O verilog -i 4 -b 0 input_feature0.hex
        objcopy input.hex -O verilog -i 4 -b 1 input_feature1.hex
        objcopy input.hex -O verilog -i 4 -b 2 input_feature2.hex
        objcopy input.hex -O verilog -i 4 -b 3 input_feature3.hex;;
    weight)
        objcopy weight.hex -O verilog -i 4 -b 0 weight0.hex
        objcopy weight.hex -O verilog -i 4 -b 1 weight1.hex
        objcopy weight.hex -O verilog -i 4 -b 2 weight2.hex
        objcopy weight.hex -O verilog -i 4 -b 3 weight3.hex;;
    output)
        objcopy output.hex -O verilog -i 4 -b 0 tmp/output0.hex
        objcopy output.hex -O verilog -i 4 -b 1 tmp/output1.hex
        objcopy output.hex -O verilog -i 4 -b 2 tmp/output2.hex
        objcopy output.hex -O verilog -i 4 -b 3 tmp/output3.hex;;
    all)
        objcopy input.hex -O verilog -i 4 -b 0 input0.hex
        objcopy input.hex -O verilog -i 4 -b 1 input1.hex
        objcopy input.hex -O verilog -i 4 -b 2 input2.hex
        objcopy input.hex -O verilog -i 4 -b 3 input3.hex
        objcopy weight.hex -O verilog -i 4 -b 0 weight0.hex
        objcopy weight.hex -O verilog -i 4 -b 1 weight1.hex
        objcopy weight.hex -O verilog -i 4 -b 2 weight2.hex
        objcopy weight.hex -O verilog -i 4 -b 3 weight3.hex;;
    test)
        g++ gen_output.cpp
		./a.out $2 $3;;
    *)
		echo "error"
		exit 1;;
esac