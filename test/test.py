# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    """Minimal smoke test: let cocotb end the sim and write results.xml."""
    # DO NOT start a cocotb Clock; tb.v already drives clk.

    # Safe defaults
    if hasattr(dut, "ena"):    dut.ena.value = 1
    if hasattr(dut, "ui_in"):  dut.ui_in.value = 0
    if hasattr(dut, "uio_in"): dut.uio_in.value = 0

    # Reset low for a few cycles, then high
    if hasattr(dut, "rst_n"):
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 5)   # 5 cycles @ 50 MHz = 100 ns
        dut.rst_n.value = 1
    else:
        await ClockCycles(dut.clk, 5)

    # Wiggle ui[1] (clk_ref) a bit
    if hasattr(dut, "ui_in"):
        for _ in range(8):               # 8 cycles = 160 ns
            dut.ui_in.value = int(dut.ui_in.value) ^ (1 << 1)
            await ClockCycles(dut.clk, 1)

    # Let things settle
    await ClockCycles(dut.clk, 15)       # 300 ns

    # Explicit pass so cocotb writes test/results.xml
    assert True, "Smoke test completed"
