# TinyTapeout cocotb Makefile

SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Project sources (must match info.yaml)
SRC_DIR := $(PWD)/../src
PROJECT_SOURCES := tt_um_adpll.v project.v

# RTL vs Gate-level
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

# Include design headers
COMPILE_ARGS += -I$(SRC_DIR)

# Testbench (Verilog)
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# cocotb Python module (test/test.py)
MODULE = test

# JUnit file for CI summary
export COCOTB_RESULTS_FILE := $(PWD)/results.xml

# Optional: fetch VCD after run
.PHONY: waves
waves:
	@cp -f $(SIM_BUILD)/**/tb.vcd $(PWD)/tb.vcd 2>/dev/null || true

# Hand off to cocotb’s rules (provides 'make' / 'make sim')
include $(shell cocotb-config --makefiles)/Makefile.sim
