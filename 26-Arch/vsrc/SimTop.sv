`ifdef VERILATOR
`include "include/common.sv"
`include "src/core.sv"
`include "src/components/mmu.sv"
`include "util/IBusToCBus.sv"
`include "util/DBusToCBus.sv"
`include "util/CBusArbiter.sv"

module SimTop import common::*;(
  input         clock,
  input         reset,
  input  [63:0] io_logCtrl_log_begin,
  input  [63:0] io_logCtrl_log_end,
  input  [63:0] io_logCtrl_log_level,
  input         io_perfInfo_clean,
  input         io_perfInfo_dump,
  output        io_uart_out_valid,
  output [7:0]  io_uart_out_ch,
  output        io_uart_in_valid,
  input  [7:0]  io_uart_in_ch
);

    cbus_req_t  oreq;
    cbus_resp_t oresp;
    logic trint, swint, exint;

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

    core core(
      .clk(clock), .reset, .ireq, .iresp, .dreq, .dresp, .trint, .swint, .exint,
      .core_priv(core_priv),
      .core_satp(core_satp),
      .skip_mem(skip_mem)
    );

    IBusToCBus icvt(.*);
    DBusToCBus dcvt(.*);

    cbus_req_t [1:0] arb_ireqs;
    cbus_resp_t [1:0] arb_iresps;
    assign arb_ireqs = {icreq, dcreq};

    CBusArbiter mux(
        .clk(clock), 
        .reset,
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .oreq(arb_req),
        .oresp(arb_resp)
    );

    logic skip_mem;

    mmu u_mmu(
        .clk(clock),
        .rst(reset),
        .req_in(arb_req),
        .resp_out(arb_resp),
        .req_out(oreq),
        .resp_in(oresp),
        .satp(core_satp),
        .cur_priv(core_priv)
    );

    assign skip_mem = oreq.valid & oreq.addr[31] == 1'b0;

    RAMHelper2 ram(
        .clk(clock), .reset, .oreq, .oresp, .trint, .swint, .exint
    );

    assign {io_uart_out_valid, io_uart_out_ch, io_uart_in_valid} = '0;

endmodule
`endif