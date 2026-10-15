/**
 * This file implements the logic of the MEM stage
 */

module mem
import common::*;
import pipeline_def::*;
(
    input logic clk, rst,
    input logic step,
    input logic stall,
    input ex_mem ex_mem_in,
    output mem_wb mem_wb_out,
    output dbus_req_t dbus_req,
    input dbus_resp_t dbus_resp,
    output logic mem_ok
);

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [2:0] addr_offset;

    assign opcode = ex_mem_in.inst[6:0];
    assign funct3 = ex_mem_in.inst[14:12];
    assign addr_offset = ex_mem_in.alu_result[2:0];

    msize_t store_size;
    always_comb begin
        case (funct3)
            3'b000: store_size = MSIZE1;
            3'b001: store_size = MSIZE2;
            3'b010: store_size = MSIZE4;
            3'b011: store_size = MSIZE8;
            default: store_size = MSIZE1;
        endcase
    end

    msize_t load_size;
    always_comb begin
        case (funct3)
            3'b000, 3'b100: load_size = MSIZE1;
            3'b001, 3'b101: load_size = MSIZE2;
            3'b010, 3'b110: load_size = MSIZE4;
            3'b011:         load_size = MSIZE8;
            default:        load_size = MSIZE1;
        endcase
    end

    u64 load_data_comb;
    logic [63:0] raw_data;
    
    always_comb begin
        case (funct3)
            3'b000, 3'b100: raw_data = {{56{1'b0}}, dbus_resp.data[addr_offset*8 +: 8]};
            3'b001, 3'b101: raw_data = {{48{1'b0}}, dbus_resp.data[addr_offset*8 +: 16]};
            3'b010, 3'b110: raw_data = {{32{1'b0}}, dbus_resp.data[addr_offset*8 +: 32]};
            3'b011:         raw_data = dbus_resp.data[addr_offset*8 +: 64];
            default:        raw_data = dbus_resp.data;
        endcase
        
        case (funct3)
            3'b000: load_data_comb = {{56{raw_data[7]}}, raw_data[7:0]};
            3'b001: load_data_comb = {{48{raw_data[15]}}, raw_data[15:0]};
            3'b010: load_data_comb = {{32{raw_data[31]}}, raw_data[31:0]};
            3'b011: load_data_comb = raw_data;
            3'b100: load_data_comb = {56'b0, raw_data[7:0]};
            3'b101: load_data_comb = {48'b0, raw_data[15:0]};
            3'b110: load_data_comb = {32'b0, raw_data[31:0]};
            default: load_data_comb = dbus_resp.data;
        endcase
    end

    u64 aligned_data_comb;
    strobe_t strobe_mask_comb;
    always_comb begin
        case (funct3)
            3'b000: begin
                aligned_data_comb = {56'b0, ex_mem_in.store_data[7:0]} << (addr_offset * 8);
                strobe_mask_comb = 8'b1 << addr_offset;
            end
            3'b001: begin
                aligned_data_comb = {48'b0, ex_mem_in.store_data[15:0]} << (addr_offset * 8);
                strobe_mask_comb = 8'b11 << addr_offset;
            end
            3'b010: begin
                aligned_data_comb = {32'b0, ex_mem_in.store_data[31:0]} << (addr_offset * 8);
                strobe_mask_comb = 8'b1111 << addr_offset;
            end
            3'b011: begin
                aligned_data_comb = ex_mem_in.store_data[63:0] << (addr_offset * 8);
                strobe_mask_comb = 8'b11111111;
            end
            default: begin
                aligned_data_comb = 64'b0;
                strobe_mask_comb = 8'b0;
            end
        endcase
    end

    u64 result;
    logic mem;
    u64 mem_addr;
    always_ff @ (posedge clk) begin
        if (rst == `Enable) begin
            mem <= 1'b0;
            result <= 64'b0;
            mem_ok <= `Enable;
            dbus_req.valid <= `Disable;
            mem_addr <= PCINIT;
            mem_wb_out <= '0;
        end else begin
            if (ex_mem_in.valid && mem_ok && ex_mem_in.pc != mem_wb_out.pc) begin
                result <= ex_mem_in.alu_result;

                case (opcode)
                    7'b0000011: begin
                        dbus_req.valid <= `Enable;
                        dbus_req.addr <= ex_mem_in.alu_result;
                        dbus_req.size <= load_size;
                        dbus_req.strobe <= 8'b0;
                        dbus_req.data <= 64'b0;
                        mem <= 1'b1;
                        mem_addr <= ex_mem_in.alu_result;
                        mem_ok <= `Disable;
                    end

                    7'b0100011: begin
                        dbus_req.valid <= `Enable;
                        dbus_req.addr <= ex_mem_in.alu_result;
                        dbus_req.size <= store_size;
                        dbus_req.data <= aligned_data_comb;
                        dbus_req.strobe <= strobe_mask_comb;
                        mem <= 1'b1;
                        mem_addr <= ex_mem_in.alu_result;
                        mem_ok <= `Disable;
                    end

                    default: begin
                        dbus_req.valid <= `Disable;
                        dbus_req.addr <= PCINIT;
                        dbus_req.strobe <= 8'b0;
                        mem <= 1'b0;
                        mem_addr <= PCINIT;

                        mem_wb_out.pc <= ex_mem_in.pc;
                        mem_wb_out.rd <= ex_mem_in.rd;
                        mem_wb_out.reg_write <= ex_mem_in.reg_write;
                        mem_wb_out.inst <= ex_mem_in.inst;
                        mem_wb_out.alu_result <= ex_mem_in.alu_result;
                        mem_wb_out.ret_addr <= ex_mem_in.ret_addr;
                        mem_wb_out.valid <= ex_mem_in.valid;
                        mem_wb_out.mem <= 1'b0;
                        mem_wb_out.mem_addr <= PCINIT;
                        mem_wb_out.is_csr <= ex_mem_in.is_csr;
                        mem_wb_out.csr_addr <= ex_mem_in.csr_addr;
                        mem_wb_out.csr_data <= ex_mem_in.csr_data;
                        mem_wb_out.current_priv <= ex_mem_in.current_priv;
                    end

                endcase
            end else begin
                if (mem_ok) begin

                end else if (dbus_resp.addr_ok && dbus_resp.data_ok) begin
                    mem_ok <= `Enable;
                    dbus_req.valid <= `Disable;

                    mem_wb_out.pc <= ex_mem_in.pc;
                    mem_wb_out.rd <= ex_mem_in.rd;
                    mem_wb_out.reg_write <= ex_mem_in.reg_write;
                    mem_wb_out.inst <= ex_mem_in.inst;
                    mem_wb_out.ret_addr <= ex_mem_in.ret_addr;
                    mem_wb_out.valid <= ex_mem_in.valid;
                    mem_wb_out.mem <= mem;
                    mem_wb_out.mem_addr <= mem_addr;
                    mem_wb_out.is_csr <= ex_mem_in.is_csr;
                    mem_wb_out.csr_addr <= ex_mem_in.csr_addr;
                    mem_wb_out.csr_data <= ex_mem_in.csr_data;
                    mem_wb_out.exception_taken <= ex_mem_in.exception_taken;
                    mem_wb_out.next_mepc <= ex_mem_in.next_mepc;
                    mem_wb_out.next_mcause <= ex_mem_in.next_mcause;
                    mem_wb_out.is_mret <= ex_mem_in.is_mret;
                    mem_wb_out.current_priv <= ex_mem_in.current_priv;

                    if (opcode == 7'b0000011) begin
                        mem_wb_out.alu_result <= load_data_comb;
                    end else begin
                        mem_wb_out.alu_result <= result;
                    end
                end
            end
        end
    end

endmodule