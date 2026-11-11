#!/usr/bin/env bash
# ============================================================
# run_sim.sh — Quick simulation launcher for Linux / WSL2 / macOS
# Usage: chmod +x run_sim.sh && ./run_sim.sh
# ============================================================
set -e

echo ""
echo "=========================================="
echo "  RISC-V Pipeline — Quick Simulation"
echo "=========================================="
echo ""

mkdir -p sim/waveforms sim/logs

RTL_SOURCES="rtl/alu.v rtl/reg_file.v rtl/if_stage.v rtl/id_stage.v \
             rtl/ex_stage.v rtl/mem_stage.v rtl/wb_stage.v \
             rtl/pipeline_regs.v rtl/hazard_unit.v rtl/branch_predictor.v \
             rtl/top.v"

# ---- ALU Standalone Test ----------------------------------------
echo "[1/3] Compiling ALU standalone testbench..."
iverilog -g2012 -o sim/alu_tb_out rtl/alu.v verif/tb_alu_standalone.v
echo "[2/3] Running ALU simulation..."
vvp sim/alu_tb_out | tee sim/logs/alu_sim.log

# ---- Full Pipeline Test ----------------------------------------
echo ""
echo "[3/3] Compiling full pipeline testbench..."
iverilog -g2012 -o sim/tb_top_out $RTL_SOURCES verif/tb_top.v
echo "      Running pipeline simulation (Fibonacci)..."
vvp sim/tb_top_out | tee sim/logs/pipeline_sim.log

echo ""
echo "=========================================="
echo "  Waveforms: sim/waveforms/tb_top.vcd"
echo "  Logs:      sim/logs/"
echo ""
echo "  View waveform: gtkwave sim/waveforms/tb_top.vcd"
echo "=========================================="
echo ""

# ---- Run Python golden model tests (no simulator needed) ------
if command -v python3 &>/dev/null; then
    echo "Running Python golden model tests..."
    python3 -m pytest verif/test_golden_model.py -v --tb=short 2>&1 | tee sim/logs/golden_tests.log
    echo ""
fi

echo "✅ All simulations complete!"

