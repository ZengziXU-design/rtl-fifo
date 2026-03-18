`timescale 1ns/1ns

module tb_fifo_async;

  localparam int N_BIT = 8;
  localparam int DEPTH = 16;

  logic               wr_clk;
  logic               rd_clk;
  logic               wr_rst;
  logic               rd_rst;

  logic [N_BIT-1:0]   wrstream_msg;
  logic               wrstream_val;
  logic               wrstream_rdy;

  logic [N_BIT-1:0]   rdstream_msg;
  logic               rdstream_val;
  logic               rdstream_rdy;

  logic               wr_full;
  logic               rd_empty;

  // ------------------------------------------------------------
  // DUT
  // ------------------------------------------------------------
  fifo_async #(
    .N_BIT (N_BIT),
    .DEPTH (DEPTH)
  ) dut (
    .wr_clk       (wr_clk),
    .rd_clk       (rd_clk),
    .wr_rst       (wr_rst),
    .rd_rst       (rd_rst),

    .wrstream_msg (wrstream_msg),
    .wrstream_val (wrstream_val),
    .wrstream_rdy (wrstream_rdy),

    .rdstream_msg (rdstream_msg),
    .rdstream_val (rdstream_val),
    .rdstream_rdy (rdstream_rdy),

    .wr_full      (wr_full),
    .rd_empty     (rd_empty)
  );

  // ------------------------------------------------------------
  // Clock generation
  // wr_clk : 10ns period
  // rd_clk : 30ns period
  // ------------------------------------------------------------
  initial begin
    wr_clk = 1'b0;
    forever #5 wr_clk = ~wr_clk;
  end

  initial begin
    rd_clk = 1'b0;
    forever #15 rd_clk = ~rd_clk;
  end

  // ------------------------------------------------------------
  // Dump waves
  // ------------------------------------------------------------
  initial begin
    $dumpfile("fifo_async_tb.vcd");
    $dumpvars(0, tb_fifo_async);
  end

  // ------------------------------------------------------------
  // Simple reference model / scoreboard
  // ------------------------------------------------------------
  logic [N_BIT-1:0] ref_mem [0:1023];
  logic [N_BIT-1:0] exp_data;

  integer wr_idx;
  integer rd_idx;
  integer num_wr;
  integer num_rd;

  integer released;
  integer remaining;

  // Record every successful write
  always @(posedge wr_clk) begin
    if (!wr_rst && wrstream_val && wrstream_rdy) begin
      ref_mem[wr_idx] = wrstream_msg;
      wr_idx = wr_idx + 1;
      num_wr = num_wr + 1;
      $display("[%0t] WR  data = 0x%02h   total_wr = %0d", $time, wrstream_msg, num_wr);
    end
  end

  // Check every successful read
  always @(posedge rd_clk) begin
    if (!rd_rst && rdstream_val && rdstream_rdy) begin
      if (rd_idx >= wr_idx) begin
        $fatal(1, "[%0t] ERROR: read happened but reference queue is empty", $time);
      end

      exp_data = ref_mem[rd_idx];

      if (rdstream_msg !== exp_data) begin
        $fatal(1,
          "[%0t] ERROR: read mismatch, got = 0x%02h, expected = 0x%02h",
          $time, rdstream_msg, exp_data
        );
      end

      rd_idx = rd_idx + 1;
      num_rd = num_rd + 1;
      $display("[%0t] RD  data = 0x%02h   total_rd = %0d", $time, rdstream_msg, num_rd);
    end
  end

  // ------------------------------------------------------------
  // Tasks
  // ------------------------------------------------------------
  task automatic write_word(input logic [N_BIT-1:0] data);
    begin
      @(negedge wr_clk);
      wrstream_msg = data;
      wrstream_val = 1'b1;

      begin : WAIT_WR_HANDSHAKE
        forever begin
          @(posedge wr_clk);
          if (wrstream_val && wrstream_rdy) begin
            disable WAIT_WR_HANDSHAKE;
          end
        end
      end

      @(negedge wr_clk);
      wrstream_val = 1'b0;
    end
  endtask

  task automatic read_n(input integer n);
    integer cnt;
    begin
      cnt = 0;

      @(negedge rd_clk);
      rdstream_rdy = 1'b1;

      while (cnt < n) begin
        @(posedge rd_clk);
        if (rdstream_val && rdstream_rdy) begin
          cnt = cnt + 1;
        end
      end

      @(negedge rd_clk);
      rdstream_rdy = 1'b0;
    end
  endtask

  // ------------------------------------------------------------
  // Timeout
  // ------------------------------------------------------------
  initial begin
    #5000;
    $fatal(1, "TIMEOUT");
  end

  // ------------------------------------------------------------
  // Main test
  // ------------------------------------------------------------
  initial begin
    wr_rst       = 1'b1;
    rd_rst       = 1'b1;
    wrstream_msg = '0;
    wrstream_val = 1'b0;
    rdstream_rdy = 1'b0;

    wr_idx       = 0;
    rd_idx       = 0;
    num_wr       = 0;
    num_rd       = 0;
    released     = 0;
    remaining    = 0;
    exp_data     = '0;

    // Reset
    repeat (4) @(posedge wr_clk);
    repeat (2) @(posedge rd_clk);

    wr_rst = 1'b0;
    rd_rst = 1'b0;

    // Give CDC synchronizers some time
    repeat (2) @(posedge wr_clk);
    repeat (2) @(posedge rd_clk);

    // --------------------------------------------------------
    // Phase 1: write 6 words, then read 6 words
    // --------------------------------------------------------
    $display("\n================ Phase 1: write 6, read 6 ================\n");

    write_word(8'h00);
    write_word(8'h01);
    write_word(8'h02);
    write_word(8'h03);
    write_word(8'h04);
    write_word(8'h05);

    read_n(6);

    repeat (2) @(posedge rd_clk);
    #1;
    if (rd_empty !== 1'b1) begin
      $fatal(1, "[%0t] ERROR: FIFO should be empty after phase 1", $time);
    end

    // --------------------------------------------------------
    // Phase 2: fill FIFO to full
    // --------------------------------------------------------
    $display("\n================ Phase 2: fill FIFO =======================\n");

    for (integer i = 0; i < DEPTH; i = i + 1) begin
      write_word(8'h80 + i[7:0]);
    end

    @(posedge wr_clk);
    #1;
    if (wr_full !== 1'b1) begin
      $fatal(1, "[%0t] ERROR: FIFO should be full after phase 2", $time);
    end

    // --------------------------------------------------------
    // Phase 3: try one extra write while full
    // it should be blocked first, then accepted after some reads
    // --------------------------------------------------------
    $display("\n================ Phase 3: extra write under full ==========\n");

    @(negedge wr_clk);
    wrstream_msg = 8'hF0;
    wrstream_val = 1'b1;

    // While FIFO is still full, wrstream_rdy should stay low
    repeat (3) begin
      @(posedge wr_clk);
      #1;
      if (wrstream_rdy !== 1'b0) begin
        $fatal(1, "[%0t] ERROR: wrstream_rdy should be 0 while FIFO is full", $time);
      end
    end

    released = 0;

    fork
      begin
        // start reading 4 entries to make room
        read_n(4);
      end

      begin : WAIT_EXTRA_ACCEPT
        repeat (20) begin
          @(posedge wr_clk);
          if (wrstream_val && wrstream_rdy) begin
            released = 1;
            $display("[%0t] Extra write accepted after full condition cleared", $time);
            disable WAIT_EXTRA_ACCEPT;
          end
        end
      end
    join

    if (released == 0) begin
      $fatal(1, "[%0t] ERROR: extra write was not accepted in time", $time);
    end

    @(negedge wr_clk);
    wrstream_val = 1'b0;

    // --------------------------------------------------------
    // Phase 4: drain everything
    // --------------------------------------------------------
    remaining = wr_idx - rd_idx;
    $display("\n================ Phase 4: drain remaining %0d words =======\n", remaining);

    read_n(remaining);

    repeat (2) @(posedge rd_clk);
    #1;
    if (rd_empty !== 1'b1) begin
      $fatal(1, "[%0t] ERROR: FIFO should be empty at end of test", $time);
    end

    if (wr_idx !== rd_idx) begin
      $fatal(1, "[%0t] ERROR: write count != read count (%0d vs %0d)",
             $time, wr_idx, rd_idx);
    end

    $display("\n===========================================================");
    $display("PASS: all checks passed");
    $display("total writes = %0d, total reads = %0d", num_wr, num_rd);
    $display("===========================================================\n");

    #20;
    $finish;
  end

  initial begin
    $dumpfile("fifo_async_tb.vcd");
    $dumpvars(0, tb_fifo_async);
  end

endmodule