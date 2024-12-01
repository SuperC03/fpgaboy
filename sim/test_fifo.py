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
DEPTH: int = 8


async def reset(dut):
    dut.rst_in.value = 0b1;
    await ClockCycles(dut.clk_in, 2, rising=False)
    dut.rst_in.value = 0b0;
    await ClockCycles(dut.clk_in, 2, rising=False)

@cocotb.test()
async def test_within_capacity(dut):
    """Tests the FIFO without reading or writing more than the capacity limits."""
    # Seeds the RNG.
    rng: random.Random = random.Random(42)
    # Sets up the FIFO.
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.wr_en.value = 0b0;
    dut.rd_en.value = 0b0;
    dut.data_in.value = 0x00;
    await reset(dut)

    # Creates a deque of similar limit.
    FIFO: deque = deque([], DEPTH)

    for _ in range(DEPTH * 4):
        inserts: int = rng.randint(0, DEPTH)
        removals: int = inserts

        # Inserts n elements in n clock cycles.
        for _ in range(inserts):
            await FallingEdge(dut.clk_in)
            element: int = rng.getrandbits(WIDTH)
            dut.wr_en.value = 0b1
            dut.data_in.value = element
            FIFO.append(element)
            await ClockCycles(dut.clk_in, 1, rising=False)
            dut.wr_en.value = 0b0
            assert (occ := dut.occupancy_out.value) == (deq := len(FIFO)), f"Expected occupancy {deq} not {occ}"
            # Tests the stability of intermittent writes.
            await ClockCycles(dut.clk_in, rng.randint(0, DEPTH // 2), rising=False)
        
        # Removes n elements in n clock cycles.
        for _ in range(removals):
            await FallingEdge(dut.clk_in)
            dut.rd_en.value = 0b1
            ref: int = FIFO.popleft()
            await ClockCycles(dut.clk_in, 1, rising=False)
            dut.rd_en.value = 0b0

            assert dut.data_valid_out.value == 0b1, "Expected 1-cycle reads."
            assert (out := dut.data_out.value) == ref, f"Received {out} instead of {ref}"

            # Tests the stability of intermittent reads.
            await ClockCycles(dut.clk_in, rng.randint(0, DEPTH // 2), rising=False)
    

def fifo_runner():
    """Simulate the FIFO hdl using cocotb."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "fifo.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "WIDTH": WIDTH,
        "DEPTH": DEPTH
    }

    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="FIFO",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="FIFO",
        test_module="test_fifo",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
   fifo_runner()