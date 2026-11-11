// ============================================================
// Pipeline Registers — IF/ID, ID/EX, EX/MEM, MEM/WB
// Each register supports flush (bubble insertion) and stall
// ============================================================

// ---- IF/ID Register ----------------------------------------
module if_id_reg (
    input  wire        clk, rst,
    input  wire        stall,  // Hold value (do not update)
    input  wire        flush,  // Insert NOP bubble
    input  wire [31:0] pc_in,
    input  wire [31:0] pc_plus4_in,
    input  wire [31:0] instr_in,
    output reg  [31:0] pc_out,
    output reg  [31:0] pc_plus4_out,
    output reg  [31:0] instr_out
);
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            pc_out       <= 32'b0;
            pc_plus4_out <= 32'b0;
            instr_out    <= 32'h00000013; // NOP
        end else if (!stall) begin
            pc_out       <= pc_in;
            pc_plus4_out <= pc_plus4_in;
            instr_out    <= instr_in;
        end
    end
endmodule

// ---- ID/EX Register ----------------------------------------
module id_ex_reg (
    input  wire        clk, rst, flush,
    input  wire [31:0] pc_in, pc_plus4_in,
    input  wire [31:0] rd1_in, rd2_in, imm_in,
    input  wire [4:0]  rs1_in, rs2_in, rd_in,
    input  wire [3:0]  alu_ctrl_in,
    input  wire [2:0]  funct3_in,
    input  wire        reg_write_in, mem_read_in, mem_write_in,
    input  wire        mem_to_reg_in, alu_src_in, branch_in, jump_in,
    output reg  [31:0] pc_out, pc_plus4_out,
    output reg  [31:0] rd1_out, rd2_out, imm_out,
    output reg  [4:0]  rs1_out, rs2_out, rd_out,
    output reg  [3:0]  alu_ctrl_out,
    output reg  [2:0]  funct3_out,
    output reg         reg_write_out, mem_read_out, mem_write_out,
    output reg         mem_to_reg_out, alu_src_out, branch_out, jump_out
);
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            pc_out <= 0; pc_plus4_out <= 0;
            rd1_out <= 0; rd2_out <= 0; imm_out <= 0;
            rs1_out <= 0; rs2_out <= 0; rd_out <= 0;
            alu_ctrl_out <= 0; funct3_out <= 0;
            reg_write_out <= 0; mem_read_out <= 0; mem_write_out <= 0;
            mem_to_reg_out <= 0; alu_src_out <= 0;
            branch_out <= 0; jump_out <= 0;
        end else begin
            pc_out <= pc_in; pc_plus4_out <= pc_plus4_in;
            rd1_out <= rd1_in; rd2_out <= rd2_in; imm_out <= imm_in;
            rs1_out <= rs1_in; rs2_out <= rs2_in; rd_out <= rd_in;
            alu_ctrl_out <= alu_ctrl_in; funct3_out <= funct3_in;
            reg_write_out <= reg_write_in; mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in; mem_to_reg_out <= mem_to_reg_in;
            alu_src_out <= alu_src_in; branch_out <= branch_in;
            jump_out <= jump_in;
        end
    end
endmodule

// ---- EX/MEM Register ----------------------------------------
module ex_mem_reg (
    input  wire        clk, rst, flush,
    input  wire [31:0] pc_plus4_in, alu_result_in, wr_data_in, branch_target_in,
    input  wire [4:0]  rd_in,
    input  wire [2:0]  funct3_in,
    input  wire        reg_write_in, mem_read_in, mem_write_in,
    input  wire        mem_to_reg_in, branch_taken_in, jump_in,
    output reg  [31:0] pc_plus4_out, alu_result_out, wr_data_out, branch_target_out,
    output reg  [4:0]  rd_out,
    output reg  [2:0]  funct3_out,
    output reg         reg_write_out, mem_read_out, mem_write_out,
    output reg         mem_to_reg_out, branch_taken_out, jump_out
);
    always @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            pc_plus4_out <= 0; alu_result_out <= 0;
            wr_data_out <= 0; branch_target_out <= 0;
            rd_out <= 0; funct3_out <= 0;
            reg_write_out <= 0; mem_read_out <= 0; mem_write_out <= 0;
            mem_to_reg_out <= 0; branch_taken_out <= 0; jump_out <= 0;
        end else begin
            pc_plus4_out <= pc_plus4_in; alu_result_out <= alu_result_in;
            wr_data_out <= wr_data_in; branch_target_out <= branch_target_in;
            rd_out <= rd_in; funct3_out <= funct3_in;
            reg_write_out <= reg_write_in; mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in; mem_to_reg_out <= mem_to_reg_in;
            branch_taken_out <= branch_taken_in; jump_out <= jump_in;
        end
    end
endmodule

// ---- MEM/WB Register ----------------------------------------
module mem_wb_reg (
    input  wire        clk, rst,
    input  wire [31:0] pc_plus4_in, alu_result_in, mem_rd_data_in,
    input  wire [4:0]  rd_in,
    input  wire        reg_write_in, mem_to_reg_in, jump_in,
    output reg  [31:0] pc_plus4_out, alu_result_out, mem_rd_data_out,
    output reg  [4:0]  rd_out,
    output reg         reg_write_out, mem_to_reg_out, jump_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_plus4_out <= 0; alu_result_out <= 0; mem_rd_data_out <= 0;
            rd_out <= 0; reg_write_out <= 0; mem_to_reg_out <= 0; jump_out <= 0;
        end else begin
            pc_plus4_out <= pc_plus4_in; alu_result_out <= alu_result_in;
            mem_rd_data_out <= mem_rd_data_in; rd_out <= rd_in;
            reg_write_out <= reg_write_in; mem_to_reg_out <= mem_to_reg_in;
            jump_out <= jump_in;
        end
    end
endmodule

