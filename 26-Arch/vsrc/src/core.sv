`ifndef __CORE_SV
`define __CORE_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "src/pipeline/pipeline_top.sv"
`endif

module core import common::*;(
	input  logic       clk, reset,
	output ibus_req_t  ireq,
	input  ibus_resp_t iresp,
	output dbus_req_t  dreq,
	input  dbus_resp_t dresp,
	input  logic       trint, swint, exint,
	output u2          core_priv,
	output u64         core_satp,
	input  logic       skip_mem
);

	u64 [31:0] gpr;
	logic commit_valid;
	u64 commit_pc;
	u32 commit_instr;
	logic commit_wen;
	u5 commit_wdest;
	u64 commit_wdata;
	logic commit_mem;
	u64 commit_mem_addr;

    u64 commit_mstatus;
    u64 commit_mtvec;
    u64 commit_mip;
    u64 commit_mie;
    u64 commit_mscratch;
    u64 commit_mcause;
    u64 commit_mtval;
    u64 commit_mepc;
    u64 commit_mcycle;
    u64 commit_mhartid;
    u64 commit_satp;
    u64 commit_sstatus;

	u2 commit_priv;

	pipeline_top u_pipeline_top(
		.clk(clk),
		.rst(reset),
		.trint(trint),
		.swint(swint),
		.exint(exint),
		.iresp(iresp),
		.ireq(ireq),
		.dresp(dresp),
		.dreq(dreq),
		.gpr_out(gpr),
		.commit_valid(commit_valid),
		.commit_pc(commit_pc),
		.commit_instr(commit_instr),
		.commit_wen(commit_wen),
		.commit_wdest(commit_wdest),
		.commit_wdata(commit_wdata),
		.commit_mem(commit_mem),
		.commit_mem_addr(commit_mem_addr),
		.commit_mstatus(commit_mstatus),
		.commit_mtvec(commit_mtvec),
		.commit_mip(commit_mip),
		.commit_mie(commit_mie),
		.commit_mscratch(commit_mscratch),
		.commit_mcause(commit_mcause),
		.commit_mtval(commit_mtval),
		.commit_mepc(commit_mepc),
		.commit_mcycle(commit_mcycle),
		.commit_mhartid(commit_mhartid),
		.commit_satp(commit_satp),
		.commit_sstatus(commit_sstatus),
		.commit_priv(commit_priv),
		.core_priv(core_priv)
	);

    assign core_satp = commit_satp;

`ifdef VERILATOR
	DifftestInstrCommit DifftestInstrCommit(
		.clock              (clk),
		.coreid             (commit_mhartid[7:0]),
		.index              (0),
		.valid              (commit_valid),
		.pc                 (commit_pc),
		.instr              (commit_instr),
		.skip               ((commit_mem & commit_mem_addr[31] == 0)),
		.isRVC              (0),
		.scFailed           (0),
		.wen                (commit_wen),
		.wdest              ({3'b0, commit_wdest}),
		.wdata              (commit_wdata)
	);

	DifftestArchIntRegState DifftestArchIntRegState (
		.clock              (clk),
		.coreid             (commit_mhartid[7:0]),
		.gpr_0              (gpr[0]),
		.gpr_1              (gpr[1]),
		.gpr_2              (gpr[2]),
		.gpr_3              (gpr[3]),
		.gpr_4              (gpr[4]),
		.gpr_5              (gpr[5]),
		.gpr_6              (gpr[6]),
		.gpr_7              (gpr[7]),
		.gpr_8              (gpr[8]),
		.gpr_9              (gpr[9]),
		.gpr_10             (gpr[10]),
		.gpr_11             (gpr[11]),
		.gpr_12             (gpr[12]),
		.gpr_13             (gpr[13]),
		.gpr_14             (gpr[14]),
		.gpr_15             (gpr[15]),
		.gpr_16             (gpr[16]),
		.gpr_17             (gpr[17]),
		.gpr_18             (gpr[18]),
		.gpr_19             (gpr[19]),
		.gpr_20             (gpr[20]),
		.gpr_21             (gpr[21]),
		.gpr_22             (gpr[22]),
		.gpr_23             (gpr[23]),
		.gpr_24             (gpr[24]),
		.gpr_25             (gpr[25]),
		.gpr_26             (gpr[26]),
		.gpr_27             (gpr[27]),
		.gpr_28             (gpr[28]),
		.gpr_29             (gpr[29]),
		.gpr_30             (gpr[30]),
		.gpr_31             (gpr[31])
	);

    DifftestTrapEvent DifftestTrapEvent(
		.clock              (clk),
		.coreid             (commit_mhartid[7:0]),
		.valid              (0),
		.code               (0),
		.pc                 (0),
		.cycleCnt           (0),
		.instrCnt           (0)
	);

	DifftestCSRState DifftestCSRState(
		.clock              (clk),
		.coreid             (commit_mhartid[7:0]),
		.priviledgeMode     (commit_priv),
		.mstatus            (commit_mstatus),
		.sstatus            (commit_sstatus),
		.mepc               (commit_mepc),
		.sepc               (0),
		.mtval              (commit_mtval),
		.stval              (0),
		.mtvec              (commit_mtvec),
		.stvec              (0),
		.mcause             (commit_mcause),
		.scause             (0),
		.satp               (commit_satp),
		.mip                (commit_mip),
		.mie                (commit_mie),
		.mscratch           (commit_mscratch),
		.sscratch           (0),
		.mideleg            (0),
		.medeleg            (0)
	);
`endif
endmodule
`endif