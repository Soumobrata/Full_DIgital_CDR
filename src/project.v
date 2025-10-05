/*
 * SPDX-License-Identifier: Apache-2.0
 * Author: Soumobrata Ghosh
 */
`default_nettype none

module tt_um_sfg_cdr (
  input  wire [7:0] ui_in,   // 8 input pins
  output wire [7:0] uo_out,  // 8 output pins
  input  wire [7:0] uio_in,  // 8 bidir input
  output wire [7:0] uio_out, // 8 bidir output
  output wire [7:0] uio_oe,  // 8 bidir output-en
  input  wire       ena,     // TT mux enable
  input  wire       clk,     // ~50 MHz board clock
  input  wire       rst_n    // active low
);

  // ---------- CDR core (unchanged) ----------
  wire signed [7:0]  y_n = ui_in;
  wire        sample_en;         // 1-cycle pulse each baud
  wire signed [7:0]  x_n;
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

  // ---------- 50% duty REC_CLK: toggle on each sample_en ----------
  reg rec_clk;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rec_clk <= 1'b0;
    end else if (sample_en) begin
      rec_clk <= ~rec_clk;
    end
  end

  // ---------- Outputs (quiet when ena=0) ----------
  // uo_out[0] = SAMPLE_EN (pulse), uo_out[1] = REC_CLK (50% duty)
  wire [7:0] outs = {
    dfcw[31],     // [7] sign(dfcw)  (debug)
    v_ctrl[31],   // [6] sign(v_ctrl) (debug)
    d_q2[1],      // [5]
    d_q2[0],      // [4]
    d_bb,         // [3]
    x_n[7],       // [2] sign of sample
    rec_clk,      // [1] REC_CLK
    sample_en     // [0] SAMPLE_EN
  };

  assign uo_out  = ena ? outs : 8'h00;
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

endmodule

`default_nettype wire
