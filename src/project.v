
// TinyTapeout top wrapper: tt_um_sfg_cdr
`default_nettype none

module tt_um_sfg_cdr (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);
  wire rst    = ~rst_n;
  wire active = ena & ~rst;

  // signed input sample bus
  wire signed [7:0] y_n = ui_in;

  // CDR core signals
  wire        sample_en;
  wire signed [7:0]  x_n;
  wire        d_bb;
  wire [1:0]  d_q2;
  wire signed [31:0] v_ctrl;
  wire signed [31:0] dfcw;

  // CDR core (sampler is just a DFF gated by sample_en)
  cdr_core #(
    .PHASE_BITS (32),
    // 25 MHz tick @ 50 MHz clk -> UI = 2 clocks
    .FCW_NOM    (32'h8000_0000),
    // loop gains / trims (conservative; tiny dfcw influence)
    .KP_SHIFT   (12),
    .KI_SHIFT   (18),
    .DFCW_SHIFT (29),
    .DFCW_CLAMP (32'sd8388608) // small clamp; adjust if desired
  ) u_cdr (
    .clk       (clk),
    .rst       (rst | ~ena),
    .y_n       (active ? y_n : 8'sd0),
    .sample_en (sample_en),
    .x_n       (x_n),
    .d_bb      (d_bb),
    .d_q2      (d_q2),
    .v_ctrl    (v_ctrl),
    .dfcw      (dfcw)
  );

  // Recovered 50% duty clock: toggle on each symbol strobe
  reg rec_clk_ff;
  always @(posedge clk) begin
    if (rst | ~ena) rec_clk_ff <= 1'b0;
    else if (sample_en) rec_clk_ff <= ~rec_clk_ff;
  end

  // Outputs: quiet when disabled
  assign uo_out[0]   = active ? sample_en : 1'b0;      // SAMPLE_EN pulse
  assign uo_out[1]   = active ? rec_clk_ff : 1'b0;     // REC_CLK 50% duty
  assign uo_out[7:2] = active ? x_n[7:2]   : 6'h00;    // sampler/debug

  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;
endmodule

`default_nettype wire
