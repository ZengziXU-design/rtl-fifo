module fifo_async #(
  parameter int N_BIT = 8,
  parameter int DEPTH = 16 // DEPTH = 4, 8, 16, ...
)(
  input  logic               wr_clk,
  input  logic               rd_clk,
  input  logic               wr_rst,
  input  logic               rd_rst,

  input  logic [N_BIT-1:0]   wrstream_msg,
  input  logic               wrstream_val,
  output logic               wrstream_rdy,

  output logic [N_BIT-1:0]   rdstream_msg,
  output logic               rdstream_val,
  input  logic               rdstream_rdy,

  output logic               wr_full,
  output logic               rd_empty
);

    localparam int PTRW = $clog2(DEPTH);

    logic [N_BIT-1:0] entries [0:DEPTH-1]; 
    logic [PTRW:0]  rdptr_bin,  wrptr_bin;
    logic [PTRW:0]  rdptr_gray, wrptr_gray;

    logic [PTRW:0] rdptr_gray_ff1, rdptr_gray_ff2;
    logic [PTRW:0] wrptr_gray_ff1, wrptr_gray_ff2;

    logic do_wr, do_rd;
    assign do_wr = wrstream_val && wrstream_rdy;
    assign do_rd = rdstream_val && rdstream_rdy;

    logic [PTRW:0] wrptr_bin_next, rdptr_bin_next;

    always @(*) begin
        if (do_wr) begin
            if (wrptr_bin[PTRW-1:0] == DEPTH-1) begin
                wrptr_bin_next[PTRW-1:0] = 0;
                wrptr_bin_next[PTRW] = ~wrptr_bin[PTRW];
            end else begin
                wrptr_bin_next = wrptr_bin + 1;
            end
        end else begin
            wrptr_bin_next = wrptr_bin;
        end
    end

    always @(*) begin
        if (do_rd) begin
            if (rdptr_bin[PTRW-1:0] == DEPTH-1) begin
                rdptr_bin_next[PTRW-1:0] = 0;
                rdptr_bin_next[PTRW] = ~rdptr_bin[PTRW];
            end else begin
                rdptr_bin_next = rdptr_bin + 1;
            end
        end else begin
            rdptr_bin_next = rdptr_bin;
        end
    end


    always_ff @(posedge wr_clk) begin
        if (wr_rst) begin
            wrptr_bin <= 0;
        end else wrptr_bin <= wrptr_bin_next;
    end

    always_ff @(posedge rd_clk) begin
        if (rd_rst) begin
            rdptr_bin <= 0;
        end else rdptr_bin <= rdptr_bin_next;
    end

    function automatic logic [PTRW:0] bin2gray(input logic [PTRW:0] bin);
        return (bin >> 1) ^ bin;
    endfunction

    assign wrptr_gray = bin2gray(wrptr_bin);
    assign rdptr_gray = bin2gray(rdptr_bin);

    always_ff @(posedge wr_clk) begin
        if (wr_rst) begin
            rdptr_gray_ff1 <= 0;
            rdptr_gray_ff2 <= 0;
        end else begin
            rdptr_gray_ff1 <= rdptr_gray;
            rdptr_gray_ff2 <= rdptr_gray_ff1;
        end
    end

    always_ff @(posedge rd_clk) begin
        if (rd_rst) begin
            wrptr_gray_ff1 <= 0;
            wrptr_gray_ff2 <= 0;
        end else begin
            wrptr_gray_ff1 <= wrptr_gray;
            wrptr_gray_ff2 <= wrptr_gray_ff1;
        end
    end

    function automatic logic is_full(input logic [PTRW:0] wrptr, input logic [PTRW:0] rdptr);
        return (wrptr[PTRW] != rdptr[PTRW]) &&
            (wrptr[PTRW-1] != rdptr[PTRW-1]) &&
            (wrptr[PTRW-2:0] == rdptr[PTRW-2:0]);
    endfunction

    assign rd_empty = (rdptr_gray == wrptr_gray_ff2);
    assign wr_full = is_full(wrptr_gray, rdptr_gray_ff2);

    assign wrstream_rdy = !wr_full;
    assign rdstream_val = !rd_empty;


    always_ff @(posedge wr_clk) begin
        if (do_wr) begin
            entries[wrptr_bin[PTRW-1:0]] <= wrstream_msg;
        end
    end

    assign rdstream_msg = rdstream_val ? entries[rdptr_bin[PTRW-1:0]] : 0;

endmodule