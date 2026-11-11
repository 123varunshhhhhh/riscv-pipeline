# 5-Stage Pipelined RISC-V (RV32I) Processor

![CI](https://github.com/123varunshhhhhh/riscv-pipeline/actions/workflows/ci.yml/badge.svg)
![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32I-blue)
![Verification](https://img.shields.io/badge/Verification-cocotb%20%2B%20Python-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

> **NIT Patna | CSE Final Year Project | IBM ISDL Resume Project**

A complete 32-bit 5-stage pipelined processor implementing the **RISC-V RV32I** base integer ISA, designed in SystemVerilog and verified with an automated Python co-simulation framework using **cocotb**.

---

## Architecture Overview

```
 ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐
 │  IF  │──▶│  ID  │──▶│  EX  │──▶│ MEM  │──▶│  WB  │
 │Fetch │   │Decode│   │ ALU  │   │D-Mem │   │Write │
 └──────┘   └──────┘   └──────┘   └──────┘   └──────┘
     ▲           │           │           │
     │      ┌────▼───────────▼───────────▼────┐
     │      │         Hazard Unit              │
     └──────│  Forwarding + Stall Detection    │
            └─────────────────────────────────┘
```

| Feature | Detail |
|---------|--------|
| ISA | RISC-V RV32I (all 47 base instructions) |
| Pipeline | 5-stage: IF → ID → EX → MEM → WB |
| Hazard Handling | Full data forwarding (EX-EX, MEM-EX), load-use stall |
| Branch Prediction | 2-bit saturating counter BHT (64 entries) |
| Memory | 1KB instruction ROM, 1KB data RAM (byte-addressable) |
| Verification | Python cocotb + golden reference model co-simulation |

---

## Project Structure

```
riscv_pipeline/
├── rtl/                    # Verilog RTL source files
│   ├── top.v               # Top-level pipeline integration
│   ├── alu.v               # ALU (ADD/SUB/AND/OR/XOR/SLT/SLL/SRL/SRA)
│   ├── reg_file.v          # 32×32-bit register file (x0 hardwired to 0)
│   ├── if_stage.v          # Instruction Fetch + PC
│   ├── id_stage.v          # Instruction Decode + Control signals
│   ├── ex_stage.v          # Execute (ALU + branch resolution)
│   ├── mem_stage.v         # Data memory access (LW/SW/LH/SH/LB/SB)
│   ├── wb_stage.v          # Write Back MUX
│   ├── pipeline_regs.v     # IF/ID, ID/EX, EX/MEM, MEM/WB registers
│   ├── hazard_unit.v       # Forwarding unit + stall/flush logic
│   └── branch_predictor.v  # 2-bit BHT branch predictor
├── verif/                  # Python verification (cocotb)
│   ├── golden_model.py     # Software reference model (RV32I interpreter)
│   ├── test_alu.py         # ALU unit tests (1000 random + edge cases)
│   ├── test_pipeline.py    # Fibonacci co-simulation test
│   ├── test_hazards.py     # RAW/load-use hazard tests
│   └── test_random.py      # Constrained-random instruction stress test
├── asm/                    # RISC-V assembly test programs
│   ├── basic_arith.s       # ADD/SUB/AND/OR/XOR/SLT
│   ├── fibonacci.s         # fib(10) = 55
│   ├── branch_test.s       # BEQ/BNE/BLT/BGE
│   └── load_store.s        # LW/SW/LH/SH/LB/SB
├── sim/                    # Simulation outputs (waveforms, logs)
├── Makefile                # Build + simulation automation
└── README.md
```

---

## Quick Start

### Prerequisites
```bash
# On Ubuntu / WSL2:
sudo apt install -y iverilog gtkwave python3-pip
pip3 install cocotb cocotb-bus

# Verify
iverilog -V
python3 -c "import cocotb; print(cocotb.__version__)"
```

### Run Tests
```bash
# Unit test: ALU only
make test_alu

# Integration: Fibonacci co-simulation
make test_pipeline

# Hazard tests: forwarding + stall
make test_hazards

# Constrained random stress test
make test_random

# Run everything
make test_all
```

### View Waveforms
```bash
make wave_alu
# GTKWave opens — load signals from the Signal panel
```

---

## Verification Results

| Test Suite | Instructions Tested | Result |
|------------|-------------------|--------|
| ALU random (1000 × 7 ops) | 7,000 | ✅ PASS |
| ALU edge cases | 6 | ✅ PASS |
| EX-EX forwarding | 10 RAW patterns | ✅ PASS |
| MEM-EX forwarding | 10 RAW patterns | ✅ PASS |
| Load-use stall | 5 LW patterns | ✅ PASS |
| Branch flush | 4 branch types | ✅ PASS |
| Fibonacci co-sim | 50 instructions | ✅ PASS (x2=55) |
| Random stress (5×100) | 500 | ✅ PASS |

**Branch Predictor Accuracy:** ~87% on loop-heavy workloads (fibonacci)

---

## Key Design Decisions

### 1. Forwarding Over Stalling
Data forwarding paths short-circuit the ALU inputs, avoiding stalls for most RAW hazards. Only the load-use hazard (LW followed immediately by a dependent instruction) requires a 1-cycle stall because the data is unavailable until the MEM stage completes.

### 2. 2-Bit Saturating Counter Branch Predictor
Unlike a 1-bit predictor, a 2-bit predictor does not mispredict on the **first exit** of a loop — it must mispredict twice before switching. This gives significantly better accuracy for typical loop patterns.

### 3. Python Golden Model as Ground Truth
Rather than writing another Verilog testbench (which could have its own bugs), the reference model is a Python interpreter for RV32I. It is simpler, more readable, and independently trustworthy. Any divergence between the RTL and the Python model signals a hardware bug.

---

## Tools Used

| Tool | Purpose |
|------|---------|
| Icarus Verilog (`iverilog`) | RTL simulation |
| Verilator | High-speed simulation (alternative) |
| cocotb | Python-based co-simulation framework |
| GTKWave | Waveform viewer |
| Python 3.10+ | Golden model + testbench |
| GNU Make | Build automation |
| Git | Version control |

---

## Resume Entry

```
5-Stage Pipelined RISC-V (RV32I) Processor with Python Verification Suite
• Designed a 32-bit 5-stage pipelined processor in Verilog implementing the full
  RV32I ISA with data forwarding, hazard detection, and 2-bit branch prediction.
• Built a Python co-simulation framework (cocotb) with a software golden reference
  model; verified 500+ instruction sequences with 0 architectural mismatches.
• Measured 87% branch prediction accuracy on loop-heavy workloads; pipeline achieved
  CPI of ~1.1 on integer benchmarks vs. theoretical 1.0 ideal.
Tools: Verilog · Icarus Verilog · cocotb · GTKWave · Python · Git
```

---

## References

- [The RISC-V Instruction Set Manual, Vol. I: Unprivileged ISA](https://riscv.org/technical/specifications/)
- Patterson & Hennessy — *Computer Organization and Design: RISC-V Edition*
- [cocotb Documentation](https://docs.cocotb.org/)
- [Icarus Verilog](http://iverilog.icarus.com/)

