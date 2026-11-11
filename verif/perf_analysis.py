"""
perf_analysis.py — Pipeline Performance Analyzer
Runs programs on the golden model and measures:
  - CPI (Cycles Per Instruction)
  - Stall cycles (load-use hazards)
  - Branch mispredictions + predictor accuracy
  - Pipeline efficiency

Usage: python3 verif/perf_analysis.py
No simulator needed — purely Python.
"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from golden_model import RV32IGoldenModel

# ----------------------------------------------------------------
# Mini assembler
# ----------------------------------------------------------------
def addi(rd,rs1,imm): return (imm&0xFFF)<<20|rs1<<15|rd<<7|0x13
def add(rd,rs1,rs2):  return rs2<<20|rs1<<15|rd<<7|0x33
def sub(rd,rs1,rs2):  return 0x20<<25|rs2<<20|rs1<<15|rd<<7|0x33
def and_(rd,rs1,rs2): return rs2<<20|rs1<<15|7<<12|rd<<7|0x33
def or_(rd,rs1,rs2):  return rs2<<20|rs1<<15|6<<12|rd<<7|0x33
def sw(rs2,rs1,imm):  return ((imm>>5)&0x7F)<<25|rs2<<20|rs1<<15|2<<12|(imm&0x1F)<<7|0x23
def lw(rd,rs1,imm):   return (imm&0xFFF)<<20|rs1<<15|2<<12|rd<<7|0x03
def beq(rs1,rs2,off):
    o=off&0x1FFF
    return ((o>>12)&1)<<31|((o>>5)&0x3F)<<25|rs2<<20|rs1<<15|((o>>1)&0xF)<<8|((o>>11)&1)<<7|0x63
def bne(rs1,rs2,off):
    o=off&0x1FFF
    return ((o>>12)&1)<<31|((o>>5)&0x3F)<<25|rs2<<20|rs1<<15|1<<12|((o>>1)&0xF)<<8|((o>>11)&1)<<7|0x63
def nop(): return addi(0,0,0)

# ----------------------------------------------------------------
# Pipeline timing model — counts stalls and flushes analytically
# ----------------------------------------------------------------
class PipelineModel:
    """
    Simulates 5-stage pipeline timing on top of the ISA model.
    Counts:
      - load_use_stalls  : 1 stall per LW followed immediately by dependent instr
      - branch_flushes   : 2 wasted slots per taken branch (assume resolve at EX)
      - total_cycles     : wall-clock cycles to execute N instructions
      - CPI              : total_cycles / N
    """
    LOAD_OPCODE   = 0x03
    BRANCH_OPCODE = 0x63
    JUMP_OPCODES  = {0x6F, 0x67}

    def __init__(self):
        self.reset()

    def reset(self):
        self.instr_count      = 0
        self.load_use_stalls  = 0
        self.branch_flushes   = 0
        self.branch_total     = 0
        self.branch_taken     = 0
        self.branch_misses    = 0   # 2-bit predictor simulation
        self.prev_instr       = None
        self.prev_rd          = 0
        self.bht              = [0b01] * 64  # 64-entry 2-bit BHT, init weakly-NT

    def _bht_idx(self, pc):
        return (pc >> 2) & 0x3F

    def _predict(self, pc):
        return self.bht[self._bht_idx(pc)] >= 2  # MSB

    def _update_bht(self, pc, taken):
        idx = self._bht_idx(pc)
        if taken and self.bht[idx] < 3:
            self.bht[idx] += 1
        elif not taken and self.bht[idx] > 0:
            self.bht[idx] -= 1

    def analyze(self, program: list) -> dict:
        """Run the program through the timing model. Returns stats dict."""
        self.reset()
        model  = RV32IGoldenModel()
        pc_idx = 0
        limit  = 0

        while pc_idx < len(program) and limit < 100_000:
            instr    = program[pc_idx]
            opcode   = instr & 0x7F
            rd       = (instr >> 7)  & 0x1F
            rs1      = (instr >> 15) & 0x1F
            rs2      = (instr >> 20) & 0x1F
            funct3   = (instr >> 12) & 0x7

            # --- Load-use stall detection ---
            if (self.prev_instr is not None and
                    (self.prev_instr & 0x7F) == self.LOAD_OPCODE and
                    self.prev_rd != 0 and
                    (self.prev_rd == rs1 or self.prev_rd == rs2)):
                self.load_use_stalls += 1

            # --- Branch prediction ---
            if opcode == self.BRANCH_OPCODE:
                self.branch_total += 1
                predicted = self._predict(pc_idx * 4)
                # Execute to know actual outcome
                old_pc = model.pc
                model.execute(instr)
                actual_taken = (model.pc != old_pc + 4)
                if actual_taken:
                    self.branch_taken += 1
                if predicted != actual_taken:
                    self.branch_misses += 1
                    self.branch_flushes += 2  # 2-cycle penalty per mispredict
                self._update_bht(pc_idx * 4, actual_taken)
                pc_idx = model.pc // 4
            elif opcode in self.JUMP_OPCODES:
                self.branch_flushes += 2  # Always-taken jumps: 2-cycle flush
                model.execute(instr)
                pc_idx = model.pc // 4
            else:
                model.execute(instr)
                pc_idx += 1

            self.prev_instr = instr
            self.prev_rd    = rd if opcode not in {0x23, self.BRANCH_OPCODE} else 0
            self.instr_count += 1
            limit += 1

        total_cycles = self.instr_count + self.load_use_stalls + self.branch_flushes + 4  # +4 drain
        cpi = total_cycles / max(self.instr_count, 1)
        bp_acc = (1 - self.branch_misses / max(self.branch_total, 1)) * 100

        return {
            "instructions"     : self.instr_count,
            "total_cycles"     : total_cycles,
            "cpi"              : cpi,
            "load_use_stalls"  : self.load_use_stalls,
            "branch_flushes"   : self.branch_flushes,
            "branch_total"     : self.branch_total,
            "branch_taken"     : self.branch_taken,
            "branch_misses"    : self.branch_misses,
            "bp_accuracy_pct"  : bp_acc,
            "pipeline_eff_pct" : (self.instr_count / max(total_cycles, 1)) * 100,
        }

# ----------------------------------------------------------------
# Benchmark programs
# ----------------------------------------------------------------
BENCHMARKS = {
    "fibonacci(10)": [
        addi(1,0,0), addi(2,0,1), addi(3,0,9),   # counter=9 → fib(10)=55
        add(4,1,2), addi(1,2,0), addi(2,4,0), addi(3,3,-1),
        bne(3,0,-16), nop(), nop(),
    ],
    "sum_1_to_100": [
        addi(1,0,0), addi(2,0,1), addi(3,0,100),
        add(1,1,2), addi(2,2,1), bne(2,3,-8), nop(), nop(),
    ],
    "bubble_sort_8": lambda: _bubble_sort_prog(8),
    "arith_no_branch": [
        addi(1,0,10), addi(2,0,20), addi(3,0,30),
        add(4,1,2), add(5,2,3), add(6,4,5),
        sub(7,6,1), and_(8,6,7), or_(9,7,8),
        sub(10,9,3), add(11,10,1), sub(12,11,2),
        nop(), nop(), nop(), nop(),
    ],
}

def _bubble_sort_prog(n):
    """Generate bubble sort for n elements pre-loaded at addr 0x100"""
    # Simplified: n iterations of compare-swap pairs using addi/add/sub
    prog = [addi(1,0,100)]  # base address
    for i in range(n):
        prog += [
            lw(2,1,i*4),     # a[i]
            lw(3,1,(i+1)*4) if i < n-1 else nop(),  # a[i+1]
            sub(4,2,3),      # a[i] - a[i+1]
            nop(), nop(),    # pad
        ]
    prog += [nop()] * 8
    return prog

BENCHMARKS["bubble_sort_8"] = _bubble_sort_prog(8)

# ----------------------------------------------------------------
# Pretty printer
# ----------------------------------------------------------------
def print_report(name, stats):
    w = 44
    print(f"\n{'─'*w}")
    print(f"  Benchmark: {name}")
    print(f"{'─'*w}")
    print(f"  Instructions executed : {stats['instructions']:>8,}")
    print(f"  Total cycles          : {stats['total_cycles']:>8,}")
    print(f"  CPI                   : {stats['cpi']:>8.3f}  (ideal = 1.000)")
    print(f"  Pipeline efficiency   : {stats['pipeline_eff_pct']:>7.1f}%")
    print(f"{'─'*w}")
    print(f"  Load-use stalls       : {stats['load_use_stalls']:>8,}")
    print(f"  Branch/jump flushes   : {stats['branch_flushes']:>8,}")
    print(f"{'─'*w}")
    if stats['branch_total'] > 0:
        print(f"  Branches total        : {stats['branch_total']:>8,}")
        print(f"  Branches taken        : {stats['branch_taken']:>8,}")
        print(f"  Mispredictions        : {stats['branch_misses']:>8,}")
        print(f"  Predictor accuracy    : {stats['bp_accuracy_pct']:>7.1f}%")
    else:
        print(f"  Branches              :        none")
    print(f"{'─'*w}")

# ----------------------------------------------------------------
# Main
# ----------------------------------------------------------------
if __name__ == "__main__":
    print("=" * 44)
    print("  RISC-V 5-Stage Pipeline — Perf Report")
    print("  2-bit BHT Branch Predictor (64 entries)")
    print("=" * 44)

    pm = PipelineModel()
    all_stats = {}

    for name, prog in BENCHMARKS.items():
        stats = pm.analyze(prog)
        all_stats[name] = stats
        print_report(name, stats)

    # --- Summary table ---
    print(f"\n{'='*44}")
    print(f"  {'Benchmark':<22} {'CPI':>6}  {'BP Acc':>7}")
    print(f"  {'─'*22} {'─'*6}  {'─'*7}")
    for name, s in all_stats.items():
        bp = f"{s['bp_accuracy_pct']:.1f}%" if s['branch_total'] > 0 else "  N/A "
        print(f"  {name:<22} {s['cpi']:>6.3f}  {bp:>7}")
    print(f"{'='*44}")

    avg_cpi = sum(s['cpi'] for s in all_stats.values()) / len(all_stats)
    avg_bp  = sum(s['bp_accuracy_pct'] for s in all_stats.values()
                  if s['branch_total'] > 0)
    bp_cnt  = sum(1 for s in all_stats.values() if s['branch_total'] > 0)
    print(f"\n  Average CPI           : {avg_cpi:.3f}")
    print(f"  Avg Branch Predictor  : {avg_bp/max(bp_cnt,1):.1f}%")
    print(f"\n  → Use these numbers in your RESUME ENTRY ⬆")
    print(f"{'='*44}\n")
