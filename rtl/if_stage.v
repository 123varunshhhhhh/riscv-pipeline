// ============================================================
// IF Stage — Instruction Fetch
// Fetches instruction from instruction memory at current PC
// ============================================================
module if_stage (
    input  wire        clk,
    input  wire        rst,
    input  wire        stall,          // Hold PC (load-use hazard)
    input  wire        pc_src,         // 1 = take branch/jump
    input  wire [31:0] branch_target,  // Branch/jump target address
    output reg  [31:0] pc,             // Current Program Counter
    output wire [31:0] instr,          // Fetched instruction
    output wire [31:0] pc_plus4        // PC + 4 (sequential next)
);

    // Instruction Memory — 256 words (1 KB), initialized from hex file
    // Run from project root so the path resolves correctly:
    //   iverilog ... && vvp sim/tb_top_out
    reg [31:0] imem [0:255];
    integer k;
    initial begin
        // Initialize all words to NOP (ADDI x0, x0, 0)
        for (k = 0; k < 256; k = k + 1)
            imem[k] = 32'h00000013;

        // Built-in benchmark: Fibonacci(10) calculation
        // Computes fib(10) = 55 (0x37) in register x2
        imem[0] = 32'h00000093; // 0x00: addi x1, x0, 0
        imem[1] = 32'h00100113; // 0x04: addi x2, x0, 1
        imem[2] = 32'h00900193; // 0x08: addi x3, x0, 9
        imem[3] = 32'h00208233; // 0x0C: add  x4, x1, x2  (loop)
        imem[4] = 32'h00010093; // 0x10: addi x1, x2, 0
        imem[5] = 32'h00020113; // 0x14: addi x2, x4, 0
        imem[6] = 32'hfff18193; // 0x18: addi x3, x3, -1
        imem[7] = 32'hfe0198e3; // 0x1C: bne  x3, x0, -16
        // 0x20..: NOPs

        // Load custom hex file if present (silently ignored if missing)
        $readmemh("asm/program.hex", imem);
        $readmemh("program.hex", imem);
    end

    assign pc_plus4 = pc + 32'd4;
    assign instr    = imem[pc[9:2]]; // Word-addressed (ignore bottom 2 bits)

    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'b0;
        else if (!stall)
            pc <= pc_src ? branch_target : pc_plus4;
    end

endmodule

