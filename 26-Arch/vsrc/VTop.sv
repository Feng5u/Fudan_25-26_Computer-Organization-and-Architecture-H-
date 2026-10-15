`ifndef __VTOP_SV
`define __VTOP_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "src/core.sv"
`include "src/components/mmu.sv"
`include "util/IBusToCBus.sv"
`include "util/DBusToCBus.sv"
`include "util/CBusArbiter.sv"

`endif
module VTop 
	import common::*;(
	input logic clk, reset,

	output cbus_req_t  oreq,
	input  cbus_resp_t oresp,
	input logic trint, swint, exint
);

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;

    cbus_req_t  arb_req;
    cbus_resp_t arb_resp;

    u2 core_priv;
    u64 core_satp;
    IBusToCBus icvt(.*);

    DBusToCBus dcvt(.*);

    cbus_req_t [1:0] arb_ireqs;
    cbus_resp_t [1:0] arb_iresps;
    assign arb_ireqs = {icreq, dcreq};

    CBusArbiter mux(
        .clk(clk),
        .reset(reset),
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .oreq(arb_req),
        .oresp(arb_resp)
    );

    logic skip_mem;

    mmu u_mmu(
        .clk(clk),
        .rst(reset),
        .req_in(arb_req),
        .resp_out(arb_resp),
        .req_out(oreq),
        .resp_in(oresp),
        .satp(core_satp),
        .cur_priv(core_priv)
    );

    assign skip_mem = oreq.valid && (oreq.addr[31] == 1'b0);
    core core(.*);

	always_ff @(posedge clk) begin
		if (~reset) begin
			// $display("icreq %x, %x", icreq.valid, icreq.addr);
			// if (oreq.valid || dcreq.addr == 64'h40600004) $display("dcreq %x, %x, oreq %x, %x, dcresp %x", dcreq.addr, dcreq.valid, oreq.valid, oreq.addr, dcresp.ready);
		end
	end
	

endmodule



`endif