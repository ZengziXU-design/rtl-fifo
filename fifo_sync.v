module fifo_sync #(
  parameter int N_bit = 8,
  parameter int DEPTH  = 16
)(
  input  logic              clk,
  input  logic              reset, // Synchronous active high reset

  input  logic              wr_en,
  input  logic [N_bit - 1:0] wdata_i,
  input  logic              rd_en,
  output logic [N_bit - 1:0] rdata_o,

  output logic              empty,
  output logic              full,

  output logic [$clog2(DEPTH) : 0] count // number of elements in the FIFO, 0 to DEPTH
);


    logic [N_bit-1:0] entries [0:DEPTH-1]; // Storage for FIFO entries
    logic [$clog2(DEPTH)-1:0] rdptr, wrptr; // Read and write pointers

    logic do_wr, do_rd;
    assign do_wr = wr_en && !full;
    assign do_rd = rd_en && !empty;

    always_ff @(posedge clk) begin
        if (reset) begin
            rdptr <= 0;
            wrptr <= 0;
            count <= 0;
            rdata_o <= 0;
        end else begin
            if (do_wr) begin
                entries[wrptr] <= wdata_i;
                if (wrptr == (DEPTH - 1)) wrptr <= 0;
                else wrptr <= wrptr + 1;
            end

            if (do_rd) begin
                rdata_o <= entries[rdptr];
                if (rdptr == (DEPTH - 1)) rdptr <= 0;
                else rdptr <= rdptr + 1;
            end
            case ({do_wr, do_rd})
                2'b01: count <= count - 1; // Read only
                2'b10: count <= count + 1; // Write only
                default: count <= count;
            endcase
        end
    end

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

endmodule