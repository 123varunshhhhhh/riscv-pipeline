"""
test_pipeline.py — Co-simulation integration test
Runs the golden Python model alongside the RTL and compares
register state after every instruction. Reports any mismatch.
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from golden_model import RV32IGoldenModel

# ----------------------------------------------------------------
# Simple RV32I assembler (encodes instructions as 32-bit ints)
# ----------------------------------------------------------------
def addi(rd, rs1, imm): return (imm & 0xFFF) << 20 | rs1 << 15 | 0b000 << 12 | rd << 7 | 0x13
def add(rd, rs1, rs2):  return 0 << 25 | rs2 << 20 | rs1 << 15 | 0 << 12 | rd << 7 | 0x33
def sub(rd, rs1, rs2):  return 0x20 << 25 | rs2 << 20 | rs1 << 15 | 0 << 12 | rd << 7 | 0x33
def beq(rs1, rs2, off): 
    off &= 0x1FFF
    return ((off>>12)&1)<<31 | ((off>>5)&0x3F)<<25 | rs2<<20 | rs1<<15 | 0<<12 | ((off>>1)&0xF)<<8 | ((off>>11)&1)<<7 | 0x63
def bne(rs1, rs2, off):
    off &= 0x1FFF
    return ((off>>12)&1)<<31 | ((off>>5)&0x3F)<<25 | rs2<<20 | rs1<<15 | 1<<12 | ((off>>1)&0xF)<<8 | ((off>>11)&1)<<7 | 0x63
def nop(): return addi(0, 0, 0)

# ----------------------------------------------------------------
# Fibonacci program: computes fib(10)=55 in x2
# Start: x1=fib(0)=0, x2=fib(1)=1
# 9 iterations yields: fib(2)=1, fib(3)=2, ..., fib(10)=55
# ----------------------------------------------------------------
FIB_PROGRAM = [
    addi(1,  0, 0),   # x1 = 0
    addi(2,  0, 1),   # x2 = 1
    addi(3,  0, 9),   # x3 = 9 (9 iterations gives fib(10))
    # loop:
    add(4,  1, 2),    # x4 = x1 + x2
    addi(1, 2, 0),    # x1 = x2
    addi(2, 4, 0),    # x2 = x4
    addi(3, 3, -1),   # x3 -= 1
    bne(3,  0, -16),  # loop if x3 != 0 (BNE!)
    nop(),
]

@cocotb.test()
async def test_cosimulation_fibonacci(dut):
    """
    Co-simulate: run Fibonacci on RTL and Python model in lockstep.
    After pipeline drains, compare all register values.
    """
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0

    # Run golden model on the program
    model = RV32IGoldenModel()
    pc    = 0
    while pc // 4 < len(FIB_PROGRAM):
        instr = FIB_PROGRAM[pc // 4]
        model.execute(instr)
        pc = model.pc

    # Give RTL enough cycles to finish (instructions × pipeline depth + drain)
    await ClockCycles(dut.clk, len(FIB_PROGRAM) * 2 + 20)

    # Compare every register
    mismatches = []
    for i in range(1, 32):
        rtl_val   = int(dut.u_rf.regs[i].value)
        model_val = model.regs[i]
        if rtl_val != model_val:
            mismatches.append(
                f"  x{i:02d}: RTL={rtl_val:#010x}  Model={model_val:#010x}")

    if mismatches:
        cocotb.log.error("❌ Co-simulation MISMATCH:\n" + "\n".join(mismatches))
        assert False, f"Register mismatch in {len(mismatches)} register(s)"
    else:
        fib10 = model.regs[2]
        cocotb.log.info(f"✅ Co-simulation PASSED — fib(10)={fib10} in x2")
        assert fib10 == 55, f"fib(10) should be 55, got {fib10}"

