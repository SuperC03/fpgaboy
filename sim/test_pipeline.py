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

WIDTH: int = 8
STAGES: int = 8

async def reset(dut):
    """Resets the Pipeline."""
    dut.rst_in.value = 0b1;
    await ClockCycles(dut.clk_in, 2, rising=False)
    dut.rst_in.value = 0b0;
    await ClockCycles(dut.clk_in, 2, rising=False)


async def setup(dut):
    """Sets up the Pipeline."""
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.data_in.value = 0x00;
    await reset(dut)

@cocotb.test()
async def test_pipeline(dut):
    """Tests the Pipeline."""
    await setup(dut)
    pipeline: deque = deque(maxlen=STAGES)
    # Initialize the pipeline with zeros
    for _ in range(STAGES):
        pipeline.append(0)
    
    # Runs the test
    for _ in range(STAGES * 100):
        data = random.randint(0, 2**WIDTH - 1)
        dut.data_in.value = data
        pipeline.append(data)
        await ClockCycles(dut.clk_in, 1, rising=False)
        expected = pipeline.popleft()
        assert dut.data_out.value == expected, f"Expected {expected}, got {dut.data_out.value}"


def pipeline_runner():
    """Simulate the pipeline hdl using cocotb."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "Pipeline.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "WIDTH": WIDTH,
        "STAGES": STAGES
    }

    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="Pipeline",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="Pipeline",
        test_module="test_pipeline",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    pipeline_runner()