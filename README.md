# RTL FIFO (Synchronous and Asynchronous)

## Run Simulation (Icarus Verilog)

```bash
git clone https://github.com/ZengziXU-design/rtl-fifo.git
cd rtl-fifo
mkdir build
cd build
iverilog -g2012 -o simv-sync ../fifo_sync.v ../fifo_tb.v
vvp simv-sync
iverilog -g2012 -o simv-async ../fifo_sync.v ../fifo_async_tb.v
vvp simv-async
```
