// ============================================================
// WB Stage — Write Back
// Selects between ALU result and memory load data
// ============================================================
module wb_stage (
    input  wire [31:0] alu_result,
    input  wire [31:0] mem_rd_data,
    input  wire        mem_to_reg,  // 1 = use memory data
    output wire [31:0] wb_data
);

    assign wb_data = mem_to_reg ? mem_rd_data : alu_result;

endmodule

