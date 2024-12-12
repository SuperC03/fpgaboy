import cocotb
import os
import random
import sys
from math import log
import logging
from cocotb.clock import Clock #useful for sequential logic
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
from pathlib import Path
from cocotb.triggers import Timer
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

@cocotb.test()
async def test_a(dut):
    """cocotb test for debouncer testing"""
    cocotb.start_soon(Clock(dut.clk_in, 10, "ns").start())
    await ClockCycles(dut.clk_in, 10)
    dut.dirty_in.value = 0
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 10)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 50)
    dut.dirty_in.value = 1
    await ClockCycles(dut.clk_in, 500)

def debouncer_runner():
    """Simulate the adder using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "debouncer.sv"]
    build_test_args = ["-Wall"]
    parameters = {"DEBOUNCE_TIME_MS":0.001}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="debouncer",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="debouncer",
        test_module="test_debouncer",
        test_args=run_test_args,
    )

if __name__ == "__main__":
    debouncer_runner()
