"""
test_random.py — Constrained-random instruction generator + verification
Generates valid RV32I instruction streams, runs co-simulation,
and compares RTL vs Python golden model. Reports bugs automatically.
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from golden_model import RV32IGoldenModel
import random
import struct

# ----------------------------------------------------------------
# Constrained random RV32I instruction generator
# ----------------------------------------------------------------
class RV32IGenerator:
    REGS = list(range(1, 16))  # Only use x1-x15 (avoid stack pointer etc.)

    def r_type(self, funct7=0, funct3=0):
        rd, rs1, rs2 = random.sample(self.REGS, 3)
        return funct7<<25 | rs2<<20 | rs1<<15 | funct3<<12 | rd<<7 | 0x33

    def i_type_alu(self, funct3=0):
        rd, rs1 = random.sample(self.REGS, 2)
        imm = random.randint(-2048, 2047)
        return (imm & 0xFFF)<<20 | rs1<<15 | funct3<<12 | rd<<7 | 0x13

    def gen_program(self, length=50):
        """Generate a valid program with no memory ops (pure ALU + branches)"""
        instrs = []
        # Init registers with known values first
        for reg in self.REGS[:8]:
            imm = random.randint(1, 100)
            instrs.append((imm & 0xFFF)<<20 | 0<<15 | 0<<12 | reg<<7 | 0x13)
        # Random ALU instructions
        ops = [
            lambda: self.r_type(0x00, 0x0),  # ADD
            lambda: self.r_type(0x20, 0x0),  # SUB
            lambda: self.r_type(0x00, 0x7),  # AND
            lambda: self.r_type(0x00, 0x6),  # OR
            lambda: self.r_type(0x00, 0x4),  # XOR
            lambda: self.i_type_alu(0x0),    # ADDI
            lambda: self.i_type_alu(0x7),    # ANDI
            lambda: self.i_type_alu(0x6),    # ORI
        ]
        for _ in range(length):
            instrs.append(random.choice(ops)())
        # End with NOPs to let pipeline drain
        for _ in range(8):
            instrs.append(0x00000013)
        return instrs

@cocotb.test()
async def test_random_alu_cosim(dut):
    """
    Stress test: 500 random ALU instructions, compare all registers
    after each run against the golden Python model.
    """
    gen = RV32IGenerator()
    total_pass = 0
    total_fail = 0

    for trial in range(5):  # 5 independent programs
        program = gen.gen_program(length=100)

        # Run golden model
        model = RV32IGoldenModel()
        pc = 0
        idx = 0
        while idx < len(program):
            model.execute(program[idx])
            idx += 1

        # Run RTL (via cocotb reset + clock)
        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
        dut.rst.value = 1

        # Load program into instruction memory
        for i, instr in enumerate(program):
            dut.u_if.imem[i].value = instr
        for i in range(len(program), 256):
            dut.u_if.imem[i].value = 0x00000013

        await ClockCycles(dut.clk, 5)
        dut.rst.value = 0
        await ClockCycles(dut.clk, len(program) + 20)

        # Compare
        ok = True
        for i in range(1, 16):
            rtl_v   = int(dut.u_rf.regs[i].value)
            model_v = model.regs[i] & 0xFFFFFFFF
            if rtl_v != model_v:
                cocotb.log.error(
                    f"Trial {trial}: x{i} mismatch RTL={rtl_v:#010x} Model={model_v:#010x}")
                ok = False
                total_fail += 1

        if ok:
            total_pass += 1
            cocotb.log.info(f"✅ Trial {trial+1}/5: 100 random instructions — PASS")

    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Random Test Summary: {total_pass}/5 programs PASSED")
    assert total_fail == 0, f"{total_fail} register mismatches found!"

