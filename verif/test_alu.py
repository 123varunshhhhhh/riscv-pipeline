"""
test_alu.py — cocotb unit testbench for the ALU module
Run with: make SIM=icarus MODULE=test_alu
"""

import cocotb
from cocotb.triggers import Timer
import random

OPERATIONS = {
    "ADD":  (0b0000, lambda a, b: (a + b) & 0xFFFFFFFF),
    "SUB":  (0b0001, lambda a, b: (a - b) & 0xFFFFFFFF),
    "AND":  (0b0010, lambda a, b: a & b),
    "OR":   (0b0011, lambda a, b: a | b),
    "XOR":  (0b0100, lambda a, b: a ^ b),
    "SLL":  (0b0111, lambda a, b: (a << (b & 0x1F)) & 0xFFFFFFFF),
    "SRL":  (0b1000, lambda a, b: (a & 0xFFFFFFFF) >> (b & 0x1F)),
}

async def run_op(dut, ctrl, a, b, expected, op_name):
    dut.a.value        = a & 0xFFFFFFFF
    dut.b.value        = b & 0xFFFFFFFF
    dut.alu_ctrl.value = ctrl
    await Timer(2, units="ns")
    got = int(dut.result.value)
    assert got == expected, (
        f"[{op_name}] FAIL: a={a:#010x} b={b:#010x} "
        f"expected={expected:#010x} got={got:#010x}"
    )

@cocotb.test()
async def test_alu_random(dut):
    """1000 random tests per operation"""
    for op_name, (ctrl, fn) in OPERATIONS.items():
        for _ in range(1000):
            a = random.randint(0, 0xFFFFFFFF)
            b = random.randint(0, 0xFFFFFFFF)
            await run_op(dut, ctrl, a, b, fn(a, b), op_name)
        cocotb.log.info(f"✅ {op_name}: 1000 random tests PASSED")

@cocotb.test()
async def test_alu_edge_cases(dut):
    """Edge cases: overflow, zero operands, all-ones"""
    cases = [
        (0b0000, 0xFFFFFFFF, 1,          0x00000000, "ADD overflow"),
        (0b0001, 0x00000000, 1,          0xFFFFFFFF, "SUB underflow"),
        (0b0010, 0xFFFFFFFF, 0x00000000, 0x00000000, "AND with 0"),
        (0b0011, 0x00000000, 0xFFFFFFFF, 0xFFFFFFFF, "OR with 0xFFFF"),
        (0b0100, 0xFFFFFFFF, 0xFFFFFFFF, 0x00000000, "XOR with self"),
        (0b0000, 0,          0,          0,           "ADD zeros"),
    ]
    for ctrl, a, b, expected, name in cases:
        await run_op(dut, ctrl, a, b, expected, name)
        cocotb.log.info(f"✅ Edge: {name} PASSED")

@cocotb.test()
async def test_zero_flag(dut):
    """Zero flag should be high iff result == 0"""
    # SUB equal values → result=0, zero=1
    dut.a.value = 42; dut.b.value = 42; dut.alu_ctrl.value = 0b0001
    await Timer(2, units="ns")
    assert int(dut.zero.value) == 1, "zero flag should be 1 for 42-42"
    # ADD → result ≠ 0, zero=0
    dut.a.value = 1; dut.b.value = 2; dut.alu_ctrl.value = 0b0000
    await Timer(2, units="ns")
    assert int(dut.zero.value) == 0, "zero flag should be 0 for 1+2"
    cocotb.log.info("✅ Zero flag tests PASSED")

