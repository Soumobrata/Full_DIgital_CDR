


`default_nettype none
`timescale 1ns/1ps

module tb;
  reg  [7:0] ui_in   = 8'h00;
  wire [7:0] uo_out;
  reg  [7:0] uio_in  = 8'h00;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  reg        ena     = 1'b0;
  reg        clk     = 1'b0;
  reg        rst_n   = 1'b0;

  // 50 MHz clock (20 ns period)
  always #10 clk = ~clk;

  // DUT = TinyTapeout top wrapper around your cdr
  tt_um_sfg_cdr dut (
    .ui_in (ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena(ena),
    .clk(clk),
    .rst_n(rst_n)
  );

  initial begin
    // simple bring-up for waveform sims (cocotb will do the real checks)
    rst_n = 0;
    ena   = 0;
    ui_in = 8'h00;
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);
    ena = 1;

    // drive a small ramp so REC_CLK/sample_en have activity
    integer i;
    for (i = 0; i < 800; i = i + 1) begin
      @(posedge clk);
      ui_in <= ui_in + 8'd2;
    end

    $finish;
  end
endmodule

`default_nettype wire
