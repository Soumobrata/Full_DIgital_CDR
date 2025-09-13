`default_nettype none
`timescale 1ns / 1ps

/* 
   Cocotb-friendly TinyTapeout testbench.
   - Drives a 50 MHz clock (20 ns period)
   - Does NOT call $finish; cocotb ends the simulation
   - Dumps VCD to tb.vcd
*/
module tb;

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
  // Power pins only for gate-level sims
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Instantiate your top module
  tt_um_adpll user_project (
`ifdef GL_TEST
      .VPWR   (VPWR),
      .VGND   (VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  // Clock generation: 50 MHz (20 ns period)
  initial clk = 1'b0;
  always #10 clk = ~clk;

  // Simple power-on defaults; cocotb drives real stimulus
  initial begin
    ena    = 1'b1;
    rst_n  = 1'b1; // cocotb will toggle reset
    ui_in  = 8'h00;
    uio_in = 8'h00;
  end

endmodule

`default_nettype wire

