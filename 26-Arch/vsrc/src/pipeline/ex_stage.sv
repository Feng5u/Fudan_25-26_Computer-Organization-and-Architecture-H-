/**
 * This file implements the EX stage.
 */

module ex
import common::*;
import pipeline_def::*;
(
    input logic clk, rst,
    input logic step,
    input logic stall,
    input u2 current_priv,
    input id_ex id_ex_in,
    input u2 forward_a,
    input u2 forward_b,
    input u64 forward_data_a,
    input u64 forward_data_b,
    output ex_mem ex_mem_out,
    output logic branch_taken,
    output u64 branch_target,
    output logic execute_ok,
    output u64 alu_result,
    input logic exception_taken,
    input u64 next_mcause, next_mepc, next_mstatus
);

    logic alu_stall;
    logic branch_taken_int;
    u64 alu_src_a, alu_src_b;
    u64 rs1_data_forwarded, rs2_data_forwarded;

    always_comb begin
        case (forward_a)
            2'b01,
            2'b10: rs1_data_forwarded = forward_data_a;
            default: rs1_data_forwarded = id_ex_in.rs1_data;
        endcase
    end

    always_comb begin
        case (forward_b)
            2'b01,
            2'b10: rs2_data_forwarded = forward_data_b;
            default: rs2_data_forwarded = id_ex_in.rs2_data;
        endcase
    end

    assign alu_src_a = (id_ex_in.rs1 == `RegNone ? 64'b0 : rs1_data_forwarded);

    always_comb begin
        if (id_ex_in.alu_src_b == 1'b0) begin
            alu_src_b = (id_ex_in.rs2 == `RegNone ? 64'b0 : rs2_data_forwarded);
        end else begin
            alu_src_b = id_ex_in.imm;
        end
    end

    alu u_alu(
        .clk(clk),
        .src_a(alu_src_a),
        .src_b(alu_src_b),
        .alu_op(id_ex_in.alu_op),
        .is_32bit(id_ex_in.is_32bit),
        .result(alu_result),
        .alu_stall(alu_stall)
    );

    branch_unit u_branchunit(
        .funct3(id_ex_in.branch_type),
        .rs1_data(alu_src_a),
        .rs2_data(alu_src_b),
        .branch_taken(branch_taken_int)
    );

    ex_mem ex_mem_next;

    always_comb begin
        ex_mem_next.pc = id_ex_in.pc;
        ex_mem_next.alu_result = id_ex_in.is_csr ? id_ex_in.csr_data : (id_ex_in.store_pc ? id_ex_in.pc + 4 : alu_result);
        ex_mem_next.store_data = rs2_data_forwarded;
        ex_mem_next.rd = id_ex_in.rd;
        ex_mem_next.reg_write = id_ex_in.reg_write;
        ex_mem_next.is_32bit = id_ex_in.is_32bit;
        ex_mem_next.is_load = id_ex_in.is_load;
        ex_mem_next.ret_addr = id_ex_in.pc + 4;
        ex_mem_next.inst = id_ex_in.inst;
        ex_mem_next.valid = id_ex_in.valid;
        ex_mem_next.is_csr = id_ex_in.is_csr;
        ex_mem_next.csr_addr = id_ex_in.csr_addr;
        ex_mem_next.csr_data = alu_result;
        ex_mem_next.exception_taken = exception_taken;
        ex_mem_next.next_mcause = next_mcause;
        ex_mem_next.next_mepc = next_mepc;
        ex_mem_next.next_mstatus = next_mstatus;
        ex_mem_next.is_mret = id_ex_in.is_mret;
        ex_mem_next.current_priv = current_priv;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            ex_mem_out <= '0;
        end else if (step && ex_mem_out.pc != id_ex_in.pc) begin
            ex_mem_out <= ex_mem_next;
        end
    end

    assign execute_ok = ~alu_stall;

    assign branch_taken = (id_ex_in.is_branch && branch_taken_int) || id_ex_in.is_jal || id_ex_in.is_jalr || id_ex_in.is_csr || id_ex_in.is_ecall || id_ex_in.is_mret;
    assign branch_target = (id_ex_in.is_ecall || id_ex_in.is_mret) ? id_ex_in.csr_data : (id_ex_in.is_csr ? id_ex_in.pc + 4 : (id_ex_in.is_branch && branch_taken_int) ? id_ex_in.imm : ((id_ex_in.is_jal || id_ex_in.is_jalr) ? alu_result : 64'b0));

endmodule