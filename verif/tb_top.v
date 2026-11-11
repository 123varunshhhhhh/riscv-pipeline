// ============================================================
// tb_top.v — Standalone Verilog Testbench for Top-Level Pipeline
// No Python/cocotb needed — run directly with Icarus Verilog
//
// Usage:
//   iverilog -g2012 -o sim/tb_top_out rtl/*.v verif/tb_top.v
//   vvp sim/tb_top_out
//   gtkwave sim/waveforms/tb_top.vcd
// ============================================================
`timescale 1ns/1ps

module tb_top;

    // ----------------------------------------------------------------
    // Clock + Reset
    // ----------------------------------------------------------------
    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk;   // 10 ns period → 100 MHz

    // ----------------------------------------------------------------
    // DUT instantiation
    // ----------------------------------------------------------------
    top dut (.clk(clk), .rst(rst));

    // ----------------------------------------------------------------
    // Waveform dump
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("sim/waveforms/tb_top.vcd");
        $dumpvars(0, tb_top);
    end

    // ----------------------------------------------------------------
    // Reset sequence
    // ----------------------------------------------------------------
    initial begin
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        $display("[%0t] Reset released — pipeline starting", $time);
    end

    // ----------------------------------------------------------------
    // Monitor: print register writes as they happen
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst && dut.u_rf.reg_write && dut.u_rf.rd != 0)
            $display("[%0t] WB: x%0d <= 0x%08h",
                     $time, dut.u_rf.rd, dut.u_rf.wr_data);
    end

    // ----------------------------------------------------------------
    // Monitor: print PC each cycle
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst)
            $display("[%0t] PC = 0x%08h  INSTR = 0x%08h",
                     $time, dut.u_if.pc, dut.id_instr);
    end

    // ----------------------------------------------------------------
    // Self-checking: Fibonacci(10) = 55 expected in x2
    // Program runs for 100 cycles then we check
    // ----------------------------------------------------------------
    integer cycle_count = 0;
    integer pass_count  = 0;
    integer fail_count  = 0;

    always @(posedge clk) if (!rst) cycle_count <= cycle_count + 1;

    task check_reg;
        input integer reg_num;
        input [31:0]  expected;
        input [63:0]  test_name;
        reg [31:0] actual;
        begin
            actual = dut.u_rf.regs[reg_num];
            if (actual === expected) begin
                $display("  PASS | x%0d = 0x%08h (%0d)  — %s",
                         reg_num, actual, actual, test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | x%0d = 0x%08h, expected 0x%08h  — %s",
                         reg_num, actual, expected, test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // Wait for pipeline to finish running fibonacci program
        wait(rst == 0);
        repeat(120) @(posedge clk);

        $display("\n========================================");
        $display("  RISC-V Pipeline — Self-Check Results");
        $display("  After %0d cycles", cycle_count);
        $display("========================================");

        // --- Fibonacci checks ---
        $display("\n[Fibonacci(10) Program]");
        check_reg(2, 32'd55, "fib(10)=55 in x2");
        check_reg(3, 32'd0,  "loop counter x3=0");

        // --- Basic arithmetic checks (from basic_arith program) ---
        // Uncomment after loading basic_arith.hex instead of fibonacci.hex
        // check_reg(3,  32'd17, "ADD  10+7=17  → x3");
        // check_reg(4,  32'd3,  "SUB  10-7=3   → x4");
        // check_reg(5,  32'd2,  "AND  10&7=2   → x5");
        // check_reg(6,  32'd15, "OR   10|7=15  → x6");
        // check_reg(7,  32'd13, "XOR  10^7=13  → x7");
        // check_reg(8,  32'd1,  "SLT  7<10=1   → x8");
        // check_reg(9,  32'd0,  "SLT  10<7=0   → x9");
        // check_reg(10, 32'd12, "ADDI 17-5=12  → x10");

        $display("\n========================================");
        $display("  PASSED: %0d / %0d checks", pass_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("  ✅ ALL TESTS PASSED");
        else
            $display("  ❌ %0d TEST(S) FAILED", fail_count);
        $display("========================================\n");

        $finish;
    end

    // ----------------------------------------------------------------
    // Timeout guard — abort if simulation hangs
    // ----------------------------------------------------------------
    initial begin
        #20000;
        $display("❌ TIMEOUT: simulation exceeded 20000 ns");
        $finish;
    end

endmodule

