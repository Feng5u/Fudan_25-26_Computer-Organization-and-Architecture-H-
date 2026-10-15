/**
 * This file is the top module of the pipeline
 */

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipeline_def.sv"
`include "include/csr.sv"
`include "src/components/regfile.sv"
`include "src/components/alu.sv"
`include "src/components/mul.sv"
`include "src/components/div.sv"
`include "src/components/csr_regfile.sv"
`include "src/components/imm_gen.sv"
`include "src/components/mmu.sv"
`include "src/components/trap.sv"
`include "src/components/branch_unit.sv"
`include "src/pipeline/if_stage.sv"
`include "src/pipeline/id_stage.sv"
`include "src/pipeline/ex_stage.sv"
`include "src/pipeline/mem_stage.sv"
`include "src/pipeline/wb_stage.sv"
`include "src/control/forward_unit.sv"
`include "src/control/stall.sv"
`endif

module pipeline_top
import common::*;
import pipeline_def::*;
import csr_pkg::*;
(
    input logic clk, rst,
    input logic trint, swint, exint,
    input ibus_resp_t iresp,
    output ibus_req_t ireq,
    input dbus_resp_t dresp,
    output dbus_req_t dreq,
    output u64 [31:0] gpr_out,
    output logic commit_valid,
    output u64 commit_pc,
    output u32 commit_instr,
    output logic commit_wen,
    output u5 commit_wdest,
    output u64 commit_wdata,
    output logic commit_mem,
    output u64 commit_mem_addr,
    output u64 commit_mstatus,
    output u64 commit_mtvec,
    output u64 commit_mip,
    output u64 commit_mie,
    output u64 commit_mscratch,
    output u64 commit_mcause,
    output u64 commit_mtval,
    output u64 commit_mepc,
    output u64 commit_mcycle,
    output u64 commit_mhartid,
    output u64 commit_satp,
    output u64 commit_sstatus,
    output u2 commit_priv,
    output u2 core_priv
);

    logic regfile_we;
    u5 regfile_waddr;
    u64 regfile_wdata;
    u64 regfile_rdata1, regfile_rdata2;
    u5 regfile_raddr1, regfile_raddr2;

    regfile u_regfile(
        .clk(clk),
        .rst(rst),
        .we(regfile_we),
        .waddr(regfile_waddr),
        .wdata(regfile_wdata),
        .re1(1'b1),
        .raddr1(regfile_raddr1),
        .rdata1(regfile_rdata1),
        .re2(1'b1),
        .raddr2(regfile_raddr2),
        .rdata2(regfile_rdata2),
        .gpr_out(gpr_out)
    );

    logic step;
    logic stall_sig;
    logic fetch_ok, decode_ok, execute_ok, mem_ok, writeback_ok;
    if_id if_id_reg;
    id_ex id_ex_reg;
    ex_mem ex_mem_reg;
    mem_wb mem_wb_reg;
    logic branch_taken;
    u64 branch_target;

    u64 wb_result;
    u5 wb_rd;
    logic wb_reg_write;

    stall_gen u_stall(
        .clk(clk),
        .rst(rst),
        .step(step),
        .if_id_inst(if_id_reg.inst),
        .if_id_valid(if_id_reg.valid),
        .id_ex_inst(id_ex_reg.inst),
        .id_ex_valid(id_ex_reg.valid),
        .is_load(id_ex_reg.is_load),
        .stall(stall_sig)
    );

    u2 current_priv, prev_priv;
    u2 next_priv;
    u1 priv_we;
    
    u12 csr_raddr;
    u64 csr_rdata;
    logic csr_we;
    u12 csr_waddr;
    u64 csr_wdata;
    csr_reg u_csr_reg;

    csr_regfile u_csr_regfile(
        .clk(clk),
        .rst(rst),
        .trint(trint),
        .swint(swint),
        .exint(exint),
        .csr_re(1'b1),
        .csr_raddr(csr_raddr),
        .csr_rdata(csr_rdata),
        .csr_we(csr_we),
        .csr_waddr(csr_waddr),
        .csr_wdata(csr_wdata),
        .csr_reg_out(u_csr_reg),
        .is_mret(ex_mem_reg.is_mret),
        .exception_taken(ex_mem_reg.exception_taken),
        .next_mepc(ex_mem_reg.next_mepc),
        .next_mcause(ex_mem_reg.next_mcause),
        .next_mstatus(ex_mem_reg.next_mstatus),
        .current_priv(current_priv),
        .prev_priv(prev_priv)
    );

    IF u_if_stage(
        .clk(clk),
        .rst(rst),
        .step(step),
        .stall(stall_sig),
        .exception_taken(exception_taken),
        .branch_taken(branch_taken),
        .branch_target(next_pc),
        .fetch_ok(fetch_ok),
        .if_id_out(if_id_reg),
        .ibus_req(ireq),
        .ibus_resp(iresp)
    );

    u64 id_in_rdata1, id_in_rdata2;

    always_comb begin
        id_in_rdata1 = regfile_rdata1;
        id_in_rdata2 = regfile_rdata2;
    end

    id u_id_stage(
        .clk(clk),
        .rst(rst),
        .step(step),
        .stall(stall_sig),
        .if_id_in(if_id_reg),
        .rs1_data_in(id_in_rdata1),
        .rs2_data_in(id_in_rdata2),
        .id_ex_out(id_ex_reg),
        .decode_ok(decode_ok),
        .exception_taken(exception_taken),
        .branch_taken(branch_taken),
        .csr_rdata(csr_rdata)
    );

    logic [6:0] opcode;
    always_comb begin
        opcode = if_id_reg.inst[6:0];
        regfile_raddr1 = if_id_reg.inst[19:15];
        regfile_raddr2 = if_id_reg.inst[24:20];
        case (opcode) 
            7'b1110011:begin
                case (if_id_reg.inst[14:12])
                    3'b000: begin
                        case (if_id_reg.inst[31:20])
                            12'b000000000000: csr_raddr = CSR_MTVEC;
                            12'b001100000010: csr_raddr = CSR_MEPC;
                            default: csr_raddr = if_id_reg.inst[31:20];
                        endcase
                    end
                    default: csr_raddr = if_id_reg.inst[31:20];
                endcase
            end
            default: begin
            end
        endcase
    end

    logic [1:0] forward_a, forward_b;
    u64 forward_data_a, forward_data_b;

    u64 priv_change_pc;
    always_ff @(posedge clk) begin
        if (rst) begin
            current_priv <= 2'b11;
            prev_priv <= 2'b11;
            priv_change_pc <= 64'b0;
        end else if (priv_we && (id_ex_reg.pc != priv_change_pc || trint || swint || exint)) begin
            prev_priv <= current_priv;
            current_priv <= next_priv;
            priv_change_pc <= id_ex_reg.pc;
        end
    end

    u64 alu_result;

    ex u_ex_stage(
        .clk(clk),
        .rst(rst),
        .step(step),
        .stall(stall_sig),
        .current_priv(current_priv),
        .id_ex_in(id_ex_reg),
        .forward_a(forward_a),
        .forward_b(forward_b),
        .forward_data_a(forward_data_a),
        .forward_data_b(forward_data_b),
        .ex_mem_out(ex_mem_reg),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .execute_ok(execute_ok),
        .alu_result(alu_result),
        .exception_taken(exception_taken),
        .next_mepc(next_mepc),
        .next_mcause(next_mcause),
        .next_mstatus(next_mstatus)
    );

    u64 next_pc, next_mepc, next_mcause, next_mstatus;
    logic exception_taken;

    trap u_trap (
        .clk(clk),
        .trint(trint),
        .swint(swint),
        .exint(exint),
        .id_ex_reg(id_ex_reg),
        .alu_result(alu_result),
        .ex_mem_reg(ex_mem_reg),
        .mem_wb_reg(mem_wb_reg),
        .u_csr_reg(u_csr_reg),
        .prev_priv(prev_priv),
        .cur_priv(current_priv),
        .priv_we(priv_we),
        .next_priv(next_priv),
        .next_pc(next_pc),
        .next_mepc(next_mepc),
        .next_mcause(next_mcause),
        .next_mstatus(next_mstatus),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .exception_taken(exception_taken)
    );

    forward_unit u_forward_unit(
        .id_ex_reg(id_ex_reg),
        .ex_mem_reg(ex_mem_reg),
        .mem_wb_reg(mem_wb_reg),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    always_comb begin
        if (forward_a == 2'b01) begin
            forward_data_a = ex_mem_reg.alu_result;
        end else if (forward_a == 2'b10) begin
            forward_data_a = mem_wb_reg.alu_result;
        end else begin
            forward_data_a = id_ex_reg.rs1_data;
        end

        if (forward_b == 2'b01) begin
            forward_data_b = ex_mem_reg.alu_result;
        end else if (forward_b == 2'b10) begin
            forward_data_b = mem_wb_reg.alu_result;
        end else begin
            forward_data_b = id_ex_reg.rs2_data;
        end
    end

    mem u_mem_stage(
        .clk(clk),
        .rst(rst),
        .step(step),
        .stall(stall_sig),
        .ex_mem_in(ex_mem_reg),
        .mem_wb_out(mem_wb_reg),
        .mem_ok(mem_ok),
        .dbus_req(dreq),
        .dbus_resp(dresp)
    );

    wb u_wb_stage(
        .clk(clk),
        .rst(rst),
        .step(step),
        .stall(stall_sig),
        .mem_wb_in(mem_wb_reg),
        .wb_result(wb_result),
        .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write),
        .writeback_ok(writeback_ok),
        .csr_we(csr_we),
        .csr_waddr(csr_waddr),
        .csr_wdata(csr_wdata)
    );

    assign regfile_we = wb_reg_write;
    assign regfile_waddr = wb_rd;
    assign regfile_wdata = wb_result;

    assign step = fetch_ok && decode_ok && execute_ok && mem_ok && writeback_ok;

    u64 prev_pc;

    always_ff @(posedge clk) begin
        if (rst == `Enable) begin
            prev_pc <= 64'b0;
            commit_valid <= `Disable;
        end else if (mem_wb_reg.pc != 64'b0 && mem_wb_reg.pc != prev_pc && 
                mem_wb_reg.inst != `InstNone) begin
            commit_valid <= `Enable;
            prev_pc <= mem_wb_reg.pc;
        end else begin
            commit_valid <= `Disable;
        end
    end
    
    assign commit_pc = mem_wb_reg.pc;
    assign commit_instr = mem_wb_reg.inst;
    assign commit_wen = mem_wb_reg.reg_write;
    assign commit_wdest = mem_wb_reg.rd;
    assign commit_wdata = mem_wb_reg.alu_result;
    assign commit_mem = mem_wb_reg.mem;
    assign commit_mem_addr = mem_wb_reg.mem_addr;
    assign commit_mstatus = u_csr_reg.mstatus;
    assign commit_mtvec = u_csr_reg.mtvec;
    assign commit_mip = u_csr_reg.mip;
    assign commit_mie = u_csr_reg.mie;
    assign commit_mscratch = u_csr_reg.mscratch;
    assign commit_mcause = u_csr_reg.mcause;
    assign commit_mtval = u_csr_reg.mtval;
    assign commit_mepc = u_csr_reg.mepc;
    assign commit_mcycle = u_csr_reg.mcycle;
    assign commit_mhartid = u_csr_reg.mhartid;
    assign commit_satp = u_csr_reg.satp;
    assign commit_sstatus = u_csr_reg.sstatus;
    assign commit_priv = mem_wb_reg.current_priv;
    assign core_priv = current_priv;

endmodule