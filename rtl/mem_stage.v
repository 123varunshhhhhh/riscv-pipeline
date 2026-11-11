// ============================================================
// MEM Stage — Data Memory Access (LW/SW)
// 256-word data memory, byte/halfword/word access
// ============================================================
module mem_stage (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] alu_result,  // Computed address
    input  wire [31:0] wr_data,     // Store data (RS2)
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [2:0]  funct3,      // LW/LH/LB/LHU/LBU / SW/SH/SB
    output reg  [31:0] rd_data      // Load result
);

    reg [7:0] dmem [0:1023]; // 1 KB byte-addressable data memory

    wire [9:0] addr = alu_result[9:0];

    always @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                3'b010: begin // SW
                    dmem[addr]   <= wr_data[7:0];
                    dmem[addr+1] <= wr_data[15:8];
                    dmem[addr+2] <= wr_data[23:16];
                    dmem[addr+3] <= wr_data[31:24];
                end
                3'b001: begin // SH
                    dmem[addr]   <= wr_data[7:0];
                    dmem[addr+1] <= wr_data[15:8];
                end
                3'b000: begin // SB
                    dmem[addr]   <= wr_data[7:0];
                end
            endcase
        end
    end

    always @(*) begin
        rd_data = 32'b0;
        if (mem_read) begin
            case (funct3)
                3'b010: rd_data = {dmem[addr+3], dmem[addr+2], dmem[addr+1], dmem[addr]};  // LW
                3'b001: rd_data = {{16{dmem[addr+1][7]}}, dmem[addr+1], dmem[addr]};        // LH
                3'b000: rd_data = {{24{dmem[addr][7]}},   dmem[addr]};                      // LB
                3'b101: rd_data = {16'b0, dmem[addr+1], dmem[addr]};                        // LHU
                3'b100: rd_data = {24'b0, dmem[addr]};                                      // LBU
                default: rd_data = 32'b0;
            endcase
        end
    end

endmodule

