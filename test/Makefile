
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

SIM ?= icarus
TOPLEVEL_LANG ?= verilog

SRC_DIR = $(PWD)/../src
# RTL source files (just basenames)
PROJECT_SOURCES = cdr.v project.v

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD         = sim_build/rtl
VERILOG_SOURCES  += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# Gate-level simulation:
SIM_BUILD         = sim_build/gl
COMPILE_ARGS     += -DGL_TEST
COMPILE_ARGS     += -DFUNCTIONAL
COMPILE_ARGS     += -DSIM
VERILOG_SOURCES  += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
VERILOG_SOURCES  += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v
VERILOG_SOURCES  += $(PWD)/gate_level_netlist.v

# Wrapper for GL sims
VERILOG_SOURCES  += $(SRC_DIR)/project.v
endif

# Share include path with both design and tb
COMPILE_ARGS     += -I$(SRC_DIR)

# Testbench & cocotb entry (your tb instantiates tt_um_sfg_cdr)
VERILOG_SOURCES  += $(PWD)/tb.v
TOPLEVEL = tb
MODULE   = test

include $(shell cocotb-config --makefiles)/Makefile.sim
