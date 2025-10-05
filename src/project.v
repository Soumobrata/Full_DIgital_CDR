/*
 * SPDX-License-Identifier: Apache-2.0
 * Author: Soumobrata Ghosh
 */

`default_nettype none

module tt_um_sfg_cdr (
  input  wire [7:0] ui_in,   // 8 input pins
  output wire [7:0] uo_out,  // 8 output pins
  input  wire [7:0] uio_in,  // 8 bidir pins
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,     // mux enable
  input  wire       clk,     // ~50 MHz board clock
  input  wire       rst_n    // active-low reset
);

  // ------------------------------------------
  // instantiate your unchanged CDR core
  // ------------------------------------------
  wire signed [7:0] y_n   = ui_in;
  wire        sample_en;
  wire signed [7:0] x_n;
  wire        d_bb;
  wire [1:0]  d_q2;
  wire signed [15:0] f_n;
  wire signed [31:0] v_ctrl;
  wire signed [31:0] dfcw;

  cdr u_cdr (
    .clk(clk),
    .rst_n(rst_n),
    .y_n(y_n),
    .sample_en(sample_en),
    .x_n(x_n),
    .d_bb(d_bb),
    .d_q2(d_q2),
    .f_n(f_n),
    .v_ctrl(v_ctrl),
    .dfcw(dfcw)
  );

  // ------------------------------------------
  // simple debug mapping to outputs
  // ------------------------------------------
  assign uo_out = ena ? {
      dfcw[31], v_ctrl[31], d_q2[1], d_q2[0],
      d_bb, x_n[7], sample_en, 1'b0
  } : 8'h00;

  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

endmodule
`default_nettype wire
