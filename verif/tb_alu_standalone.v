// ============================================================
// tb_alu_standalone.v — Standalone ALU testbench (no cocotb)
// Run with: iverilog -g2012 -o sim/alu_tb rtl/alu.v verif/tb_alu_standalone.v
//           vvp sim/alu_tb
// ============================================================
`timescale 1ns/1ps

module tb_alu_standalone;

    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero;

    integer pass = 0, fail = 0;

    alu dut (.a(a), .b(b), .alu_ctrl(alu_ctrl), .result(result), .zero(zero));

    initial begin
        $dumpfile("sim/waveforms/alu.vcd");
        $dumpvars(0, tb_alu_standalone);
    end

    task test_op;
        input [3:0]   ctrl;
        input [31:0]  in_a, in_b, expected;
        input [127:0] name;
        begin
            a = in_a; b = in_b; alu_ctrl = ctrl;
            #2;
            if (result === expected) begin
                $display("  PASS | %-6s a=%08h b=%08h → %08h", name, in_a, in_b, result);
                pass = pass + 1;
            end else begin
                $display("  FAIL | %-6s a=%08h b=%08h → got %08h, expected %08h",
                         name, in_a, in_b, result, expected);
                fail = fail + 1;
            end
        end
    endtask

    integer i;
    reg [31:0] rand_a, rand_b;

    initial begin
        $display("\n=== ALU Standalone Testbench ===\n");
        $display("[Directed Tests]");

        // ADD
        test_op(4'b0000, 32'd10,        32'd7,         32'd17,         "ADD");
        test_op(4'b0000, 32'hFFFFFFFF,  32'd1,         32'd0,          "ADD_OVF");
        test_op(4'b0000, 32'd0,         32'd0,         32'd0,          "ADD_ZERO");

        // SUB
        test_op(4'b0001, 32'd10,        32'd7,         32'd3,          "SUB");
        test_op(4'b0001, 32'd0,         32'd1,         32'hFFFFFFFF,   "SUB_UDF");

        // AND
        test_op(4'b0010, 32'hFF00FF00,  32'h0F0F0F0F,  32'h0F000F00,   "AND");
        test_op(4'b0010, 32'hFFFFFFFF,  32'd0,         32'd0,          "AND_ZERO");

        // OR
        test_op(4'b0011, 32'hFF000000,  32'h00FF0000,  32'hFFFF0000,   "OR");

        // XOR
        test_op(4'b0100, 32'hFFFFFFFF,  32'hFFFFFFFF,  32'd0,          "XOR_SELF");
        test_op(4'b0100, 32'hAAAAAAAA,  32'h55555555,  32'hFFFFFFFF,   "XOR_ALT");

        // SLT (signed)
        test_op(4'b0101, 32'hFFFFFFFF,  32'd1,         32'd1,          "SLT_NEG");   // -1 < 1
        test_op(4'b0101, 32'd5,         32'd3,         32'd0,          "SLT_GTE");

        // SLL
        test_op(4'b0111, 32'd1,         32'd4,         32'd16,         "SLL");
        test_op(4'b0111, 32'd1,         32'd31,        32'h80000000,   "SLL_MAX");

        // SRL
        test_op(4'b1000, 32'h80000000,  32'd1,         32'h40000000,   "SRL");

        // SRA (arithmetic, sign-extend)
        test_op(4'b1001, 32'h80000000,  32'd4,         32'hF8000000,   "SRA_NEG");

        // Zero flag
        a = 32'd5; b = 32'd5; alu_ctrl = 4'b0001; #2; // SUB 5-5=0
        if (zero === 1'b1) begin
            $display("  PASS | ZERO_FLAG set for 5-5=0"); pass = pass + 1;
        end else begin
            $display("  FAIL | ZERO_FLAG should be 1 for 5-5=0"); fail = fail + 1;
        end

        $display("\n[Random Tests — 200 iterations]");
        for (i = 0; i < 200; i = i + 1) begin
            rand_a = $random;
            rand_b = $random;
            // Test ADD
            a = rand_a; b = rand_b; alu_ctrl = 4'b0000; #2;
            if (result === (rand_a + rand_b)) pass = pass + 1;
            else begin
                $display("  FAIL | RAND ADD %08h+%08h=%08h exp %08h",
                         rand_a, rand_b, result, rand_a+rand_b);
                fail = fail + 1;
            end
            // Test AND
            a = rand_a; b = rand_b; alu_ctrl = 4'b0010; #2;
            if (result === (rand_a & rand_b)) pass = pass + 1;
            else begin
                $display("  FAIL | RAND AND"); fail = fail + 1;
            end
        end

        $display("\n================================");
        $display("PASSED: %0d / %0d", pass, pass + fail);
        if (fail == 0) $display("✅ ALL ALU TESTS PASSED");
        else           $display("❌ %0d FAILURES", fail);
        $display("================================\n");
        $finish;
    end

endmodule

