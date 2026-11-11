"""
test_branch_predictor.py — cocotb tests for the 2-bit BHT branch predictor
Verifies:
  1. Initial state (weakly not-taken)
  2. State transitions on taken/not-taken feedback
  3. Saturating behaviour (doesn't exceed 11 or go below 00)
  4. Accuracy on a tight loop (should converge to Strongly Taken quickly)
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

async def reset_dut(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut.rst.value          = 1
    dut.update_valid.value = 0
    dut.update_pc.value    = 0
    dut.actual_taken.value = 0
    dut.pc.value           = 0
    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_initial_state_weakly_not_taken(dut):
    """After reset all entries should be 01 (Weakly Not-Taken) → predict=0"""
    await reset_dut(dut)
    for pc_val in [0x00, 0x04, 0x08, 0x10, 0x20, 0x40, 0xFC]:
        dut.pc.value = pc_val
        await RisingEdge(dut.clk)
        pred = int(dut.predicted_taken.value)
        assert pred == 0, f"PC={pc_val:#04x}: initial prediction should be 0 (Weakly NT), got {pred}"
    cocotb.log.info("✅ Initial state: all entries Weakly Not-Taken")

@cocotb.test()
async def test_state_machine_transitions(dut):
    """
    For one entry (PC=0x10), drive the full state machine:
    Reset→WNT(01) →taken→WT(10) →taken→ST(11) →!taken→WT(10) →!taken→WNT(01) →!taken→SNT(00)
    """
    await reset_dut(dut)
    test_pc = 0x10

    async def update(taken):
        dut.update_valid.value  = 1
        dut.update_pc.value     = test_pc
        dut.actual_taken.value  = 1 if taken else 0
        await RisingEdge(dut.clk)
        dut.update_valid.value  = 0
        await RisingEdge(dut.clk)

    async def predict():
        dut.pc.value = test_pc
        await RisingEdge(dut.clk)
        return int(dut.predicted_taken.value)

    # State: WNT (01) → predict 0
    assert await predict() == 0, "Start: should be Weakly NT"

    # taken → WT (10) → predict 1
    await update(True)
    assert await predict() == 1, "After 1×taken: Weakly Taken → predict 1"

    # taken → ST (11) → predict 1
    await update(True)
    assert await predict() == 1, "After 2×taken: Strongly Taken → predict 1"

    # taken again: should SATURATE at ST (11)
    await update(True)
    assert await predict() == 1, "ST saturates: still predict 1"

    # !taken → WT (10) → predict 1
    await update(False)
    assert await predict() == 1, "After 1×NT from ST: Weakly Taken → still predict 1"

    # !taken → WNT (01) → predict 0
    await update(False)
    assert await predict() == 0, "After 2×NT: Weakly NT → predict 0"

    # !taken → SNT (00) → predict 0
    await update(False)
    assert await predict() == 0, "After 3×NT: Strongly NT → predict 0"

    # !taken again: SATURATES at SNT (00)
    await update(False)
    assert await predict() == 0, "SNT saturates: still predict 0"

    cocotb.log.info("✅ State machine transitions: all correct")

@cocotb.test()
async def test_loop_convergence(dut):
    """
    Simulate a tight loop: branch taken 9 times, then not-taken once (exit).
    After the first iteration, predictor should converge to Strongly Taken.
    Accuracy should be >= 80%.
    """
    await reset_dut(dut)
    loop_pc  = 0x1C   # BNE at this PC
    total    = 0
    correct  = 0
    ITERS    = 10     # 10 full loop runs

    for iteration in range(ITERS):
        for step in range(10):   # 9 taken + 1 not-taken per iteration
            taken = (step < 9)
            # Get prediction
            dut.pc.value = loop_pc
            await RisingEdge(dut.clk)
            predicted = int(dut.predicted_taken.value)
            # Score
            total += 1
            if predicted == int(taken): correct += 1
            # Update
            dut.update_valid.value = 1
            dut.update_pc.value    = loop_pc
            dut.actual_taken.value = 1 if taken else 0
            await RisingEdge(dut.clk)
            dut.update_valid.value = 0

    accuracy = correct / total * 100
    cocotb.log.info(f"Loop predictor accuracy: {correct}/{total} = {accuracy:.1f}%")
    assert accuracy >= 80.0, f"Predictor accuracy {accuracy:.1f}% < 80% threshold"
    cocotb.log.info(f"✅ Branch predictor loop test: {accuracy:.1f}% accuracy (≥80% required)")

@cocotb.test()
async def test_independent_entries(dut):
    """Different PCs use different BHT entries — no aliasing for well-separated PCs"""
    await reset_dut(dut)
    pc_a = 0x04   # index 1
    pc_b = 0xFC   # index 63 — far apart

    # Train pc_a → Strongly Taken
    for _ in range(3):
        dut.update_valid.value = 1
        dut.update_pc.value    = pc_a
        dut.actual_taken.value = 1
        await RisingEdge(dut.clk)
    dut.update_valid.value = 0
    await RisingEdge(dut.clk)

    # pc_b should still be Weakly NT (untouched)
    dut.pc.value = pc_b
    await RisingEdge(dut.clk)
    pred_b = int(dut.predicted_taken.value)
    assert pred_b == 0, f"pc_b should still be Weakly NT (0), got {pred_b}"

    # pc_a should be Strongly Taken
    dut.pc.value = pc_a
    await RisingEdge(dut.clk)
    pred_a = int(dut.predicted_taken.value)
    assert pred_a == 1, f"pc_a should be Strongly Taken (1), got {pred_a}"

    cocotb.log.info("✅ BHT entries are independent (no cross-PC aliasing)")

