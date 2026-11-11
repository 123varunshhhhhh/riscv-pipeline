# ============================================================
# Makefile — Build + Simulate RISC-V Pipeline
# Usage:
#   make sim_alu        — Simulate ALU testbench with Icarus
#   make test_alu       — Run ALU cocotb tests
#   make test_pipeline  — Run pipeline co-simulation test
#   make test_hazards   — Run hazard unit tests
#   make test_random    — Run constrained-random tests
#   make test_all       — Run all cocotb tests
#   make wave_alu       — Open GTKWave for ALU waveform
#   make clean          — Remove all generated files
# ============================================================

SIM        ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES      ?= 1

# ---- RTL Sources -----------------------------------------------
RTL_SRCS = rtl/alu.v \
           rtl/reg_file.v \
           rtl/if_stage.v \
           rtl/id_stage.v \
           rtl/ex_stage.v \
           rtl/mem_stage.v \
           rtl/wb_stage.v \
           rtl/pipeline_regs.v \
           rtl/hazard_unit.v \
           rtl/branch_predictor.v \
           rtl/top.v

# ---- cocotb ALU test -------------------------------------------
test_alu: TOPLEVEL = alu
test_alu: MODULE   = verif.test_alu
test_alu: rtl/alu.v
	rm -rf sim_build/alu
	$(MAKE) -f $(shell cocotb-config --makefiles)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="rtl/alu.v" \
		TOPLEVEL=$(TOPLEVEL) MODULE=$(MODULE) \
		SIM_BUILD=sim_build/alu \
		WAVES=$(WAVES)

# ---- cocotb pipeline test --------------------------------------
test_pipeline: TOPLEVEL = top
test_pipeline: MODULE   = verif.test_pipeline
test_pipeline: $(RTL_SRCS)
	rm -rf sim_build/pipeline
	mkdir -p sim_build/pipeline/asm && cp -r asm/* sim_build/pipeline/asm/ 2>/dev/null || true
	$(MAKE) -f $(shell cocotb-config --makefiles)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(RTL_SRCS)" \
		TOPLEVEL=$(TOPLEVEL) MODULE=$(MODULE) \
		SIM_BUILD=sim_build/pipeline \
		WAVES=$(WAVES)

# ---- cocotb hazard test ----------------------------------------
test_hazards: TOPLEVEL = top
test_hazards: MODULE   = verif.test_hazards
test_hazards: $(RTL_SRCS)
	rm -rf sim_build/hazards
	mkdir -p sim_build/hazards/asm && cp -r asm/* sim_build/hazards/asm/ 2>/dev/null || true
	$(MAKE) -f $(shell cocotb-config --makefiles)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(RTL_SRCS)" \
		TOPLEVEL=$(TOPLEVEL) MODULE=$(MODULE) \
		SIM_BUILD=sim_build/hazards \
		WAVES=$(WAVES)

# ---- cocotb random test ----------------------------------------
test_random: TOPLEVEL = top
test_random: MODULE   = verif.test_random
test_random: $(RTL_SRCS)
	rm -rf sim_build/random
	mkdir -p sim_build/random/asm && cp -r asm/* sim_build/random/asm/ 2>/dev/null || true
	$(MAKE) -f $(shell cocotb-config --makefiles)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="$(RTL_SRCS)" \
		TOPLEVEL=$(TOPLEVEL) MODULE=$(MODULE) \
		SIM_BUILD=sim_build/random \
		WAVES=$(WAVES)

# ---- Icarus standalone ALU simulation --------------------------
sim_alu: rtl/alu.v
	mkdir -p sim/waveforms
	iverilog -g2012 -o sim/alu_tb_out rtl/alu.v verif/tb_alu_standalone.v
	vvp sim/alu_tb_out
	@echo "Waveform: alu.vcd — open with: gtkwave alu.vcd"

# ---- Icarus standalone Pipeline simulation ---------------------
sim_pipeline: $(RTL_SRCS)
	mkdir -p sim/waveforms
	iverilog -g2012 -o sim/tb_top_out $(RTL_SRCS) verif/tb_top.v
	vvp sim/tb_top_out
	@echo "Waveform: tb_top.vcd — open with: gtkwave tb_top.vcd"
	@echo "Waveform: sim/waveforms/alu.vcd — open with: gtkwave sim/waveforms/alu.vcd"

# ---- cocotb branch predictor test ------------------------------
test_branch_predictor: TOPLEVEL = branch_predictor
test_branch_predictor: MODULE   = verif.test_branch_predictor
test_branch_predictor: rtl/branch_predictor.v
	rm -rf sim_build/branch_predictor
	$(MAKE) -f $(shell cocotb-config --makefiles)/Makefile.sim \
		SIM=$(SIM) TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
		VERILOG_SOURCES="rtl/branch_predictor.v" \
		TOPLEVEL=$(TOPLEVEL) MODULE=$(MODULE) \
		SIM_BUILD=sim_build/branch_predictor \
		WAVES=$(WAVES)

# ---- All tests -------------------------------------------------
test_all: test_alu test_pipeline test_hazards test_random test_branch_predictor
	@echo "============================================"
	@echo "✅ All test suites completed"
	@echo "============================================"

# ---- GTKWave ---------------------------------------------------
wave_alu:
	gtkwave sim/waveforms/dump.vcd &

# ---- Assemble .s to .hex (requires RISC-V toolchain) -----------
%.hex: %.s
	riscv32-unknown-elf-as -o $*.o $<
	riscv32-unknown-elf-ld -Ttext 0x0 -o $*.elf $*.o
	riscv32-unknown-elf-objcopy -O verilog $*.elf $@
	@echo "Generated $@"

# ---- Clean -----------------------------------------------------
clean:
	rm -rf sim/__pycache__ __pycache__ results.xml sim_build
	rm -rf sim/waveforms/*.vcd *.vcd *.o *.elf
	rm -rf sim/alu_tb_out sim/tb_top_out
	find . -name "*.pyc" -delete

.PHONY: test_alu test_pipeline test_hazards test_random test_branch_predictor test_all sim_alu sim_pipeline wave_alu clean

