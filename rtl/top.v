// ============================================================
// TOP — 5-Stage Pipelined RISC-V (RV32I) Processor
// Connects: IF → ID → EX → MEM → WB with hazard handling
// ============================================================
`include "rtl/alu.v"
`include "rtl/reg_file.v"
`include "rtl/if_stage.v"
`include "rtl/id_stage.v"
`include "rtl/ex_stage.v"
`include "rtl/mem_stage.v"
`include "rtl/wb_stage.v"
`include "rtl/pipeline_regs.v"
`include "rtl/hazard_unit.v"
`include "rtl/branch_predictor.v"

module top (
    input wire clk,
    input wire rst
);

    // ----------------------------------------------------------------
    // IF Stage wires
    // ----------------------------------------------------------------
    wire [31:0] if_pc, if_instr, if_pc_plus4;
    wire        pc_src;
    wire [31:0] branch_target_final;

    // ----------------------------------------------------------------
    // IF/ID Pipeline Register wires
    // ----------------------------------------------------------------
    wire [31:0] id_pc, id_pc_plus4, id_instr;

    // ----------------------------------------------------------------
    // ID Stage wires
    // ----------------------------------------------------------------
    wire [4:0]  id_rs1, id_rs2, id_rd;
    wire [6:0]  id_opcode;
    wire [2:0]  id_funct3;
    wire [6:0]  id_funct7;
    wire        id_reg_write, id_mem_read, id_mem_write;
    wire        id_mem_to_reg, id_alu_src, id_branch, id_jump;
    wire [3:0]  id_alu_ctrl;
    wire [31:0] id_imm_ext;
    wire [31:0] id_rd1, id_rd2;

    // ----------------------------------------------------------------
    // ID/EX Pipeline Register wires
    // ----------------------------------------------------------------
    wire [31:0] ex_pc, ex_pc_plus4, ex_rd1, ex_rd2, ex_imm;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [3:0]  ex_alu_ctrl;
    wire [2:0]  ex_funct3;
    wire        ex_reg_write, ex_mem_read, ex_mem_write;
    wire        ex_mem_to_reg, ex_alu_src, ex_branch, ex_jump;

    // ----------------------------------------------------------------
    // EX Stage wires
    // ----------------------------------------------------------------
    wire [31:0] ex_alu_result, ex_alu_b_val;
    wire        ex_branch_taken;
    wire [31:0] ex_branch_target;
    wire [1:0]  fwd_a, fwd_b;

    // ----------------------------------------------------------------
    // EX/MEM Pipeline Register wires
    // ----------------------------------------------------------------
    wire [31:0] mem_pc_plus4, mem_alu_result, mem_wr_data, mem_branch_target;
    wire [4:0]  mem_rd;
    wire [2:0]  mem_funct3;
    wire        mem_reg_write, mem_mem_read, mem_mem_write;
    wire        mem_mem_to_reg, mem_branch_taken, mem_jump;

    // ----------------------------------------------------------------
    // MEM Stage wires
    // ----------------------------------------------------------------
    wire [31:0] mem_rd_data;

    // ----------------------------------------------------------------
    // MEM/WB Pipeline Register wires
    // ----------------------------------------------------------------
    wire [31:0] wb_pc_plus4, wb_alu_result, wb_mem_rd_data;
    wire [4:0]  wb_rd;
    wire        wb_reg_write, wb_mem_to_reg, wb_jump;

    // ----------------------------------------------------------------
    // WB Stage wires
    // ----------------------------------------------------------------
    wire [31:0] wb_data;
    // For JAL/JALR: write PC+4 (return address) to rd
    wire [31:0] wb_final = wb_jump ? wb_pc_plus4 : wb_data;

    // ----------------------------------------------------------------
    // Hazard signals
    // ----------------------------------------------------------------
    wire stall, if_id_flush_hz;

    // ----------------------------------------------------------------
    // Branch/Jump control: flush IF and ID/EX on taken branch
    // ----------------------------------------------------------------
    assign pc_src            = mem_branch_taken | mem_jump;
    assign branch_target_final = mem_branch_taken ? mem_branch_target : mem_alu_result; // JAL uses ALU
    wire   branch_flush      = pc_src; // Flush IF/ID and ID/EX on branch/jump

    // ----------------------------------------------------------------
    // Module Instantiations
    // ----------------------------------------------------------------

    if_stage u_if (
        .clk(clk), .rst(rst),
        .stall(stall), .pc_src(pc_src),
        .branch_target(branch_target_final),
        .pc(if_pc), .instr(if_instr), .pc_plus4(if_pc_plus4)
    );

    if_id_reg u_if_id (
        .clk(clk), .rst(rst),
        .stall(stall), .flush(branch_flush | if_id_flush_hz),
        .pc_in(if_pc), .pc_plus4_in(if_pc_plus4), .instr_in(if_instr),
        .pc_out(id_pc), .pc_plus4_out(id_pc_plus4), .instr_out(id_instr)
    );

    id_stage u_id (
        .instr(id_instr),
        .rd1_data(id_rd1), .rd2_data(id_rd2),
        .rs1(id_rs1), .rs2(id_rs2), .rd(id_rd),
        .opcode(id_opcode), .funct3(id_funct3), .funct7(id_funct7),
        .reg_write(id_reg_write), .mem_read(id_mem_read),
        .mem_write(id_mem_write), .mem_to_reg(id_mem_to_reg),
        .alu_src(id_alu_src), .branch(id_branch), .jump(id_jump),
        .alu_ctrl(id_alu_ctrl), .imm_ext(id_imm_ext)
    );

    reg_file u_rf (
        .clk(clk), .rst(rst),
        .rs1(id_rs1), .rs2(id_rs2),
        .rd1(id_rd1), .rd2(id_rd2),
        .rd(wb_rd), .wr_data(wb_final), .reg_write(wb_reg_write)
    );

    id_ex_reg u_id_ex (
        .clk(clk), .rst(rst), .flush(branch_flush | stall),
        .pc_in(id_pc), .pc_plus4_in(id_pc_plus4),
        .rd1_in(id_rd1), .rd2_in(id_rd2), .imm_in(id_imm_ext),
        .rs1_in(id_rs1), .rs2_in(id_rs2), .rd_in(id_rd),
        .alu_ctrl_in(id_alu_ctrl), .funct3_in(id_funct3),
        .reg_write_in(id_reg_write), .mem_read_in(id_mem_read),
        .mem_write_in(id_mem_write), .mem_to_reg_in(id_mem_to_reg),
        .alu_src_in(id_alu_src), .branch_in(id_branch), .jump_in(id_jump),
        .pc_out(ex_pc), .pc_plus4_out(ex_pc_plus4),
        .rd1_out(ex_rd1), .rd2_out(ex_rd2), .imm_out(ex_imm),
        .rs1_out(ex_rs1), .rs2_out(ex_rs2), .rd_out(ex_rd),
        .alu_ctrl_out(ex_alu_ctrl), .funct3_out(ex_funct3),
        .reg_write_out(ex_reg_write), .mem_read_out(ex_mem_read),
        .mem_write_out(ex_mem_write), .mem_to_reg_out(ex_mem_to_reg),
        .alu_src_out(ex_alu_src), .branch_out(ex_branch), .jump_out(ex_jump)
    );

    hazard_unit u_haz (
        .id_ex_rs1(ex_rs1), .id_ex_rs2(ex_rs2),
        .ex_mem_rd(mem_rd), .ex_mem_reg_write(mem_reg_write),
        .ex_mem_mem_read(mem_mem_read),
        .mem_wb_rd(wb_rd), .mem_wb_reg_write(wb_reg_write),
        .fwd_a(fwd_a), .fwd_b(fwd_b),
        .stall(stall), .if_id_flush(if_id_flush_hz)
    );

    ex_stage u_ex (
        .pc(ex_pc), .rd1(ex_rd1), .rd2(ex_rd2), .imm_ext(ex_imm),
        .alu_ctrl(ex_alu_ctrl), .alu_src(ex_alu_src),
        .branch(ex_branch), .funct3(ex_funct3),
        .fwd_a_data(mem_alu_result), .fwd_b_data(wb_final),
        .fwd_a_sel(fwd_a), .fwd_b_sel(fwd_b),
        .alu_result(ex_alu_result), .alu_b_val(ex_alu_b_val),
        .branch_taken(ex_branch_taken), .branch_target(ex_branch_target)
    );

    ex_mem_reg u_ex_mem (
        .clk(clk), .rst(rst), .flush(1'b0),
        .pc_plus4_in(ex_pc_plus4), .alu_result_in(ex_alu_result),
        .wr_data_in(ex_alu_b_val), .branch_target_in(ex_branch_target),
        .rd_in(ex_rd), .funct3_in(ex_funct3),
        .reg_write_in(ex_reg_write), .mem_read_in(ex_mem_read),
        .mem_write_in(ex_mem_write), .mem_to_reg_in(ex_mem_to_reg),
        .branch_taken_in(ex_branch_taken), .jump_in(ex_jump),
        .pc_plus4_out(mem_pc_plus4), .alu_result_out(mem_alu_result),
        .wr_data_out(mem_wr_data), .branch_target_out(mem_branch_target),
        .rd_out(mem_rd), .funct3_out(mem_funct3),
        .reg_write_out(mem_reg_write), .mem_read_out(mem_mem_read),
        .mem_write_out(mem_mem_write), .mem_to_reg_out(mem_mem_to_reg),
        .branch_taken_out(mem_branch_taken), .jump_out(mem_jump)
    );

    mem_stage u_mem (
        .clk(clk), .rst(rst),
        .alu_result(mem_alu_result), .wr_data(mem_wr_data),
        .mem_read(mem_mem_read), .mem_write(mem_mem_write),
        .funct3(mem_funct3), .rd_data(mem_rd_data)
    );

    mem_wb_reg u_mem_wb (
        .clk(clk), .rst(rst),
        .pc_plus4_in(mem_pc_plus4), .alu_result_in(mem_alu_result),
        .mem_rd_data_in(mem_rd_data), .rd_in(mem_rd),
        .reg_write_in(mem_reg_write), .mem_to_reg_in(mem_mem_to_reg),
        .jump_in(mem_jump),
        .pc_plus4_out(wb_pc_plus4), .alu_result_out(wb_alu_result),
        .mem_rd_data_out(wb_mem_rd_data), .rd_out(wb_rd),
        .reg_write_out(wb_reg_write), .mem_to_reg_out(wb_mem_to_reg),
        .jump_out(wb_jump)
    );

    wb_stage u_wb (
        .alu_result(wb_alu_result), .mem_rd_data(wb_mem_rd_data),
        .mem_to_reg(wb_mem_to_reg), .wb_data(wb_data)
    );

endmodule

