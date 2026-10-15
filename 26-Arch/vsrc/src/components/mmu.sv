`ifndef __MMU_SV
`define __MMU_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/csr.sv"
`endif

module mmu
import common::*;
import csr_pkg::*;
(
    input logic clk,
    input logic rst,

    input cbus_req_t req_in,
    output cbus_req_t req_out,
    input cbus_resp_t resp_in,
    output cbus_resp_t resp_out,

    input word_t satp,
    input logic [1:0] cur_priv
);
    logic [63:0] data_temp;

    function automatic logic check_pte_valid(logic [63:0] pte, logic is_leaf);
        if (!pte[0]) return 0;
        return is_leaf ? (|pte[3:1]) : (~|pte[3:1]);
    endfunction

    typedef enum {
        FLUSH,
        IDLE,
        PTE0,
        PTE1,
        PTE2,
        PHY
    } mmu_state;

    mmu_state state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            data_temp <= 0;
        end else begin
            case (state)
                FLUSH: begin
                    state <= IDLE;
                    resp_out.last <= 0;
                    resp_out.ready <= 0;
                    resp_out.data <= 0;
                    data_temp <= 0;
                end

                IDLE: if (req_in.valid) begin
                    if (cur_priv == 2'b11) begin
                        state <= PHY;
                        req_out.valid <= req_in.valid;
                        req_out.is_write <= req_in.is_write;
                        req_out.size <= req_in.size;
                        req_out.addr <= req_in.addr;
                        req_out.strobe <= req_in.strobe;
                        req_out.data <= req_in.data;
                        req_out.len <= req_in.len;
                        req_out.burst <= req_in.burst;
                    end else if(satp[63:60] == 4'b1000) begin
                        state <= PTE2;
                        req_out.valid <= req_in.valid;
                        req_out.is_write <= 0;
                        req_out.size <= MSIZE8;
                        req_out.addr <= {8'b0, satp[43:0], req_in.addr[38:30], 3'b0};
                        req_out.strobe <= 0;
                        req_out.data <= req_in.data;
                        req_out.len <= req_in.len;
                        req_out.burst <= req_in.burst;
                    end else begin
                        state <= PHY;
                        req_out.valid <= req_in.valid;
                        req_out.is_write <= req_in.is_write;
                        req_out.size <= req_in.size;
                        req_out.addr <= req_in.addr;
                        req_out.strobe <= req_in.strobe;
                        req_out.data <= req_in.data;
                        req_out.len <= req_in.len;
                        req_out.burst <= req_in.burst;
                    end
                end

                PTE2: if (resp_in.last && resp_in.ready) begin
                    if (resp_in.data != data_temp) begin
                        if (!check_pte_valid(resp_in.data, 1'b0)) begin
                            state <= FLUSH;
                        end else begin
                            state <= PTE1;
                            req_out.valid <= req_in.valid;
                            req_out.is_write <= 0;
                            req_out.size <= MSIZE8;
                            req_out.addr <= {8'b0, resp_in.data[53:10], req_in.addr[29:21], 3'b0};
                            req_out.strobe <= 0;
                            req_out.data <= req_in.data;
                            req_out.len <= req_in.len;
                            req_out.burst <= req_in.burst;
                            data_temp <= resp_in.data;
                        end
                    end
                end

                PTE1: if (resp_in.last && resp_in.ready) begin
                    if (resp_in.data != data_temp) begin
                        if (!check_pte_valid(resp_in.data, 1'b0)) begin
                            state <= FLUSH;
                        end else begin
                            state <= PTE0;
                            req_out.valid <= req_in.valid;
                            req_out.is_write <= 0;
                            req_out.size <= MSIZE8;
                            req_out.addr <= {8'b0, resp_in.data[53:10], req_in.addr[20:12], 3'b0};
                            req_out.strobe <= 0;
                            req_out.data <= req_in.data;
                            req_out.len <= req_in.len;
                            req_out.burst <= req_in.burst;
                            data_temp <= resp_in.data;
                        end
                    end
                end

                PTE0: if (resp_in.last && resp_in.ready) begin
                    if (resp_in.data != data_temp) begin
                        if (!check_pte_valid(resp_in.data, 1'b1)) begin
                            state <= FLUSH;
                        end else begin
                            state <= PHY;
                            req_out.valid <= req_in.valid;
                            req_out.is_write <= req_in.is_write;
                            req_out.size <= req_in.size;
                            req_out.addr <= {8'b0, resp_in.data[53:10], req_in.addr[11:0]};
                            req_out.strobe <= req_in.strobe;
                            req_out.data <= req_in.data;
                            req_out.len <= req_in.len;
                            req_out.burst <= req_in.burst;
                            data_temp <= resp_in.data;
                        end
                    end
                end

                PHY: if (resp_in.last && resp_in.ready) begin
                    if(cur_priv == 2'b00 && satp[63:60] == 4'b1000) begin
                        if(resp_in.data != data_temp) begin
                            state <= FLUSH;
                            req_out.valid <= 0;
                            resp_out.last <= resp_in.last;
                            resp_out.ready <= resp_in.ready;
                            resp_out.data <= resp_in.data;
                        end
                    end else begin
                        state <= FLUSH;
                        req_out.valid <= 0;
                        resp_out.last <= resp_in.last;
                        resp_out.ready <= resp_in.ready;
                        resp_out.data <= resp_in.data;
                        
                    end
                end
            endcase
        end
    end

endmodule

`endif