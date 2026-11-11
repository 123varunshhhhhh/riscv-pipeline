// ============================================================
// EX Stage — Execute (ALU + Branch Resolution)
// ============================================================
module ex_stage (
    input  wire [31:0] pc,
    input  wire [31:0] rd1,        // Register value RS1
    input  wire [31:0] rd2,        // Register value RS2
    input  wire [31:0] imm_ext,    // Sign-extended immediate
    input  wire [3:0]  alu_ctrl,
    input  wire        alu_src,    // 0=rd2, 1=immediate
    input  wire        branch,
    input  wire [2:0]  funct3,
    // Forwarded values from later stages
    input  wire [31:0] fwd_a_data,
    input  wire [31:0] fwd_b_data,
    input  wire [1:0]  fwd_a_sel,  // 00=reg, 01=WB fwd, 10=MEM fwd
    input  wire [1:0]  fwd_b_sel,
    // Outputs
    output wire [31:0] alu_result,
    output wire [31:0] alu_b_val,  // RS2 value (for store data)
    output wire        branch_taken,
    output wire [31:0] branch_target
);

    // Forwarding MUXes
    wire [31:0] op_a = (fwd_a_sel == 2'b10) ? fwd_a_data :
                       (fwd_a_sel == 2'b01) ? fwd_b_data : rd1;
    wire [31:0] op_b_reg = (fwd_b_sel == 2'b10) ? fwd_a_data :
                           (fwd_b_sel == 2'b01) ? fwd_b_data : rd2;
    wire [31:0] op_b = alu_src ? imm_ext : op_b_reg;

    assign alu_b_val    = op_b_reg;
    assign branch_target = pc + imm_ext;

    // Branch outcome based on funct3
    wire zero;
    alu u_alu (.a(op_a), .b(op_b), .alu_ctrl(alu_ctrl),
               .result(alu_result), .zero(zero));

    wire lt  = $signed(op_a) < $signed(op_b);
    wire ltu = op_a < op_b;

    assign branch_taken = branch & (
        (funct3 == 3'b000 &&  zero) ||   // BEQ
        (funct3 == 3'b001 && !zero) ||   // BNE
        (funct3 == 3'b100 &&  lt)   ||   // BLT
        (funct3 == 3'b101 && !lt)   ||   // BGE
        (funct3 == 3'b110 &&  ltu)  ||   // BLTU
        (funct3 == 3'b111 && !ltu)       // BGEU
    );

endmodule

