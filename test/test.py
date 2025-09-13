
# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.triggers import ClockCycles

CLK_NS = 20  # 50 MHz period (from tb.v)

@cocotb.test()
async def test_project(dut):
    """Minimal smoke test: use the Verilog TB clock only; pulse reset; tick a bit."""

    # DO NOT START a cocotb Clock here; tb.v already drives clk.

    # Safe defaults
    if hasattr(dut, "ena"):    dut.ena.value = 1
    if hasattr(dut, "ui_in"):  dut.ui_in.value = 0
    if hasattr(dut, "uio_in"): dut.uio_in.value = 0

    # Reset low for a few cycles, then high
    if hasattr(dut, "rst_n"):
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 5)
        dut.rst_n.value = 1
    else:
        await ClockCycles(dut.clk, 5)

    # Wiggle ui[1] a few times (clk_ref) — harmless stimulus
    if hasattr(dut, "ui_in"):
        for _ in range(8):
            dut.ui_in.value = int(dut.ui_in.value) ^ (1 << 1)
            await ClockCycles(dut.clk, 1)

    # Let it run a little so VCD has waves
    await ClockCycles(dut.clk, 100)

    # No assertions; reaching here = PASS
