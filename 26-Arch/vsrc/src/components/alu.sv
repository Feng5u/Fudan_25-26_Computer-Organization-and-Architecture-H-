/**
 * This file implements the ALU.
 */

module alu
import common::*;
import pipeline_def::*;
(
    input logic clk,
    input u64 src_a,
    input u64 src_b,
    input alu_op_t alu_op,
    input logic is_32bit,
    output u64 result,
    output logic alu_stall
);

    u64 raw_result;
    u32 result_32bit;

    logic mul_valid, div_valid;
    logic mul_done, div_done;
    u64 mul_result;
    u128 div_result;
    u64 abs_src_a, abs_src_b;

    assign alu_stall = (mul_valid & ~mul_done) || (div_valid & ~div_done);

    always_comb begin
        mul_valid = 0;
        div_valid = 0;
        abs_src_a = src_a;
        abs_src_b = src_b;
        case (alu_op)
            ALU_ADD: raw_result = src_a + src_b;
            ALU_SUB: raw_result = src_a - src_b;
            ALU_AND: raw_result = src_a & src_b;
            ALU_OR: raw_result = src_a | src_b;
            ALU_XOR: raw_result = src_a ^ src_b;
            ALU_SLL: raw_result = src_a << src_b[4:0];
            ALU_SRL: raw_result = {32'b0, src_a[31:0]} >> src_b[4:0];
            ALU_SRA: raw_result = src_a >>> src_b[4:0];
            ALU_SLT: raw_result = ($signed(src_a) < $signed(src_b)) ? 64'b1 : 64'b0;
            ALU_SLTU: raw_result = (src_a < src_b) ? 64'b1 : 64'b0;
            ALU_SLLI: raw_result = src_a << src_b[5:0];
            ALU_SRLI: raw_result = src_a >> src_b[5:0];
            ALU_BRANCH: raw_result = (src_a + src_b) & ~1;
            ALU_SRAI: raw_result = src_a >>> src_b[5:0];
            ALU_ANDN: raw_result = (~src_a) & src_b;
            ALU_MUL: begin
                mul_valid = 1;
                raw_result = mul_result;
            end
            ALU_DIV: begin
                if ($signed(src_a) < 0) abs_src_a = ~src_a + 1'b1;
                if ($signed(src_b) < 0) begin
                    div_valid = 1;
                    abs_src_b = ~src_b + 1'b1;
                    raw_result = (src_a[63] ^ src_b[63]) ? (~div_result[63:0] + 1'b1) : div_result[63:0];
                end else if ($signed(src_b) > 0) begin
                    div_valid = 1;
                    raw_result = (src_a[63] ^ src_b[63]) ? (~div_result[63:0] + 1'b1) : div_result[63:0];
                end else begin
                    div_valid = 0;
                    raw_result = '1;
                end
            end
            ALU_DIVU: begin
                if (src_b == '0) begin
                    div_valid = 0;
                    raw_result = '1;
                end else begin
                    div_valid = 1;
                    raw_result = div_result[63:0];
                end
            end
            ALU_REM: begin
                if ($signed(src_a) < 0) abs_src_a = ~src_a + 1'b1;
                if ($signed(src_b) < 0) begin
                    div_valid = 1;
                    abs_src_b = ~src_b + 1'b1;
                    raw_result = (src_a[63]) ? (~div_result[127:64] + 1'b1) : div_result[127:64];
                end else if ($signed(src_b) > 0) begin
                    div_valid = 1;
                    raw_result = (src_a[63]) ? (~div_result[127:64] + 1'b1) : div_result[127:64];
                end else begin
                    div_valid = 0;
                    raw_result = src_a;
                end
            end
            ALU_REMU: begin
                if (src_b == '0) begin
                    div_valid = 0;
                    raw_result = src_a;
                end else begin
                    div_valid = 1;
                    raw_result = div_result[127:64];
                end
            end
            ALU_MULW: begin
                mul_valid = 1;
                raw_result = mul_result;
            end
            ALU_DIVW: begin
                if ($signed(src_a[31:0]) < 0) abs_src_a = {32'b0, ~src_a[31:0] + 1'b1};
                else abs_src_a = {32'b0, src_a[31:0]};
                if ($signed(src_b[31:0]) < 0) begin
                    abs_src_b = {32'b0, ~src_b[31:0] + 1'b1};
                    div_valid = 1;
                    raw_result[31:0] = (src_a[31] ^ src_b[31]) ? (~div_result[31:0] + 1'b1) : div_result[31:0];
                end else if ($signed(src_b[31:0]) > 0) begin
                    abs_src_b = {32'b0, src_b[31:0]};
                    div_valid = 1;
                    raw_result[31:0] = (src_a[31] ^ src_b[31]) ? (~div_result[31:0] + 1'b1) : div_result[31:0];
                end else begin
                    div_valid = 0;
                    raw_result = '1;
                end
            end
            ALU_DIVUW: begin
                abs_src_a = {32'b0, src_a[31:0]};
                abs_src_b = {32'b0, src_b[31:0]};
                if (src_b == '0) begin
                    div_valid = 0;
                    raw_result = '1;
                end else begin
                    div_valid = 1;
                    raw_result[31:0] = div_result[31:0];
                end
            end
            ALU_REMW: begin
                if ($signed(src_a[31:0]) < 0) abs_src_a = {32'b0, ~src_a[31:0] + 1'b1};
                else abs_src_a = {32'b0, src_a[31:0]};
                if ($signed(src_b[31:0]) < 0) begin
                    abs_src_b = {32'b0, ~src_b[31:0] + 1'b1};
                    div_valid = 1;
                    raw_result[31:0] = (src_a[31]) ? (~div_result[95:64] + 1'b1) : div_result[95:64];
                end else if ($signed(src_b[31:0]) > 0) begin
                    abs_src_b = {32'b0, src_b[31:0]};
                    div_valid = 1;
                    raw_result[31:0] = (src_a[31]) ? (~div_result[95:64] + 1'b1) : div_result[95:64];
                end else begin
                    div_valid = 0;
                    raw_result[31:0] = src_a[31:0];
                end
            end
            ALU_REMUW: begin
                abs_src_a = {32'b0, src_a[31:0]};
                abs_src_b = {32'b0, src_b[31:0]};
                if (src_b == '0) begin
                    div_valid = 0;
                    raw_result[31:0] = src_a[31:0];
                end else begin
                    div_valid = 1;
                    raw_result[31:0] = div_result[95:64];
                end
            end
            default: raw_result = 64'b0;
        endcase
    end

    divid u_divid(
        .clk(clk),
        .rst(div_valid),
        .valid(div_valid),
        .a(abs_src_a),
        .b(abs_src_b),
        .done(div_done),
        .c(div_result)
    );

    mult u_mult(
        .clk(clk),
        .rst(mul_valid),
        .valid(mul_valid),
        .a(src_a),
        .b(src_b),
        .done(mul_done),
        .c(mul_result)
    );

    always_comb begin
        if (is_32bit) begin
            result_32bit = raw_result[31:0];
            result = {{32{result_32bit[31]}}, result_32bit};
        end else begin
            result = raw_result;
            result_32bit = 32'b0;
        end
    end

endmodule