// csr_regfile.sv
module csr_regfile 
import common::*;
import csr_pkg::*;
import pipeline_def::*;
(
    input logic clk, rst,
    input logic trint, swint, exint,
    
    input logic        csr_re,
    input logic [11:0] csr_raddr,
    output logic [63:0] csr_rdata,
    
    input logic        csr_we,
    input logic [11:0] csr_waddr,
    input logic [63:0] csr_wdata,
    
    output csr_reg csr_reg_out,

    input u1 is_mret,
    input u1 exception_taken,

    input u64 next_mepc,
    input u64 next_mcause,
    input u64 next_mstatus,
    input u2 current_priv,
    input u2 prev_priv
);

    csr_reg csr_reg_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            csr_reg_next <= '0;
        end else begin
            if (csr_we && csr_waddr == CSR_MCYCLE) begin
                csr_reg_next.mcycle <= csr_wdata;
            end else begin
                csr_reg_next.mcycle <= csr_reg_next.mcycle + 1;
            end
            
            if (exception_taken) begin
                csr_reg_next.mstatus <= next_mstatus;
                csr_reg_next.mepc <= next_mepc;
                csr_reg_next.mcause <= next_mcause;
            end else if (is_mret) begin
                csr_reg_next.mstatus <= next_mstatus;
            end else if (csr_we) begin
                case (csr_waddr)
                    CSR_MSTATUS: csr_reg_next.mstatus <= (csr_wdata & MSTATUS_MASK) | (csr_reg_next.mstatus & ~MSTATUS_MASK);
                    CSR_MIE: csr_reg_next.mie <= csr_wdata;
                    CSR_MTVEC: csr_reg_next.mtvec <= csr_wdata & MTVEC_MASK;
                    CSR_MSCRATCH: csr_reg_next.mscratch <= csr_wdata;
                    CSR_MEPC: csr_reg_next.mepc <= csr_wdata;
                    CSR_MCAUSE: csr_reg_next.mcause <= csr_wdata;
                    CSR_MTVAL: csr_reg_next.mtval <= csr_wdata;
                    CSR_MIP: csr_reg_next.mip <= csr_wdata & MIP_MASK;
                    CSR_MCYCLE:  ;
                    CSR_MHARTID: ;
                    CSR_SATP: csr_reg_next.satp <= csr_wdata;
                    default: ;
                endcase
            end
        end
    end

    always_comb begin
        if (csr_re) begin
            if (csr_we && csr_raddr == csr_waddr) begin
                case (csr_raddr)
                    CSR_MSTATUS: csr_rdata = (csr_wdata & MSTATUS_MASK) | (csr_reg_next.mstatus & ~MSTATUS_MASK);
                    CSR_MIE: csr_rdata = csr_wdata;
                    CSR_MTVEC: csr_rdata = csr_wdata & MTVEC_MASK;
                    CSR_MSCRATCH: csr_rdata = csr_wdata;
                    CSR_MEPC: csr_rdata = csr_wdata;
                    CSR_MCAUSE: csr_rdata = csr_wdata;
                    CSR_MTVAL: csr_rdata = csr_wdata;
                    CSR_MIP: csr_rdata = csr_wdata & MIP_MASK;
                    CSR_MCYCLE: csr_rdata = csr_wdata;
                    CSR_MHARTID: csr_rdata = csr_wdata;
                    CSR_SATP: csr_rdata = csr_wdata;
                    CSR_SSTATUS: csr_rdata = csr_wdata & SSTATUS_MASK;
                    default: csr_rdata = 64'd0;
                endcase
            end else begin
                case (csr_raddr)
                    CSR_MSTATUS: csr_rdata = csr_reg_next.mstatus;
                    CSR_MIE: csr_rdata = csr_reg_next.mie;
                    CSR_MTVEC: csr_rdata = csr_reg_next.mtvec;
                    CSR_MSCRATCH: csr_rdata = csr_reg_next.mscratch;
                    CSR_MEPC: csr_rdata = csr_reg_next.mepc;
                    CSR_MCAUSE: csr_rdata = csr_reg_next.mcause;
                    CSR_MTVAL: csr_rdata = csr_reg_next.mtval;
                    CSR_MIP: csr_rdata = csr_reg_next.mip & MIP_MASK;
                    CSR_MCYCLE: csr_rdata = csr_reg_next.mcycle;
                    CSR_MHARTID: csr_rdata = csr_reg_next.mhartid;
                    CSR_SATP: csr_rdata = csr_reg_next.satp;
                    CSR_SSTATUS: csr_rdata = csr_reg_next.mstatus & SSTATUS_MASK;
                    default: csr_rdata = 64'd0;
                endcase
            end
        end else begin
            csr_rdata = 64'd0;
        end
    end

    assign csr_reg_out.mstatus = csr_reg_next.mstatus;
    assign csr_reg_out.mtvec = csr_reg_next.mtvec;
    assign csr_reg_out.mip = csr_reg_next.mip & MIP_MASK;
    assign csr_reg_out.mie = csr_reg_next.mie;
    assign csr_reg_out.mscratch = csr_reg_next.mscratch;
    assign csr_reg_out.mcause = csr_reg_next.mcause;
    assign csr_reg_out.mtval = csr_reg_next.mtval;
    assign csr_reg_out.mepc = csr_reg_next.mepc;
    assign csr_reg_out.mcycle = csr_reg_next.mcycle;
    assign csr_reg_out.mhartid = csr_reg_next.mhartid;
    assign csr_reg_out.satp = csr_reg_next.satp;
    assign csr_reg_out.sstatus = csr_reg_next.mstatus & SSTATUS_MASK;

endmodule