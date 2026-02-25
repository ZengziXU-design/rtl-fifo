`timescale 1ns/1ps

module fifo_sync_tb;

  localparam int N_bit = 8;
  localparam int DEPTH = 16;

  logic clk;
  logic reset;

  logic wr_en;
  logic [N_bit-1:0] wdata_i;

  logic rd_en;
  logic [N_bit-1:0] rdata_o;

  logic empty;
  logic full;
  logic [$clog2(DEPTH):0] count;

  // DUT
  fifo_sync #(
    .N_bit(N_bit),
    .DEPTH(DEPTH)
  ) dut (
    .clk(clk),
    .reset(reset),
    .wr_en(wr_en),
    .wdata_i(wdata_i),
    .rd_en(rd_en),
    .rdata_o(rdata_o),
    .empty(empty),
    .full(full),
    .count(count)
  );

  // clock: 100MHz
  initial clk = 0;
  always #5 clk = ~clk;

  // reset + init
  initial begin
    reset   = 1;
    wr_en   = 0;
    rd_en   = 0;
    wdata_i = 0;

    repeat (3) @(posedge clk);
    reset = 0;
  end

  // simple "push": only pushes when not full
  // Drive on negedge so signals are stable before DUT samples at posedge.
  task automatic push(input logic [N_bit-1:0] data);
    begin
      while (full) @(posedge clk);

      @(negedge clk);
      wdata_i = data;
      wr_en   = 1;
      rd_en   = 0;

      @(negedge clk);
      wr_en   = 0;
      wdata_i = 0;
    end
  endtask

  // simple "pop": only pops when not empty
  // Drive on negedge; sample rdata_o after the posedge that performs the read.
  task automatic pop(output logic [N_bit-1:0] data);
    begin
      while (empty) @(posedge clk);

      @(negedge clk);
      rd_en = 1;
      wr_en = 0;

      @(negedge clk);
      rd_en = 0;

      // rdata_o updates on the posedge where do_rd is true
      @(posedge clk);
      data = rdata_o;
    end
  endtask

  logic [N_bit-1:0] exp;
  logic [N_bit-1:0] got;

  initial begin
    // wait until reset deasserted
    wait(reset == 0);
    @(posedge clk);

    // 1) basic: write 8 bytes, then read back and compare
    for (int i = 0; i < 8; i++) begin
      push(i + 8'h10);
    end

    for (int i = 0; i < 8; i++) begin
      pop(got);
      exp = i + 8'h10;
      if (got !== exp) begin
        $display("[FAIL] basic readback mismatch: exp=%0h got=%0h at time %0t", exp, got, $time);
        $finish;
      end
    end
    $display("[PASS] basic write/read test");

    // 2) small interleaving test
    // push 4
    for (int i = 0; i < 4; i++) push(i + 8'hA0);
    // pop 2
    for (int i = 0; i < 2; i++) begin
      pop(got);
      exp = i + 8'hA0;
      if (got !== exp) begin
        $display("[FAIL] interleave mismatch: exp=%0h got=%0h at time %0t", exp, got, $time);
        $finish;
      end
    end
    // push 4 more
    for (int i = 4; i < 8; i++) push(i + 8'hA0);
    // pop remaining 6 (from A0..A7, but already popped A0,A1)
    for (int i = 2; i < 8; i++) begin
      pop(got);
      exp = i + 8'hA0;
      if (got !== exp) begin
        $display("[FAIL] interleave mismatch2: exp=%0h got=%0h at time %0t", exp, got, $time);
        $finish;
      end
    end
    $display("[PASS] interleaving test");

    $display("All tests passed.");
    $finish;
  end

  initial begin
    $dumpfile("fifo_sync_tb.vcd");
    $dumpvars(0, fifo_sync_tb);
  end

endmodule