import cocotb
import os
import random
import sys
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

MAX_COUNT = 16

async def reset(dut):
    """Resets the evt_counter."""
    dut.rst_in.value = 0b1
    await ClockCycles(dut.clk_in, 1, rising=False)
    dut.rst_in.value = 0b0


async def setup(dut):
    """Sets up the evt_counter."""
    await reset(dut)
    dut.evt_in.value = 0b0
    await ClockCycles(dut.clk_in, 1, rising=False)


@cocotb.test()
async def test_a(dut):
    """cocotb test?"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    await setup(dut)
    assert dut.count_out.value.integer == 0, "Reset not setting count_out to 0 :/"
    
    for i in range(1, 2*MAX_COUNT + 1):
        dut.evt_in.value = 0b1
        await ClockCycles(dut.clk_in, 1, rising=False)
        assert dut.count_out.value.integer == i % MAX_COUNT, (
            f"count_out not incrementing on evt: {i} != {dut.count_out.value.integer}"
        )
        dut.evt_in.value = 0b0
        await ClockCycles(dut.clk_in, 1, rising=False)
        assert dut.count_out.value.integer == i % MAX_COUNT, (
            f"count_out incrementing on !evt: {i} != {dut.count_out.value.integer}"
        )


def evt_counter_runner():
    """Simulate the counter using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "evt_counter.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "MAX_COUNT": 16
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="EvtCounter",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="EvtCounter",
        test_module="test_evt_counter",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    evt_counter_runner()
