#!/bin/bash
case "$1" in
	compile)
		gcc gen_input.c
		./a.out
		g++ gen_weight.cpp
		./a.out
		g++ gen_output.cpp
		./a.out;;
    input)
        objcopy input.hex -O verilog -i 4 -b 0 tmp/input_feature0.hex
        objcopy input.hex -O verilog -i 4 -b 1 tmp/input_feature1.hex
        objcopy input.hex -O verilog -i 4 -b 2 tmp/input_feature2.hex
        objcopy input.hex -O verilog -i 4 -b 3 tmp/input_feature3.hex;;
    weight)
        objcopy weight.hex -O verilog -i 4 -b 0 tmp/weight0.hex
        objcopy weight.hex -O verilog -i 4 -b 1 tmp/weight1.hex
        objcopy weight.hex -O verilog -i 4 -b 2 tmp/weight2.hex
        objcopy weight.hex -O verilog -i 4 -b 3 tmp/weight3.hex;;
    output)
        objcopy output.hex -O verilog -i 4 -b 0 tmp/output0.hex
        objcopy output.hex -O verilog -i 4 -b 1 tmp/output1.hex
        objcopy output.hex -O verilog -i 4 -b 2 tmp/output2.hex
        objcopy output.hex -O verilog -i 4 -b 3 tmp/output3.hex;;
    all)
        objcopy input.hex -O verilog -i 4 -b 0 input_feature0.hex
        objcopy input.hex -O verilog -i 4 -b 1 input_feature1.hex
        objcopy input.hex -O verilog -i 4 -b 2 input_feature2.hex
        objcopy input.hex -O verilog -i 4 -b 3 input_feature3.hex
        objcopy weight.hex -O verilog -i 4 -b 0 weight0.hex
        objcopy weight.hex -O verilog -i 4 -b 1 weight1.hex
        objcopy weight.hex -O verilog -i 4 -b 2 weight2.hex
        objcopy weight.hex -O verilog -i 4 -b 3 weight3.hex;;
    *)
		echo "error"
		exit 1;;
esac