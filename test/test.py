# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

CLK_NS = 20  # 50 MHz

@cocotb.test()
async def test_project(dut):
    """Minimal smoke test: start clock, reset, tick a bit."""
    try:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units="ns").start())
    except Exception:
        pass

    if hasattr(dut, "ena"):    dut.ena.value = 1
    if hasattr(dut, "ui_in"):  dut.ui_in.value = 0
    if hasattr(dut, "uio_in"): dut.uio_in.value = 0

    if hasattr(dut, "rst_n"):
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 5)
        dut.rst_n.value = 1
    else:
        await ClockCycles(dut.clk, 5)

    # harmless wiggle on ui[1] (clk_ref)
    if hasattr(dut, "ui_in"):
        for _ in range(8):
            dut.ui_in.value = int(dut.ui_in.value) ^ (1 << 1)
            await ClockCycles(dut.clk, 1)

    await ClockCycles(dut.clk, 100)
