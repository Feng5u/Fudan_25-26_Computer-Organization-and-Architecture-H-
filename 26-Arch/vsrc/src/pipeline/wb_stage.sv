/**
 * This file implements the WB stage.
 */

module wb
import common::*;
import pipeline_def::*;
(
    input logic clk, rst,
    input logic step,
    input logic stall,
    input mem_wb mem_wb_in,
    output u64 wb_result,
    output u5 wb_rd,
    output logic wb_reg_write,
    output logic writeback_ok,
    output logic csr_we,
    output u12 csr_waddr,
    output u64 csr_wdata
);

    always_comb begin
        if (!mem_wb_in.valid) begin
            wb_result = 64'b0;
        end else if (mem_wb_in.inst[6:0] == 7'b1101111 || mem_wb_in.inst[6:0] == 7'b1100111) begin
            wb_result = mem_wb_in.ret_addr;
        end else begin
            wb_result = mem_wb_in.alu_result;
        end
    end

    always_comb begin
        if (mem_wb_in.valid && mem_wb_in.is_csr) begin
            csr_we = `Enable;
            csr_waddr = mem_wb_in.csr_addr;
            csr_wdata = mem_wb_in.csr_data;
        end else begin
            csr_we = `Disable;
            csr_waddr = 12'b0;
            csr_wdata = 64'b0;
        end
    end

    assign wb_rd = !mem_wb_in.valid ? 5'b0 : mem_wb_in.rd;
    assign wb_reg_write = !mem_wb_in.valid ? 1'b0 : mem_wb_in.reg_write;

    assign writeback_ok = 1'b1;

endmodule