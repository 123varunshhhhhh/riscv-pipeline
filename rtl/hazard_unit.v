// ============================================================
// Hazard Unit — Data Forwarding + Stall Detection
// Handles RAW hazards and load-use hazards
// ============================================================
module hazard_unit (
    // Current instruction in ID/EX
    input  wire [4:0]  id_ex_rs1,
    input  wire [4:0]  id_ex_rs2,
    // Previous instruction in EX/MEM
    input  wire [4:0]  ex_mem_rd,
    input  wire        ex_mem_reg_write,
    input  wire        ex_mem_mem_read, // Load in EX/MEM → load-use hazard
    // Two-previous instruction in MEM/WB
    input  wire [4:0]  mem_wb_rd,
    input  wire        mem_wb_reg_write,
    // Forwarding select (to EX stage ALU inputs)
    output reg  [1:0]  fwd_a,  // 00=RegFile, 01=MEM/WB, 10=EX/MEM
    output reg  [1:0]  fwd_b,
    // Stall / flush for load-use hazard
    output wire        stall,
    output wire        if_id_flush
);

    // Load-use hazard: EX/MEM is a load AND it targets a register we need
    wire load_use = ex_mem_mem_read &&
                    ((ex_mem_rd == id_ex_rs1) || (ex_mem_rd == id_ex_rs2));

    assign stall       = load_use;
    assign if_id_flush = load_use;

    // EX/MEM forwarding takes priority over MEM/WB
    always @(*) begin
        // Forward A
        if (ex_mem_reg_write && ex_mem_rd != 5'b0 && ex_mem_rd == id_ex_rs1)
            fwd_a = 2'b10;
        else if (mem_wb_reg_write && mem_wb_rd != 5'b0 && mem_wb_rd == id_ex_rs1)
            fwd_a = 2'b01;
        else
            fwd_a = 2'b00;

        // Forward B
        if (ex_mem_reg_write && ex_mem_rd != 5'b0 && ex_mem_rd == id_ex_rs2)
            fwd_b = 2'b10;
        else if (mem_wb_reg_write && mem_wb_rd != 5'b0 && mem_wb_rd == id_ex_rs2)
            fwd_b = 2'b01;
        else
            fwd_b = 2'b00;
    end

endmodule

