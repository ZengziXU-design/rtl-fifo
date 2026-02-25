This is a verilog RTL practice code.

# RTL FIFO (Synchronous Reset)

A simple **single-clock FIFO** with **synchronous active-high reset**.

## Top Module

```verilog
module fifo_sync #(
  parameter int N_bit  = 8,
  parameter int DEPTH  = 16
)(
  input  logic               clk,
  input  logic               reset,   // synchronous active-high reset

  input  logic               wr_en,
  input  logic [N_bit-1:0]   wdata_i,
  input  logic               rd_en,
  output logic [N_bit-1:0]   rdata_o,

  output logic               empty,
  output logic               full,
  output logic [$clog2(DEPTH):0] count // 0..DEPTH
);

git clone https://github.com/ZengziXU-design/rtl-fifo.git
cd rtl-fifo
iverilog -g2012 -o simv fifo.v fifo_tb.v
vvp simv
