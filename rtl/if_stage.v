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
    initial begin
        $readmemh("asm/program.hex", imem);
        // Fill rest with NOPs (0x00000013) so pipeline never fetches garbage
        // (Icarus leaves uninitialized entries as X; NOPs are safer)
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

