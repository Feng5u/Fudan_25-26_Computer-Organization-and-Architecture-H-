/**
 * This file defines the pipeline 
 */
`ifndef PIPELINE_DEF_SV
`define PIPELINE_DEF_SV

`define Enable 1'b1
`define Disable 1'b0

`define RegNone 5'b00000
`define InstNone 32'hFFFFFFFF
`define ZeroWord 64'b0

package pipeline_def;
import common::*;

typedef struct packed {
    addr_t pc;
    u32 inst;
    logic valid;
} if_id;

typedef struct packed {
    addr_t pc;
    u64 rs1_data;
    u64 rs2_data;
    u64 imm;
    u5 rd;
    u5 rs1;
    u5 rs2;
    alu_op_t alu_op;
    logic [2:0] branch_type;
    logic alu_src_a;
    logic alu_src_b;
    logic reg_write;
    logic is_32bit;
    logic is_load;
    logic is_branch;
    logic is_jal;
    logic is_jalr;
    u32 inst;
    logic valid;
    logic store_pc;
    logic is_csr;
    u12 csr_addr;
    u64 csr_data;
    u1 is_ecall;
    u1 is_mret;
    u1 is_ii;
} id_ex;

typedef struct packed {
    addr_t pc;
    u64 alu_result;
    u64 store_data;
    u5 rd;
    logic reg_write;
    logic is_32bit;
    logic is_load;
    u64 ret_addr;
    u32 inst;
    logic valid;
    logic is_csr;
    u12 csr_addr;
    u64 csr_data;
    u1 exception_taken;
    u64 next_mepc;
    u64 next_mcause;
    u64 next_mstatus;
    u1 is_mret;
    u2 current_priv;
} ex_mem;

typedef struct packed {
    addr_t pc;
    u64 alu_result;
    u5 rd;
    logic reg_write;
    u64 ret_addr;
    u32 inst;
    logic valid;
    logic mem;
    u64 mem_addr;
    logic is_csr;
    u12 csr_addr;
    u64 csr_data;
    u1 exception_taken;
    u64 next_mepc;
    u64 next_mcause;
    u64 next_mtval;
    u1 is_mret;
    u2 current_priv;
} mem_wb;

typedef struct packed {
    u64 mstatus;
    u64 mtvec;
    u64 mip;
    u64 mie;
    u64 mscratch;
    u64 mcause;
    u64 mtval;
    u64 mepc;
    u64 mcycle;
    u64 mhartid;
    u64 satp;
    u64 sstatus;
} csr_reg;

typedef enum logic [4:0] {
    ALU_NULL,
    ALU_ADD,
    ALU_SUB,
    ALU_XOR,
    ALU_OR,
    ALU_AND,
    ALU_ANDN,
    
    ALU_SLL,
    ALU_SRL,
    ALU_SRA,
    ALU_SLT,
    ALU_SLTU,
    ALU_SLLI,
    ALU_SRLI,
    ALU_SRAI,

    ALU_BRANCH,
    
    ALU_MUL,
    ALU_DIV,
    ALU_DIVU,
    ALU_REM,
    ALU_REMU,
    ALU_MULW,
    ALU_DIVW,
    ALU_DIVUW,
    ALU_REMW,
    ALU_REMUW
} alu_op_t;

endpackage
`endif