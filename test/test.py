# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start ADPLL test")

    # Clock: 20 ns period = 50 MHz (matches info.yaml)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Resetting DUT")
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 5)

    # Quick check: uio_oe directions
    uio_oe = int(dut.uio_oe.value)
    dut._log.info(f"uio_oe = {uio_oe:08b}")
    assert (uio_oe & 0b11) == 0b11, "fb_clk & dco_out should be outputs"

    # Apply a reference clock pulse stream on ui[1] = clk_ref
    dut._log.info("Driving reference clock on ui_in[1]")
    for _ in range(20):
        dut.ui_in.value = dut.ui_in.value ^ (1 << 1)  # toggle bit[1]
        await ClockCycles(dut.clk, 1)

    # Program a value: param_sel = 1 (alpha), pgm_value = 0b10101
    dut._log.info("Programming alpha = 0b10101")
    dut.uio_in.value = (0b10101 << 2)  # bits 6:2
    dut.ui_in.value  = (1 << 3) | (1 << 5)  # pgm=1, param_sel=1
    await ClockCycles(dut.clk, 2)
    dut.ui_in.value  = (0 << 3) | (1 << 5)  # pgm back to 0
    await ClockCycles(dut.clk, 2)

    # Observe toggling on dco_out (uio_out[1]) or fb_clk (uio_out[0])
    prev_val = int(dut.uio_out.value & 0b11)
    toggled  = False
    for _ in range(2000):
        await RisingEdge(dut.clk)
        now_val = int(dut.uio_out.value & 0b11)
        if now_val != prev_val:
            toggled = True
            break
        prev_val = now_val

    assert toggled, "Expected dco_out/fb_clk to toggle after programming"

    dut._log.info("ADPLL basic smoke test passed")
