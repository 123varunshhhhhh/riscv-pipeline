"""
test_hazards.py — cocotb tests for RAW data hazards and load-use hazards
Verifies the forwarding unit and stall logic work correctly
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

def load_program(dut, instrs):
    for i, val in enumerate(instrs):
        dut.u_if.imem[i].value = val
    for i in range(len(instrs), 64):
        dut.u_if.imem[i].value = 0x00000013

async def reset(dut):
    dut.rst.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 2)

def read_reg(dut, idx):
    return int(dut.u_rf.regs[idx].value)

@cocotb.test()
async def test_raw_ex_ex_forwarding(dut):
    """
    EX-EX forwarding: result of instruction N forwarded directly to N+1
    Program:
        ADDI x1, x0, 5    # x1 = 5
        ADDI x2, x1, 3    # x2 = x1 + 3 = 8  ← RAW hazard on x1
    Expected: x2 = 8 (no stall needed with forwarding)
    """
    prog = [
        0x00500093,  # addi x1, x0, 5
        0x00308113,  # addi x2, x1, 3
    ]
    load_program(dut, prog)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)
    await ClockCycles(dut.clk, 15)   # Let pipeline drain
    assert read_reg(dut, 2) == 8, \
        f"EX-EX forward FAIL: x2={read_reg(dut, 2)}, expected 8"
    cocotb.log.info("✅ EX-EX Forwarding PASSED: x2 = 8")

@cocotb.test()
async def test_raw_mem_ex_forwarding(dut):
    """
    MEM-EX forwarding: result of N used by N+2
    Program:
        ADDI x1, x0, 10
        ADDI x3, x0, 1    # unrelated instruction
        ADD  x2, x1, x3   # x2 = 10 + 1 = 11 ← MEM-EX forward on x1
    Expected: x2 = 11
    """
    prog = [
        0x00a00093,  # addi x1, x0, 10
        0x00100193,  # addi x3, x0, 1
        0x00308133,  # add  x2, x1, x3
    ]
    load_program(dut, prog)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)
    await ClockCycles(dut.clk, 20)
    assert read_reg(dut, 2) == 11, \
        f"MEM-EX forward FAIL: x2={read_reg(dut, 2)}, expected 11"
    cocotb.log.info("✅ MEM-EX Forwarding PASSED: x2 = 11")

@cocotb.test()
async def test_load_use_stall(dut):
    """
    Load-use hazard: LW followed immediately by dependent instruction
    Pipeline MUST stall for 1 cycle (no forwarding can resolve this)
    Program:
        ADDI x1, x0, 100  # x1 = 100 (address)
        ADDI x5, x0, 42   # x5 = 42
        SW   x5, 0(x1)    # store x5=42 at addr 100
        LW   x2, 0(x1)    # x2 = mem[100] = 42
        ADD  x3, x2, x0   # x3 = x2 ← load-use hazard: stall required
    Expected: x3 = 42
    """
    prog = [
        0x06400093,  # addi x1, x0, 100
        0x02a00293,  # addi x5, x0, 42
        0x0050a023,  # sw   x5, 0(x1)
        0x0000a103,  # lw   x2, 0(x1)
        0x000101b3,  # add  x3, x2, x0
    ]
    load_program(dut, prog)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)
    await ClockCycles(dut.clk, 25)
    assert read_reg(dut, 3) == 42, \
        f"Load-use stall FAIL: x3={read_reg(dut, 3)}, expected 42"
    cocotb.log.info("✅ Load-Use Stall PASSED: x3 = 42")

@cocotb.test()
async def test_branch_flush(dut):
    """
    Branch taken: pipeline must flush 2 incorrectly-fetched instructions
    Program:
        ADDI x1, x0, 1
        BEQ  x1, x1, +8  # branch to skip next instruction (taken)
        ADDI x2, x0, 99  # should be flushed / skipped
        ADDI x3, x0, 7   # this executes after branch target
    Expected: x2 = 0 (flushed), x3 = 7
    """
    prog = [
        0x00100093,  # addi x1, x0, 1
        0x00108463,  # beq  x1, x1, +8 (skip next)
        0x06300113,  # addi x2, x0, 99 (flushed)
        0x00700193,  # addi x3, x0, 7
    ]
    load_program(dut, prog)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)
    await ClockCycles(dut.clk, 20)
    assert read_reg(dut, 2) == 0, \
        f"Branch flush FAIL: x2={read_reg(dut, 2)}, expected 0 (flushed)"
    assert read_reg(dut, 3) == 7, \
        f"Branch target FAIL: x3={read_reg(dut, 3)}, expected 7"
    cocotb.log.info("✅ Branch Flush PASSED: x2=0 (flushed), x3=7")

