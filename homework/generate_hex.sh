#!/bin/bash
case "$1" in
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
        objcopy output.hex -O verilog -i 4 -b 0 output0.hex
        objcopy output.hex -O verilog -i 4 -b 1 output1.hex
        objcopy output.hex -O verilog -i 4 -b 2 output2.hex
        objcopy output.hex -O verilog -i 4 -b 3 output3.hex;;
    all)
        objcopy input.hex -O verilog -i 4 -b 0 input_feature0.hex
        objcopy input.hex -O verilog -i 4 -b 1 input_feature1.hex
        objcopy input.hex -O verilog -i 4 -b 2 input_feature2.hex
        objcopy input.hex -O verilog -i 4 -b 3 input_feature3.hex
        objcopy weight.hex -O verilog -i 4 -b 0 weight0.hex
        objcopy weight.hex -O verilog -i 4 -b 1 weight1.hex
        objcopy weight.hex -O verilog -i 4 -b 2 weight2.hex
        objcopy weight.hex -O verilog -i 4 -b 3 weight3.hex
        objcopy output.hex -O verilog -i 4 -b 0 output0.hex
        objcopy output.hex -O verilog -i 4 -b 1 output1.hex
        objcopy output.hex -O verilog -i 4 -b 2 output2.hex
        objcopy output.hex -O verilog -i 4 -b 3 output3.hex;;
    *)
		echo "error"
		exit 1;;
esac