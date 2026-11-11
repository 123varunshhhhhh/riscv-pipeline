// ============================================================
// Register File — 32 x 32-bit registers (RV32I)
// x0 is hardwired to 0 (read-only)
// Supports 2 async read ports, 1 sync write port
// ============================================================
module reg_file (
    input  wire        clk,
    input  wire        rst,
    // Read ports
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    output wire [31:0] rd1,
    output wire [31:0] rd2,
    // Write port
    input  wire [4:0]  rd,
    input  wire [31:0] wr_data,
    input  wire        reg_write
);

    reg [31:0] regs [31:0];
    integer i;

    // x0 is always 0
    assign rd1 = (rs1 != 5'b0) ? regs[rs1] : 32'b0;
    assign rd2 = (rs2 != 5'b0) ? regs[rs2] : 32'b0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else begin
            if (reg_write && rd != 5'b0)
                regs[rd] <= wr_data;
        end
    end

endmodule

