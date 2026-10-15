`ifdef VERILATOR
`include "include/csr.sv"
`endif

module trap
import csr_pkg::*;
import common::*;
import pipeline_def::*;
(
    input logic clk,
    input logic trint, swint, exint,

    input id_ex id_ex_reg,
    input u64 alu_result,
    input ex_mem ex_mem_reg,
    input mem_wb mem_wb_reg,

    input csr_reg u_csr_reg,

    input u2 prev_priv,
    input u2 cur_priv,
    output u1 priv_we,
    output u2 next_priv,

    output u64 next_pc,
    output u64 next_mepc,
    output u64 next_mcause,
    output u64 next_mstatus,

    input u1 branch_taken,
    input u64 branch_target,

    output u1 exception_taken
);
    u7 opcode;
    u3 funct3;

    assign opcode = id_ex_reg.inst[6:0];
    assign funct3 = id_ex_reg.inst[14:12];

    logic is_load = (opcode == 7'b0000011);
    logic is_store = (opcode == 7'b0100011);

    u64 store_size;
    always_comb begin
        case (funct3)
            3'b000: store_size[2:0] = 3'b000;
            3'b001: store_size[2:0] = 3'b001;
            3'b010: store_size[2:0] = 3'b011;
            3'b011: store_size[2:0] = 3'b111;
            default: store_size[2:0] = 3'b000;
        endcase
    end

    u64 load_size;
    always_comb begin
        case (funct3)
            3'b000, 3'b100: load_size[2:0] = 3'b000;
            3'b001, 3'b101: load_size[2:0] = 3'b001;
            3'b010, 3'b110: load_size[2:0] = 3'b011;
            3'b011:         load_size[2:0] = 3'b111;
            default:        load_size[2:0] = 3'b000;
        endcase
    end

    u64 now_pc;
    u64 mret_pc;

    always_ff @(posedge clk) begin
        if (id_ex_reg.is_mret) begin
            mret_pc <= id_ex_reg.pc;
        end
    end

    assign now_pc = id_ex_reg.pc;

    csr_reg csr_reg_now;

    always_comb begin
        csr_reg_now.mstatus = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MSTATUS) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MSTATUS) ? mem_wb_reg.csr_data : u_csr_reg.mstatus));
        csr_reg_now.mtvec = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MTVEC) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MTVEC) ? mem_wb_reg.csr_data : u_csr_reg.mtvec));
        csr_reg_now.mip = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MIP) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MIP) ? mem_wb_reg.csr_data : u_csr_reg.mip));
        csr_reg_now.mie = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MIE) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MIE) ? mem_wb_reg.csr_data : u_csr_reg.mie));
        csr_reg_now.mscratch = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MSCRATCH) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MSCRATCH) ? mem_wb_reg.csr_data : u_csr_reg.mscratch));
        csr_reg_now.mcause = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MCAUSE) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MCAUSE) ? mem_wb_reg.csr_data : u_csr_reg.mcause));
        csr_reg_now.mtval = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MTVAL) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MTVAL) ? mem_wb_reg.csr_data : u_csr_reg.mtval));
        csr_reg_now.mepc = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MEPC) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MEPC) ? mem_wb_reg.csr_data : u_csr_reg.mepc));
        csr_reg_now.mcycle = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MCYCLE) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MCYCLE) ? mem_wb_reg.csr_data : u_csr_reg.mcycle));
        csr_reg_now.mhartid = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MHARTID) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MHARTID) ? mem_wb_reg.csr_data : u_csr_reg.mhartid));
        csr_reg_now.satp = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_SATP) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_SATP) ? mem_wb_reg.csr_data : u_csr_reg.satp));
        csr_reg_now.sstatus = (ex_mem_reg.is_csr && (ex_mem_reg.csr_addr == CSR_MSTATUS) ? ex_mem_reg.csr_data : (mem_wb_reg.is_csr && (mem_wb_reg.csr_addr == CSR_MSTATUS) ? mem_wb_reg.csr_data : u_csr_reg.mstatus)) & SSTATUS_MASK;
    end

    logic int_enable;

    assign int_enable = (cur_priv == 2'b11 && csr_reg_now.mstatus[3] == 1'b1) || (cur_priv != 2'b11);

    always_comb begin
        next_pc = branch_target;
        exception_taken = 1'b0;
        priv_we = 1'b0;
        if (branch_taken && branch_target[1:0] != 2'b00) begin
            exception_taken = 1'b1;
            next_pc = csr_reg_now.mtvec;
            next_mepc = id_ex_reg.pc;
            next_mcause = 0;
            next_mstatus[7] = csr_reg_now.mstatus[3];
            next_mstatus[3] = 1'b0;
            next_mstatus[12:11] = prev_priv;
            next_priv = 2'b11;
            priv_we = 1'b1;
        end else if (id_ex_reg.is_ii) begin
            exception_taken = 1'b1;
            next_pc = csr_reg_now.mtvec;
            next_mepc = id_ex_reg.pc;
            next_mcause = 2;
            next_mstatus[7] = csr_reg_now.mstatus[3];
            next_mstatus[3] = 1'b0;
            next_mstatus[12:11] = prev_priv;
            next_priv = 2'b11;
            priv_we = 1'b1;
        end else if ((is_load && ((alu_result & load_size) != 0)) || 
                     (is_store && ((alu_result & store_size) != 0))) begin
            exception_taken = 1'b1;
            next_pc = csr_reg_now.mtvec;
            next_mepc = id_ex_reg.pc;
            next_mcause = (is_load ? 4 : 6);
            next_mstatus[7] = csr_reg_now.mstatus[3];
            next_mstatus[3] = 1'b0;
            next_mstatus[12:11] = prev_priv;
            next_priv = 2'b11;
            priv_we = 1'b1;
        end else if (id_ex_reg.is_ecall) begin
            priv_we = 1'b1;
            next_priv = 2'b11;
            exception_taken = 1'b1;
            next_pc = csr_reg_now.mtvec;
            next_mepc = id_ex_reg.pc;
            case (prev_priv) 
                2'b00: next_mcause = 64'd8;
                2'b11: next_mcause = 64'd11;
                default: next_mcause = 64'd0;
            endcase
            next_mstatus[7] = csr_reg_now.mstatus[3];
            next_mstatus[3] = 1'b0;
            next_mstatus[12:11] = prev_priv;
        end else if (now_pc != mret_pc && id_ex_reg.pc != 0 && exint == 1 && int_enable && csr_reg_now.mie[11] == 1) begin
            exception_taken = 1'b1;
            next_pc = csr_reg_now.mtvec;
            next_mepc = id_ex_reg.pc;
            next_mcause[62:0] = 11;
            next_mcause[63] = 1;
            next_mstatus[7] = csr_reg_now.mstatus[3];
            next_mstatus[3] = 1'b0;
            next_mstatus[12:11] = prev_priv;
            next_priv = 2'b11;
            priv_we = 1'b1;
        end else if (now_pc != mret_pc && id_ex_reg.pc != 0 && swint == 1 && int_enable && csr_reg_now.mie[3] == 1) begin
            exception_taken = 1'b1;
            next_pc = csr_reg_now.mtvec;
            next_mepc = id_ex_reg.pc;
            next_mcause[62:0] = 3;
            next_mcause[63] = 1;
            next_mstatus[7] = csr_reg_now.mstatus[3];
            next_mstatus[3] = 1'b0;
            next_mstatus[12:11] = prev_priv;
            next_priv = 2'b11;
            priv_we = 1'b1;
        end else if (now_pc != mret_pc && id_ex_reg.pc != 0 && trint == 1 && int_enable && csr_reg_now.mie[7] == 1) begin
            exception_taken = 1'b1;
            next_pc = csr_reg_now.mtvec;
            next_mepc = id_ex_reg.pc;
            next_mcause[62:0] = 7;
            next_mcause[63] = 1;
            next_mstatus[7] = csr_reg_now.mstatus[3];
            next_mstatus[3] = 1'b0;
            next_mstatus[12:11] = prev_priv;
            next_priv = 2'b11;
            priv_we = 1'b1;
        end else if (id_ex_reg.is_mret) begin
            priv_we = 1'b1;
            next_priv = csr_reg_now.mstatus[12:11];
            next_mstatus[3] = csr_reg_now.mstatus[7];
            next_mstatus[7] = 1;
            next_mstatus[12:11] = 0;
            next_mstatus[15:14] = 0;
        end
    end

endmodule