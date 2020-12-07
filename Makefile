root_dir := $(PWD)
bld_dir := ./build
$(bld_dir):
	mkdir -p $(bld_dir)

PE: | $(bld_dir)
	cd $(bld_dir); \
	ncverilog ../PE_tb.sv +access+r +incdir+$(root_dir) +prog_path=$(root_dir);
top : | $(bld_dir)
	cd $(bld_dir); \
	ncverilog ../top_tb.sv +access+r +incdir+$(root_dir)
	# +prog_path=$(root_dir);
con : | $(bld_dir)
	cd $(bld_dir); \
	ncverilog ../controller_tb.sv +access+r +incdir+$(root_dir) +prog_path=$(root_dir);
SRAM : | $(bld_dir)
	cd $(bld_dir); \
	ncverilog ../top_tb.sv +access+r +incdir+$(root_dir) +prog_path=$(root_dir);
half : | $(bld_dir)
	cd $(bld_dir); \
	ncverilog ../half_tb.v +access+r +incdir+$(root_dir) +prog_path=$(root_dir);
DRAM : | $(bld_dir)
	cd $(bld_dir); \
	ncverilog ../DRAM_tb.sv +access+r +incdir+$(root_dir) +prog_path=$(root_dir);

clean:
	rm -rf $(bld_dir); \
	mkdir -p $(bld_dir);
