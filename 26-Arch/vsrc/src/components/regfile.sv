/**
 * This file implements the register file.
 */

 module regfile
import common::*;
import pipeline_def::*;
(
    input logic clk, rst,

    input logic we,
    input u5 waddr,
    input u64 wdata,

    input logic re1,
    input u5 raddr1,
    output u64 rdata1,

    input logic re2,
    input u5 raddr2,
    output u64 rdata2,

    output u64 [31:0] gpr_out
);

    u64 regs[0:31];

    always_ff @ (posedge clk) begin
        if (rst == `Enable) begin
            for (int i = 0; i < 32; i++) begin
                regs[i] <= `ZeroWord;
            end
        end else if (we == `Enable) begin
            if (waddr != 5'b0) begin
                regs[waddr] <= wdata;
            end
        end
    end

    always_comb begin
        if (rst == `Enable) begin
            rdata1 = `ZeroWord;
        end else if (raddr1 == 5'b0) begin
            rdata1 = `ZeroWord;
        end else if ((raddr1 == waddr) && (we == `Enable)) begin
            rdata1 = wdata;
        end else if (re1 == `Enable) begin
            rdata1 = regs[raddr1];
        end else begin
            rdata1 = `ZeroWord;
        end
    end

    always_comb begin
        if (rst == `Enable) begin
            rdata2 = `ZeroWord;
        end else if (raddr2 == 5'b0) begin
            rdata2 = `ZeroWord;
        end else if ((raddr2 == waddr) && (we == `Enable)) begin
            rdata2 = wdata;
        end else if (re2 == `Enable) begin
            rdata2 = regs[raddr2];
        end else begin
            rdata2 = `ZeroWord;
        end
    end

    always_comb begin
        gpr_out[0] = `ZeroWord;
        for (int i = 1; i < 32; i++) begin
            if (rst == `Enable) begin
                gpr_out[i] = `ZeroWord;
            end else if ((i == {27'b0, waddr}) && (we == `Enable)) begin
                gpr_out[i] = wdata;
            end else begin
                gpr_out[i] = regs[i];
            end
        end
    end

 endmodule