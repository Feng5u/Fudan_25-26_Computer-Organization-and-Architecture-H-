module IF
import common::*;
import pipeline_def::*;
(
    input logic clk, rst,
    input logic step,
    input logic stall,
    input logic exception_taken,
    input logic branch_taken,
    input u64 branch_target,
    output logic fetch_ok,
    output if_id if_id_out,
    output ibus_req_t ibus_req,
    input ibus_resp_t ibus_resp
);

    u64 pc;
    if_id if_id_next;

    always_ff @ (posedge clk) begin
        if (rst == `Enable) begin
            pc <= PCINIT;
            fetch_ok <= `Enable;
            ibus_req.valid <= `Disable;
            ibus_req.addr <= '0;
            if_id_out <= '0;
            if_id_next <= '0;
        end else begin
            if (branch_taken || exception_taken) begin
                fetch_ok <= `Enable;
                pc <= branch_target;
                ibus_req.valid <= `Enable;
                ibus_req.addr <= branch_target;
                if_id_out <= '0;
                if_id_next <= '0;
            end else if (stall) begin
                fetch_ok <= `Enable;
                if_id_out <= '0;
            end else if (step) begin
                if_id_out <= if_id_next;
                if_id_next.valid <= `Enable;
                ibus_req.valid <= `Enable;
                ibus_req.addr <= pc;
                fetch_ok <= `Disable;
            end else begin
                if (fetch_ok) begin
                    
                end else if (ibus_resp.data_ok && ibus_resp.addr_ok) begin
                    if_id_next.pc <= pc;
                    if_id_next.inst <= ibus_resp.data;
                    if_id_next.valid <= branch_taken ? 1'b0 : 1'b1;
                    fetch_ok <= `Enable;
                    ibus_req.valid <= `Disable;
                    pc <= stall ? pc : (pc + 4);
                end
            end
        end
    end

endmodule