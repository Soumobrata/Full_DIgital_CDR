
# TinyTapeout cocotb Makefile

# --- Simulator & language ---
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# --- Project sources (must match info.yaml) ---
SRC_DIR := $(PWD)/../src
PROJECT_SOURCES := tt_um_adpll.v project.v

# RTL vs Gate-level build dirs
ifneq ($(GATES),yes)

SIM_BUILD := sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

SIM_BUILD := sim_build/gl
COMPILE_ARGS    += -DGL_TEST -DFUNCTIONAL -DUSE_POWER_PINS -DSIM -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Include design headers if you have any shared includes
COMPILE_ARGS += -I$(SRC_DIR)

# --- Testbench (Verilog) ---
# Name your TB file 'tb.v' OR change the filename here to match your TB.
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# --- cocotb Python test module ---
# Looks for test/test.py
MODULE = test

# --- Make CI find test/results.xml (JUnit) ---
# cocotb will write results here so the TT workflow can upload it.
export COCOTB_RESULTS_FILE := $(PWD)/results.xml

# include cocotb rules
include $(shell cocotb-config --makefiles)/Makefile.sim
