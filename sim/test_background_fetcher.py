import os
import random
import struct
import sys

from collections import deque
from pathlib import Path
from pprint import pprint, pformat

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

X_MAX: int = 160
TOTAL_SCANLINES: int = 8

async def reset(dut):
    """Resets the FIFO."""
    dut.rst_in.value = 0b1;
    await ClockCycles(dut.clk_in, 2, rising=False)
    dut.rst_in.value = 0b0;
    await ClockCycles(dut.clk_in, 2, rising=False)


async def set_inputs(
    dut,
    X: int, Y: int,
    SCY: int, SCX: int, bg_map: int,
    WY: int, WX: int, WY_cond: int, win_map: int, win_ena: int,
    addr_mode: int,
    data: int, data_valid: int,
    bg_fifo_empty: int
):
    dut. X_in.value = X
    dut.Y_in.value = Y

    dut.SCY_in.value = SCY
    dut.SCX_in.value = SCX
    dut.background_map_in.value = bg_map

    dut.WY_in.value = WY
    dut.WX_in.value = WX
    dut.WY_cond_in.value = WY_cond
    dut.window_map_in.value = win_map
    dut.window_ena_in.value = win_ena

    dut.addressing_mode_in.value = addr_mode
    dut.data_in.value = data
    dut.data_valid_in.value = data_valid

    dut.bg_fifo_empty_in.value = bg_fifo_empty


async def tclk_tick(dut):
    """Blips the tclk signal once per 250ns."""
    await FallingEdge(dut.clk_in)
    while True:
        dut.tclk_in.value = 0b1
        await ClockCycles(dut.clk_in, 1, rising=False)
        dut.tclk_in.value = 0b0
        await ClockCycles(dut.clk_in, 24, rising=False)


async def setup(dut):
    """Sets up the FIFO."""
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    await reset(dut)
    await set_inputs(
        dut,
        0, 0,
        0, 0, 0b0,
        0, 0, 0, 0b0, 0b0,
        0b0,
        0, 0b0,
        0b1
    )


def check_outputs(
        dut, 
        addr_out: int, addr_valid_out: bool, 
        pixels_out: tuple[int], valid_pixels_out: bool 
):
    """Checks the FIFO outputs."""
    assert dut.addr_valid_out.value == addr_valid_out, (
        f"Expected {bin(addr_valid_out)}, got {dut.addr_valid_out.value}"
    )
    if addr_valid_out:
        assert dut.addr_out.value.integer == addr_out, (
            f"Expected {hex(addr_out)}, got {hex(dut.addr_out.value.integer)}"
        )
    assert dut.valid_pixels_out.value == valid_pixels_out, (
        f"Expected {bin(valid_pixels_out)}, got {dut.valid_pixels_out.value}"
    )
    if valid_pixels_out:
        assert tuple(dut.pixels_out.value) == pixels_out, (
            f"Expected {[bin(pixel) for pixel in pixels_out]}, got {dut.pixels_out.value}"
        )
    
# @cocotb.test()
async def test_reset(dut):
    """Tests the background fetcher reset."""
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await cocotb.start(tclk_tick(dut))

    await setup(dut)
    await FallingEdge(dut.clk_in)
    check_outputs(dut, 0, False, 0, False)


@cocotb.test()
async def test_nonpush_timing(dut):
    """
    Tests the timings for expected values with all 0 inputs, an empty bg_fifo, and 
    valid data in being all 0s."""
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await cocotb.start(tclk_tick(dut))

    await reset(dut)
    await set_inputs(
        dut,
        0, 0,
        0, 0, 0b0,
        0, 0, 0, 0b0, 0b0,
        0b0,
        0, 0b1,
        0b1
    )
    await FallingEdge(dut.tclk_in)
    check_outputs(dut, 0, False, 0, False)

    # Tests the fact it outputs an addr 2 tclk if it can write to buffer.
    for x in range(4):
        # Fetch tile # T1.
        await ClockCycles(dut.clk_in, 2, rising=False)
        # check_outputs(dut, 0x9800 + x, True, None, False)
        await FallingEdge(dut.tclk_in)
        # Fetch tile # T2.
        await ClockCycles(dut.clk_in, 2, rising=False)
        # check_outputs(dut, None, False, None, False)
        await FallingEdge(dut.tclk_in)

        # Fetch Tile Data Low T1.
        await ClockCycles(dut.clk_in, 2, rising=False)
        # check_outputs(dut, 0x9000, True, None, False)
        await FallingEdge(dut.clk_in)
        # Fetch Tile Data Low T2.
        await ClockCycles(dut.clk_in, 2, rising=False)
        # check_outputs(dut, None, False, None, False)
        await FallingEdge(dut.tclk_in)

        # Fetch Tile Data High T1.
        await ClockCycles(dut.clk_in, 2, rising=False)
        # check_outputs(dut, 0x9001, True, None, False)
        await FallingEdge(dut.tclk_in)
        # Fetch Tile Data High T2.
        await ClockCycles(dut.clk_in, 2, rising=False)
        # check_outputs(dut, None, False, (0,) * 8, True)
        await FallingEdge(dut.tclk_in)


def background_fetcher_runner():
    """Simulate the FIFO hdl using cocotb."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "hdl" /"evt_counter.sv",
        proj_path / "hdl" / "pixel_fetcher.sv"
    ]
    build_test_args = ["-Wall"]
    parameters = {
        "X_MAX": X_MAX,
        "TOTAL_SCANLINES": TOTAL_SCANLINES
    }

    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="BackgroundFetcher",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="BackgroundFetcher",
        test_module="test_background_fetcher",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    background_fetcher_runner()