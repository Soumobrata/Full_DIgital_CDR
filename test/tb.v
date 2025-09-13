`default_nettype none
`timescale 1ns / 1ps

/* 
   Minimal testbench for TinyTapeout CI.
   Instantiates tt_um_adpll and drives clock, reset, and a few inputs.
   Cocotb will take over for more advanced tests.
*/
module tb ();

  // Dump signals to VCD for waveform debugging
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
  end

  // Inputs and outputs
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

  // Instantiate your top module
  tt_um_adpll user_project (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
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

  // Clock generation: 50 MHz (20 ns period)
  initial clk = 0;
  always #10 clk = ~clk;

  // Simple stimulus
  initial begin
    ena    = 1'b1;
    rst_n  = 1'b0;
    ui_in  = 8'h00;
    uio_in = 8'h00;

    // Release reset
    #100;
    rst_n = 1'b1;

    // Apply a few patterns to ui_in/uio_in
    #200;
    ui_in[1] = 1'b1;    // drive clk_ref high
    #200;
    ui_in[3] = 1'b1;    // toggle pgm
    uio_in[6:2] = 5'b10101; // example pgm_value
    #500;

    // End sim
    $finish;
  end

endmodule

`default_nettype wire
