# RTL FIFO (Synchronous Reset)

A simple **single-clock FIFO** with **synchronous active-high reset**.

## Run Simulation (Icarus Verilog)

```bash
git clone https://github.com/ZengziXU-design/rtl-fifo.git
cd rtl-fifo
iverilog -g2012 -o simv fifo.v fifo_tb.v
vvp simv
