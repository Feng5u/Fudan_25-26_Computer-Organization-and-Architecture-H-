/**
 * This file implements the stall unit
 */

module stall_gen 
import common::*;
import pipeline_def::*;
(
    input logic clk,
    input logic rst,
    input logic step,
    input logic [31:0] if_id_inst,
    input logic if_id_valid,
    input logic [31:0] id_ex_inst,
    input logic id_ex_valid,
    input logic is_load,
    output logic stall
);

    logic [4:0] ex_rd;
    logic [4:0] id_rs1;
    logic [4:0] id_rs2;
    logic need_rs1, need_rs2;
    logic [6:0] id_opcode;
    logic load_use_hazard;

    assign ex_rd = id_ex_inst[11:7];
    assign id_rs1 = if_id_inst[19:15];
    assign id_rs2 = if_id_inst[24:20];
    assign id_opcode = if_id_inst[6:0];

    always_comb begin
        case (id_opcode)
            7'b0100011: begin need_rs1 = 1'b1; need_rs2 = 1'b1; end
            7'b0110011: begin need_rs1 = 1'b1; need_rs2 = 1'b1; end
            7'b0010011: begin need_rs1 = 1'b1; need_rs2 = 1'b0; end
            7'b0111011: begin need_rs1 = 1'b1; need_rs2 = 1'b1; end
            7'b0011011: begin need_rs1 = 1'b1; need_rs2 = 1'b0; end
            7'b1100011: begin need_rs1 = 1'b1; need_rs2 = 1'b1; end
            7'b1110011: begin need_rs1 = 1'b1; need_rs2 = 1'b0; end
            7'b0000011: begin need_rs1 = 1'b1; need_rs2 = 1'b0; end
            default:    begin need_rs1 = 1'b0; need_rs2 = 1'b0; end
        endcase
    end

    assign load_use_hazard = is_load && 
                             id_ex_valid && 
                             (ex_rd != `RegNone) && 
                             if_id_valid &&
                             ((need_rs1 && ex_rd == id_rs1) ||
                              (need_rs2 && ex_rd == id_rs2));

    always_ff @(posedge clk) begin
        if (rst) begin
            stall <= 1'b0;
        end else begin
            case (stall)
                1'b0:
                    stall <= load_use_hazard;
                1'b1:
                    if (step) begin
                        stall <= load_use_hazard;
                    end
            endcase
        end
    end

endmodule