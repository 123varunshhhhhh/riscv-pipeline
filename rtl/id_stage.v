// ============================================================
// ID Stage — Instruction Decode + Immediate Generation
// Decodes all RV32I instruction formats
// ============================================================
module id_stage (
    input  wire [31:0] instr,     // Raw 32-bit instruction
    input  wire [31:0] rd1_data,  // Register file read data 1
    input  wire [31:0] rd2_data,  // Register file read data 2
    // Decoded fields
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    // Control signals
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         mem_to_reg,
    output reg         alu_src,    // 1 = use immediate
    output reg         branch,
    output reg         jump,
    output reg  [3:0]  alu_ctrl,
    // Sign-extended immediate
    output reg  [31:0] imm_ext
);

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // Immediate generation (all formats)
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    always @(*) begin
        // Default safe values
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        alu_src    = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        alu_ctrl   = 4'b0000;
        imm_ext    = 32'b0;

        case (opcode)
            7'b0110011: begin // R-type
                reg_write = 1'b1;
                case ({funct7[5], funct3})
                    4'b0_000: alu_ctrl = 4'b0000; // ADD
                    4'b1_000: alu_ctrl = 4'b0001; // SUB
                    4'b0_111: alu_ctrl = 4'b0010; // AND
                    4'b0_110: alu_ctrl = 4'b0011; // OR
                    4'b0_100: alu_ctrl = 4'b0100; // XOR
                    4'b0_010: alu_ctrl = 4'b0101; // SLT
                    4'b0_011: alu_ctrl = 4'b0110; // SLTU
                    4'b0_001: alu_ctrl = 4'b0111; // SLL
                    4'b0_101: alu_ctrl = 4'b1000; // SRL
                    4'b1_101: alu_ctrl = 4'b1001; // SRA
                    default:  alu_ctrl = 4'b0000;
                endcase
            end
            7'b0010011: begin // I-type ALU
                reg_write = 1'b1;
                alu_src   = 1'b1;
                imm_ext   = imm_i;
                case (funct3)
                    3'b000: alu_ctrl = 4'b0000; // ADDI
                    3'b111: alu_ctrl = 4'b0010; // ANDI
                    3'b110: alu_ctrl = 4'b0011; // ORI
                    3'b100: alu_ctrl = 4'b0100; // XORI
                    3'b010: alu_ctrl = 4'b0101; // SLTI
                    3'b011: alu_ctrl = 4'b0110; // SLTIU
                    3'b001: alu_ctrl = 4'b0111; // SLLI
                    3'b101: alu_ctrl = funct7[5] ? 4'b1001 : 4'b1000; // SRAI/SRLI
                    default: alu_ctrl = 4'b0000;
                endcase
            end
            7'b0000011: begin // Load (LW, LH, LB)
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_src    = 1'b1;
                alu_ctrl   = 4'b0000; // ADD (base + offset)
                imm_ext    = imm_i;
            end
            7'b0100011: begin // Store (SW, SH, SB)
                mem_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = 4'b0000;
                imm_ext   = imm_s;
            end
            7'b1100011: begin // Branch (BEQ, BNE, BLT, BGE)
                branch  = 1'b1;
                alu_ctrl= 4'b0001; // SUB (compare)
                imm_ext = imm_b;
            end
            7'b1101111: begin // JAL
                reg_write = 1'b1;
                jump      = 1'b1;
                imm_ext   = imm_j;
            end
            7'b1100111: begin // JALR
                reg_write = 1'b1;
                jump      = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = 4'b0000;
                imm_ext   = imm_i;
            end
            7'b0110111: begin // LUI
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = 4'b0000;
                imm_ext   = imm_u;
            end
            7'b0010111: begin // AUIPC
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = 4'b0000;
                imm_ext   = imm_u;
            end
            default: ; // NOP
        endcase
    end

endmodule

