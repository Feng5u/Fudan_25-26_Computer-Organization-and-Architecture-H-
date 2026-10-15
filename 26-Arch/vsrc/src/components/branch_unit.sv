/**
 * This file implements the branch unit for branch condition evaluation
 */

module branch_unit
import common::*;
import pipeline_def::*;
(
    input logic [2:0] funct3,
    input u64 rs1_data,
    input u64 rs2_data,
    output logic branch_taken
);

    always_comb begin
        branch_taken = 1'b0;
        case (funct3)
            3'b000: begin
                branch_taken = (rs1_data == rs2_data);
            end
            3'b001: begin
                branch_taken = (rs1_data != rs2_data);
            end
            3'b100: begin
                branch_taken = ($signed(rs1_data) < $signed(rs2_data));
            end
            3'b101: begin
                branch_taken = ($signed(rs1_data) >= $signed(rs2_data));
            end
            3'b110: begin
                branch_taken = (rs1_data < rs2_data);
            end
            3'b111: begin
                branch_taken = (rs1_data >= rs2_data);
            end
            default: begin
                branch_taken = 1'b0;
            end
        endcase
    end

endmodule