/**
 * This file implements the forwarding unit.
 */

module forward_unit
import common::*;
import pipeline_def::*;
(
    input id_ex id_ex_reg,
    input ex_mem ex_mem_reg,
    input mem_wb mem_wb_reg,

    output logic [1:0] forward_a,
    output logic [1:0] forward_b
);

    always_comb begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        if (ex_mem_reg.pc != id_ex_reg.pc && ex_mem_reg.reg_write && ex_mem_reg.rd != 5'b0 && ex_mem_reg.rd == id_ex_reg.rs1) begin
            forward_a = 2'b01;
        end else if (mem_wb_reg.reg_write && mem_wb_reg.rd != 5'b0 && mem_wb_reg.rd == id_ex_reg.rs1) begin
            forward_a = 2'b10;
        end

        if (ex_mem_reg.pc != id_ex_reg.pc && ex_mem_reg.reg_write && ex_mem_reg.rd != 5'b0 && ex_mem_reg.rd == id_ex_reg.rs2) begin
            forward_b = 2'b01;
        end else if (mem_wb_reg.reg_write && mem_wb_reg.rd != 5'b0 && mem_wb_reg.rd == id_ex_reg.rs2) begin
            forward_b = 2'b10;
        end
    end

endmodule