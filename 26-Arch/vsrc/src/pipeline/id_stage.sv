/**
 * This file implements the ID stage.
 */

module id
import common::*;
import pipeline_def::*;
import csr_pkg::*;
(
    input logic clk, rst,
    input logic step,
    input logic stall,
    input if_id if_id_in,
    input u64 rs1_data_in,
    input u64 rs2_data_in,
    output id_ex id_ex_out,
    output logic decode_ok,
    input logic exception_taken,
    input logic branch_taken,
    input u64 csr_rdata
);

    u64 imm_tmp, imm;
    u5 rs1, rs2, rd;
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [11:0] funct12;

    alu_op_t alu_op;
    logic alu_src_a;
    logic alu_src_b;
    logic reg_write;
    logic is_32bit;
    logic is_load;
    logic is_branch;
    logic is_jal;
    logic is_jalr;
    logic branch_taken_int;
    logic store_pc;
    logic is_csr;
    logic is_ecall;
    logic is_mret;
    logic is_ii;
    u64 branch_target_int;
    u12 csr_raddr;

    imm_gen u_imm_gen(
        .pc(if_id_in.pc),
        .inst_i(if_id_in.inst),
        .imm_o(imm_tmp)
    );

    always_comb begin
        opcode = if_id_in.inst[6:0];
        rd = if_id_in.inst[11:7];
        funct3 = if_id_in.inst[14:12];
        rs1 = if_id_in.inst[19:15];
        rs2 = if_id_in.inst[24:20];
        funct7 = if_id_in.inst[31:25];
        csr_raddr = if_id_in.inst[31:20];
        funct12 = if_id_in.inst[31:20];
        
        store_pc = 1'b0;
        alu_op = ALU_NULL;
        alu_src_a = 1'b0;
        alu_src_b = 1'b0;
        reg_write = 1'b0;
        is_32bit = 1'b0;
        is_load = 1'b0;
        is_branch = 1'b0;
        is_jal = 1'b0;
        is_jalr = 1'b0;
        is_csr = 1'b0;
        is_ecall = 1'b0;
        is_mret = 1'b0;
        is_ii = 1'b0;
        branch_target_int = 64'b0;

        case (opcode)
            7'b0000011: begin
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                is_32bit = 1'b0;
                is_load = 1'b1;
                alu_op = ALU_ADD;
                imm = imm_tmp;
            end

            7'b0100011: begin
                alu_src_b = 1'b1;
                reg_write = 1'b0;
                is_32bit = 1'b0;
                alu_op = ALU_ADD;
                imm = imm_tmp;
            end

            7'b0110011: begin
                alu_src_b = 1'b0;
                reg_write = 1'b1;
                is_32bit = 1'b0;
                imm = imm_tmp;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_ADD;
                        else if (funct7 == 7'b0000001)
                            alu_op = ALU_MUL;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SUB;
                    end
                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SLLI;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SRLI;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRAI;
                        else if (funct7 == 7'b00000001)
                            alu_op = ALU_DIVU;
                    end
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: begin 
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_XOR;
                        else if (funct7 == 7'b0000001) 
                            alu_op = ALU_DIV;
                    end
                    3'b110: begin 
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_OR;
                        else if (funct7 == 7'b0000001)
                            alu_op = ALU_REM;
                    end
                    3'b111: begin 
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_AND;
                        else if (funct7 == 7'b0000001)
                            alu_op = ALU_REMU;
                    end
                    default: begin 
                        alu_op = ALU_NULL;
                        is_ii = 1'b1;
                    end
                endcase
            end

            7'b0110111: begin
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                is_32bit = 1'b0;
                rs1 = `RegNone;
                alu_op = ALU_ADD;
                imm = imm_tmp;
            end

            7'b0111011: begin
                alu_src_b = 1'b0;
                reg_write = 1'b1;
                is_32bit = 1'b1;
                imm = imm_tmp;
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_ADD;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SUB;
                        else if (funct7 == 7'b0000001)
                            alu_op = ALU_MULW;
                    end
                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SLL;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                    end
                    3'b100: begin
                        if (funct7 == 7'b0000001) 
                            alu_op = ALU_DIVW;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SRL;
                        else if (funct7 == 7'b0000001)
                            alu_op = ALU_DIVUW;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                    end
                    3'b110: begin
                        if (funct7 == 7'b0000001)
                            alu_op = ALU_REMW; 
                    end
                    3'b111: begin
                        if (funct7 == 7'b0000001)
                            alu_op = ALU_REMUW;
                    end
                    default: begin 
                        is_ii = 1'b1;
                        alu_op = ALU_NULL;
                    end
                endcase
            end

            7'b0010011: begin
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                is_32bit = 1'b0;
                imm = imm_tmp;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b001: begin
                        if (funct7[6:1] == 6'b000000)
                            alu_op = ALU_SLLI;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                    end
                    3'b101: begin
                        if (funct7[6:1] == 6'b000000)
                            alu_op = ALU_SRLI;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                    end
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: begin 
                        is_ii = 1'b1;
                        alu_op = ALU_NULL;
                    end
                endcase
            end

            7'b0011011: begin
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                is_32bit = 1'b1;
                imm = imm_tmp;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b001: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SLL;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                    end
                    default: begin
                        is_ii = 1'b1;
                        alu_op = ALU_NULL;
                    end
                endcase
            end

            7'b1100011: begin
                reg_write = 1'b0;
                is_32bit = 1'b0;
                alu_op = ALU_ADD;
                is_branch = 1'b1;
                imm = if_id_in.pc + imm_tmp;
            end

            7'b1101111: begin
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                is_32bit = 1'b0;
                rs1 = `RegNone;
                alu_op = ALU_ADD;
                is_jal = 1'b1;
                imm = if_id_in.pc + imm_tmp;
                store_pc = 1'b1;
            end

            7'b1100111: begin
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                is_32bit = 1'b0;
                alu_op = ALU_BRANCH;
                is_jalr = 1'b1;
                imm = imm_tmp;
                store_pc = 1'b1;
            end

            7'b0010111: begin
                alu_src_b = 1'b1;
                reg_write = 1'b1;
                is_32bit = 1'b0;
                rs1 = `RegNone;
                alu_op = ALU_ADD;
                imm = imm_tmp;
            end

            7'b1110011: begin
                reg_write = 1'b1;
                is_32bit = 1'b0;
                is_csr = 1'b1;
                case (funct3)
                    3'b000: begin
                        case(funct12)
                            12'b000000000000: begin
                                is_ecall = 1'b1;
                                reg_write = 1'b0;
                                is_csr = 1'b0;
                                csr_raddr = CSR_MTVEC;
                            end
                            12'b001100000010: begin
                                is_mret = 1'b1;
                                reg_write = 1'b0;
                                is_csr = 1'b0;
                                csr_raddr = CSR_MEPC;
                            end
                            default: begin
                                is_ii = 1'b1;
                                is_ecall = 1'b0;
                                is_mret = 1'b0;
                                reg_write = 1'b0;
                                is_csr = 1'b0;
                            end
                        endcase
                    end
                    3'b001: begin
                        alu_op = ALU_ADD;
                        alu_src_b = 1'b0;
                        rs2 = `RegNone;
                        imm = csr_rdata;
                    end 
                    3'b010: begin
                        alu_op = ALU_OR;
                        alu_src_b = 1'b1;
                        imm = csr_rdata;
                    end 
                    3'b011: begin
                        alu_op = ALU_ANDN;
                        alu_src_b = 1'b1;
                        imm = csr_rdata;
                    end 
                    3'b101: begin
                        alu_op = ALU_ADD;
                        alu_src_b = 1'b1;
                        imm = imm_tmp;
                        rs1 = `RegNone;
                    end
                    3'b110: begin
                        alu_op = ALU_ADD;
                        alu_src_b = 1'b1;
                        imm = imm_tmp | csr_rdata;
                        rs1 = `RegNone;
                    end
                    3'b111: begin
                        alu_op = ALU_ADD;
                        alu_src_b = 1'b1;
                        imm = (~imm_tmp) & csr_rdata;
                        rs1 = `RegNone;
                    end
                    default: begin 
                        is_ii = 1'b1;
                        alu_op = ALU_NULL;
                    end
                endcase
            end

            default: begin
                is_ii = 1'b1;
                alu_op = ALU_NULL;
                alu_src_b = 1'b0;
                reg_write = 1'b0;
                is_32bit = 1'b0;
                imm = imm_tmp;
            end
        endcase
    end

    id_ex id_ex_next;

    always_comb begin
        id_ex_next = '0;
        if (!stall && !branch_taken && if_id_in.valid) begin
            id_ex_next.pc = if_id_in.pc;
            id_ex_next.rs1_data = rs1_data_in;
            id_ex_next.rs2_data = rs2_data_in;
            id_ex_next.imm = imm;
            id_ex_next.rd = rd;
            id_ex_next.rs1 = rs1;
            id_ex_next.rs2 = rs2;
            id_ex_next.alu_op = alu_op;
            id_ex_next.branch_type = funct3;
            id_ex_next.alu_src_a = 1'b0;
            id_ex_next.alu_src_b = alu_src_b;
            id_ex_next.reg_write = reg_write;
            id_ex_next.is_32bit = is_32bit;
            id_ex_next.is_load = is_load;
            id_ex_next.is_branch = is_branch;
            id_ex_next.is_jal = is_jal;
            id_ex_next.is_jalr = is_jalr;
            id_ex_next.inst = if_id_in.inst;
            id_ex_next.valid = 1'b1;
            id_ex_next.store_pc = store_pc;
            id_ex_next.is_csr = is_csr;
            id_ex_next.csr_addr = csr_raddr;
            id_ex_next.csr_data = csr_rdata;
            id_ex_next.is_ecall = is_ecall;
            id_ex_next.is_mret = is_mret;
            id_ex_next.is_ii = is_ii;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            id_ex_out <= '0;
        end else if (step) begin
            if (stall) begin
                
            end else begin
                id_ex_out.pc <= id_ex_next.pc;
                id_ex_out.rs1_data <= id_ex_next.rs1_data;
                id_ex_out.rs2_data <= id_ex_next.rs2_data;
                id_ex_out.imm <= id_ex_next.imm;
                id_ex_out.rd <= id_ex_next.rd;
                id_ex_out.rs1 <= id_ex_next.rs1;
                id_ex_out.rs2 <= id_ex_next.rs2;
                id_ex_out.alu_op <= id_ex_next.alu_op;
                id_ex_out.branch_type <= id_ex_next.branch_type;
                id_ex_out.alu_src_a <= id_ex_next.alu_src_a;
                id_ex_out.alu_src_b <= id_ex_next.alu_src_b;
                id_ex_out.reg_write <= id_ex_next.reg_write;
                id_ex_out.is_32bit <= id_ex_next.is_32bit;
                id_ex_out.is_load <= id_ex_next.is_load;
                id_ex_out.is_branch <= id_ex_next.is_branch;
                id_ex_out.is_jal <= id_ex_next.is_jal;
                id_ex_out.is_jalr <= id_ex_next.is_jalr;
                id_ex_out.inst <= id_ex_next.inst;
                id_ex_out.valid <= (~branch_taken & ~exception_taken);
                id_ex_out.store_pc <= id_ex_next.store_pc;
                id_ex_out.is_csr <= id_ex_next.is_csr;
                id_ex_out.csr_addr <= id_ex_next.csr_addr;
                id_ex_out.csr_data <= id_ex_next.csr_data;
                id_ex_out.is_ecall <= id_ex_next.is_ecall;
                id_ex_out.is_mret <= id_ex_next.is_mret;
                id_ex_out.is_ii <= id_ex_next.is_ii;
            end
        end
    end

    assign decode_ok = 1'b1;

endmodule