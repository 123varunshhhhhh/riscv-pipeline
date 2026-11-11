// ============================================================
// Branch Predictor — 2-bit Saturating Counter BHT
// 64-entry Branch History Table, indexed by PC[7:2]
// States: 00=Strongly NT, 01=Weakly NT, 10=Weakly T, 11=Strongly T
// ============================================================
module branch_predictor #(
    parameter ENTRIES     = 64,
    parameter INDEX_BITS  = 6
) (
    input  wire        clk,
    input  wire        rst,
    // Prediction request (IF stage)
    input  wire [31:0] pc,
    output wire        predicted_taken,
    // Update (from EX stage, one cycle after branch resolves)
    input  wire        update_valid,
    input  wire [31:0] update_pc,
    input  wire        actual_taken
);

    reg [1:0] bht [ENTRIES-1:0];
    integer i;

    wire [INDEX_BITS-1:0] pred_idx = pc[INDEX_BITS+1:2];
    wire [INDEX_BITS-1:0] updt_idx = update_pc[INDEX_BITS+1:2];

    // Predict: MSB of 2-bit counter
    assign predicted_taken = bht[pred_idx][1];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < ENTRIES; i = i + 1)
                bht[i] <= 2'b01; // Weakly not-taken at reset
        end else if (update_valid) begin
            if (actual_taken && bht[updt_idx] != 2'b11)
                bht[updt_idx] <= bht[updt_idx] + 1;
            else if (!actual_taken && bht[updt_idx] != 2'b00)
                bht[updt_idx] <= bht[updt_idx] - 1;
        end
    end

endmodule

