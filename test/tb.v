
`default_nettype none
`timescale 1ns / 1ps

module tb ();

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
  end

  reg        clk;
  reg        rst_n;
  reg        ena;
  reg  [7:0] ui_in;
  reg  [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  tt_um_adpll dut (
`ifdef GL_TEST
      .VPWR (VPWR),
      .VGND (VGND),
`endif
      .ui_in   (ui_in),
      .uo_out  (uo_out),
      .uio_in  (uio_in),
      .uio_out (uio_out),
      .uio_oe  (uio_oe),
      .ena     (ena),
      .clk     (clk),
      .rst_n   (rst_n)
  );

  // 50 MHz clock
  initial clk = 1'b0;
  always #10 clk = ~clk;

  initial begin
    ena    = 1'b1;
    rst_n  = 1'b0;
    ui_in  = 8'h00;
    uio_in = 8'h00;

    #100;  rst_n = 1'b1;

    // Wiggle a few inputs
    #200; ui_in[1] = 1'b1;           // clk_ref high
    #200; ui_in[3] = 1'b1;           // pgm = 1
           uio_in[6:2] = 5'b10101;   // pgm_value
    #200; ui_in[3] = 1'b0;           // pgm = 0

    #500; $finish;
  end

endmodule

`default_nettype wire
