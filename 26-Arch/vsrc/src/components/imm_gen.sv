/**
 * This file implements the immediate generator.
 */

module imm_gen
import common::*;
import pipeline_def::*;
(
    input u64 pc,
    input u32 inst_i,
    output u64 imm_o
);

    always_comb begin
        imm_o = `ZeroWord;
        case (inst_i[6:0])
            7'b0000011:
                imm_o = {{52{inst_i[31]}}, inst_i[31:20]};
            7'b0010011: begin
                if (inst_i[14:12] == 3'b001 || inst_i[14:12] == 3'b101) begin
                    imm_o = {58'b0, inst_i[25:20]};
                end else begin
                    imm_o = {{52{inst_i[31]}}, inst_i[31:20]};
                end
            end
            7'b0011011: begin
                if (inst_i[14:12] == 3'b001 || inst_i[14:12] == 3'b101) begin
                    imm_o = {59'b0, inst_i[24:20]};
                end else begin
                    imm_o = {{52{inst_i[31]}}, inst_i[31:20]};
                end
            end
            7'b0100011:
                imm_o = {{52{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
            7'b0110111:
                imm_o = {{32{inst_i[31]}}, inst_i[31:12], 12'b0};
            7'b1100011:
                imm_o = {{51{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
            7'b1101111:
                imm_o = {{43{inst_i[31]}}, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
            7'b1100111:
                imm_o = {{52{inst_i[31]}}, inst_i[31:20]};
            7'b0010111: begin
                imm_o = {{32{inst_i[31]}}, inst_i[31:12], 12'b0};
                imm_o = imm_o + pc;
            end
            7'b1110011: imm_o = {59'b0, inst_i[19:15]};
            default:
                imm_o = `ZeroWord;
        endcase
    end

endmodule