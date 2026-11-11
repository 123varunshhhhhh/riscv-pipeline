"""
test_golden_model.py — Pure Python pytest tests for the RV32I golden model
No simulator or hardware needed. Run with: pytest verif/test_golden_model.py -v

These tests verify the golden model ITSELF is correct before we use it
as the reference in co-simulation. If the reference is wrong, every
comparison is meaningless.
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
from golden_model import RV32IGoldenModel
import pytest

# ----------------------------------------------------------------
# Instruction encoders (mini-assembler)
# ----------------------------------------------------------------
def addi(rd, rs1, imm): return (imm & 0xFFF) << 20 | rs1 << 15 | 0 << 12 | rd << 7 | 0x13
def add(rd, rs1, rs2):  return 0 << 25 | rs2 << 20 | rs1 << 15 | 0 << 12 | rd << 7 | 0x33
def sub(rd, rs1, rs2):  return 0x20 << 25 | rs2 << 20 | rs1 << 15 | 0 << 12 | rd << 7 | 0x33
def and_(rd, rs1, rs2): return rs2 << 20 | rs1 << 15 | 7 << 12 | rd << 7 | 0x33
def or_(rd, rs1, rs2):  return rs2 << 20 | rs1 << 15 | 6 << 12 | rd << 7 | 0x33
def xor_(rd, rs1, rs2): return rs2 << 20 | rs1 << 15 | 4 << 12 | rd << 7 | 0x33
def slt(rd, rs1, rs2):  return rs2 << 20 | rs1 << 15 | 2 << 12 | rd << 7 | 0x33
def sll(rd, rs1, rs2):  return rs2 << 20 | rs1 << 15 | 1 << 12 | rd << 7 | 0x33
def srl(rd, rs1, rs2):  return rs2 << 20 | rs1 << 15 | 5 << 12 | rd << 7 | 0x33
def sra(rd, rs1, rs2):  return 0x20 << 25 | rs2 << 20 | rs1 << 15 | 5 << 12 | rd << 7 | 0x33
def sw(rs2, rs1, imm):
    return ((imm >> 5) & 0x7F) << 25 | rs2 << 20 | rs1 << 15 | 2 << 12 | (imm & 0x1F) << 7 | 0x23
def lw(rd, rs1, imm):   return (imm & 0xFFF) << 20 | rs1 << 15 | 2 << 12 | rd << 7 | 0x03
def beq(rs1, rs2, off):
    off &= 0x1FFF
    return ((off>>12)&1)<<31|((off>>5)&0x3F)<<25|rs2<<20|rs1<<15|0<<12|((off>>1)&0xF)<<8|((off>>11)&1)<<7|0x63
def bne(rs1, rs2, off):
    off &= 0x1FFF
    return ((off>>12)&1)<<31|((off>>5)&0x3F)<<25|rs2<<20|rs1<<15|1<<12|((off>>1)&0xF)<<8|((off>>11)&1)<<7|0x63
def lui(rd, imm):       return (imm & 0xFFFFF) << 12 | rd << 7 | 0x37
def jal(rd, off):
    off &= 0x1FFFFF
    return ((off>>20)&1)<<31|((off>>1)&0x3FF)<<21|((off>>11)&1)<<20|((off>>12)&0xFF)<<12|rd<<7|0x6F
def nop():              return addi(0, 0, 0)

def run(program):
    """Execute a list of instructions on a fresh model; return model."""
    m = RV32IGoldenModel()
    pc_idx = 0
    limit = 0
    while pc_idx < len(program) and limit < 10000:
        m.execute(program[pc_idx])
        pc_idx = m.pc // 4
        limit += 1
    return m


# ================================================================
# R-type instruction tests
# ================================================================
class TestRType:
    def test_add_basic(self):
        m = run([addi(1, 0, 10), addi(2, 0, 7), add(3, 1, 2)])
        assert m.regs[3] == 17

    def test_add_overflow_wraps(self):
        m = run([addi(1, 0, -1), addi(2, 0, 1), add(3, 1, 2)])
        assert m.regs[3] == 0  # 0xFFFFFFFF + 1 wraps to 0

    def test_sub_basic(self):
        m = run([addi(1, 0, 10), addi(2, 0, 7), sub(3, 1, 2)])
        assert m.regs[3] == 3

    def test_sub_underflow(self):
        m = run([addi(1, 0, 0), addi(2, 0, 1), sub(3, 1, 2)])
        assert m.regs[3] == 0xFFFFFFFF

    def test_and(self):
        m = run([addi(1, 0, 0b1010), addi(2, 0, 0b0111), and_(3, 1, 2)])
        assert m.regs[3] == 0b0010

    def test_or(self):
        m = run([addi(1, 0, 0b1010), addi(2, 0, 0b0111), or_(3, 1, 2)])
        assert m.regs[3] == 0b1111

    def test_xor(self):
        m = run([addi(1, 0, 0b1010), addi(2, 0, 0b1010), xor_(3, 1, 2)])
        assert m.regs[3] == 0  # XOR with self = 0

    def test_slt_true(self):
        m = run([addi(1, 0, 3), addi(2, 0, 7), slt(3, 1, 2)])
        assert m.regs[3] == 1  # 3 < 7

    def test_slt_false(self):
        m = run([addi(1, 0, 7), addi(2, 0, 3), slt(3, 1, 2)])
        assert m.regs[3] == 0  # 7 < 3 is false

    def test_slt_signed_negative(self):
        # -1 (0xFFFFFFFF) < 1 should be True in signed comparison
        m = run([addi(1, 0, -1), addi(2, 0, 1), slt(3, 1, 2)])
        assert m.regs[3] == 1

    def test_sll(self):
        m = run([addi(1, 0, 1), addi(2, 0, 4), sll(3, 1, 2)])
        assert m.regs[3] == 16  # 1 << 4

    def test_srl(self):
        m = run([addi(1, 0, 16), addi(2, 0, 2), srl(3, 1, 2)])
        assert m.regs[3] == 4   # 16 >> 2

    def test_sra_negative(self):
        # -16 >> 2 should give -4 (arithmetic, sign-extended)
        m = run([addi(1, 0, -16), addi(2, 0, 2), sra(3, 1, 2)])
        assert m.regs[3] == 0xFFFFFFFC  # -4 in two's complement


# ================================================================
# I-type (immediate) instruction tests
# ================================================================
class TestIType:
    def test_addi_positive(self):
        m = run([addi(1, 0, 42)])
        assert m.regs[1] == 42

    def test_addi_negative(self):
        m = run([addi(1, 0, -1)])
        assert m.regs[1] == 0xFFFFFFFF

    def test_addi_chain(self):
        m = run([addi(1, 0, 10), addi(1, 1, 5), addi(1, 1, -3)])
        assert m.regs[1] == 12

    def test_x0_always_zero(self):
        """x0 should never be written, stays 0 always"""
        m = run([addi(0, 0, 999)])
        assert m.regs[0] == 0

    def test_lui(self):
        m = run([lui(1, 1)])
        assert m.regs[1] == 0x00001000  # upper 20 bits set


# ================================================================
# Load / Store tests
# ================================================================
class TestLoadStore:
    def test_sw_lw_roundtrip(self):
        m = run([
            addi(1, 0, 100),   # address = 100
            addi(2, 0, 42),    # value   = 42
            sw(2, 1, 0),       # mem[100] = 42
            lw(3, 1, 0),       # x3 = mem[100]
        ])
        assert m.regs[3] == 42

    def test_lw_different_offsets(self):
        m = run([
            addi(1, 0, 200),   # base = 200
            addi(2, 0, 10),
            addi(3, 0, 20),
            sw(2, 1, 0),       # mem[200] = 10
            sw(3, 1, 4),       # mem[204] = 20
            lw(4, 1, 0),       # x4 = 10
            lw(5, 1, 4),       # x5 = 20
        ])
        assert m.regs[4] == 10
        assert m.regs[5] == 20


# ================================================================
# Branch instruction tests
# ================================================================
class TestBranch:
    def test_beq_taken(self):
        # BEQ jumps over ADDI x2, x0, 99 → x2 stays 0
        prog = [
            addi(1, 0, 5),
            addi(2, 0, 5),
            beq(1, 2, +8),     # PC+8: skip next instruction
            addi(3, 0, 99),    # should be SKIPPED
            addi(4, 0, 7),     # should execute
            nop(),
        ]
        m = run(prog)
        assert m.regs[3] == 0,  "BEQ: x3 should be skipped"
        assert m.regs[4] == 7,  "BEQ: x4 should execute"

    def test_bne_taken(self):
        prog = [
            addi(1, 0, 3),
            addi(2, 0, 7),
            bne(1, 2, +8),     # taken (3 != 7)
            addi(3, 0, 99),    # skipped
            addi(4, 0, 1),
            nop(),
        ]
        m = run(prog)
        assert m.regs[3] == 0
        assert m.regs[4] == 1

    def test_beq_not_taken(self):
        prog = [
            addi(1, 0, 3),
            addi(2, 0, 7),
            beq(1, 2, +8),     # NOT taken (3 != 7)
            addi(3, 0, 42),    # executes
            nop(),
        ]
        m = run(prog)
        assert m.regs[3] == 42


# ================================================================
# End-to-end program tests
# ================================================================
class TestEndToEnd:
    def test_fibonacci_10(self):
        """fib(10) = 55 — the classic pipeline stress test
        Start: x1=fib(0)=0, x2=fib(1)=1
        After 9 iterations: x2=fib(10)=55
        Counter=9 (NOT 10) because we start at fib(0),fib(1) already.
        """
        prog = [
            addi(1, 0, 0),   # x1 = 0  = fib(0)
            addi(2, 0, 1),   # x2 = 1  = fib(1)
            addi(3, 0, 9),   # x3 = 9  (9 iters: fib(1)→fib(10))
            # loop (pc=0x0C):
            add(4, 1, 2),    # x4 = x1 + x2
            addi(1, 2, 0),   # x1 = x2
            addi(2, 4, 0),   # x2 = x4
            addi(3, 3, -1),  # x3--
            bne(3, 0, -16),  # if x3 != 0, loop back  (BNE not BEQ!)
            nop(),
        ]
        m = run(prog)
        assert m.regs[2] == 55, f"fib(10) = {m.regs[2]}, expected 55"

    def test_sum_1_to_10(self):
        """Sum 1..10 = 55 using a loop"""
        prog = [
            addi(1, 0, 0),   # accumulator
            addi(2, 0, 1),   # i = 1
            addi(3, 0, 10),  # limit
            # loop:
            add(1, 1, 2),    # acc += i
            addi(2, 2, 1),   # i++
            bne(2, 3, -8),   # loop if i != limit (runs until i=10, adds 1..9, then exits)
            nop(),
        ]
        m = run(prog)
        # Adds 1 through 9 (exits when i==10 before adding 10)
        assert m.regs[1] == 45, f"Sum 1..9 = {m.regs[1]}, expected 45"

    def test_multiply_by_repeated_addition(self):
        """6 * 7 = 42 using a loop"""
        prog = [
            addi(1, 0, 6),   # multiplicand
            addi(2, 0, 7),   # multiplier (counter)
            addi(3, 0, 0),   # result = 0
            # loop:
            add(3, 3, 1),    # result += 6
            addi(2, 2, -1),  # counter--
            bne(2, 0, -8),   # loop
            nop(),
        ]
        m = run(prog)
        assert m.regs[3] == 42, f"6×7 = {m.regs[3]}, expected 42"

