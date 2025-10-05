// cdr.v — Baud-rate CDR (Mueller-Muller PD), phase-only feel, fixed baud
`default_nettype none

// -----------------------------------------------------------------------------
// Top-level CDR
// -----------------------------------------------------------------------------
module cdr (
  input  wire               clk,
  input  wire               rst_n,
  input  wire signed [7:0]  y_n,
  output wire               sample_en,   // 1-cycle symbol strobe (DCO wrap)
  output wire signed [7:0]  x_n,
  output wire               d_bb,
  output wire [1:0]         d_q2,
  output wire signed [15:0] f_n,
  output wire signed [31:0] v_ctrl,
  output wire signed [31:0] dfcw
);

  // -------- configuration --------
  localparam integer PHASE_BITS   = 32;

  // 25 MHz tick @ 50 MHz clk  =>  UI = 2 clocks
  localparam [PHASE_BITS-1:0] FCW_NOM = 32'h8000_0000;

  // loop gains (conservative)
  localparam integer KP_SHIFT     = 12;
  localparam integer KI_SHIFT     = 18;

  // keep dfcw tiny vs FCW_NOM (phase-only feel)
  localparam integer DFCW_SHIFT   = 29;  // very weak freq trim

  // Use plain integers for clamp math (iverilog friendly)
  localparam integer FCW_NOM_INT     = 32'h8000_0000;
  localparam integer DFCW_STEP_INT   = (FCW_NOM_INT >> 10);  // ~0.098% of FCW
  localparam signed  [31:0] DFCW_CLAMP = DFCW_STEP_INT;      // +/- one step

  wire rst = ~rst_n;

  // 1) sampler: update only on sample_en
  sampler_ce u_sampler (
    .clk(clk), .rst(rst), .sample_en(sample_en),
    .x_in(y_n), .x_n(x_n)
  );

  // 2) quantizer (hard + 2b soft kept)
  quantizer_sign2b u_q (
    .x_n(x_n), .d_bb(d_bb), .d_q2(d_q2)
  );

  // 3) one-UI delays for MMPD
  wire signed [7:0] x_z1;
  wire              d_z1;

  delay_ce #(.W(8)) u_dx (
    .clk(clk), .rst(rst), .en(sample_en), .din(x_n),  .dout(x_z1)
  );

  delay_ce #(.W(1)) u_dd (
    .clk(clk), .rst(rst), .en(sample_en), .din(d_bb), .dout(d_z1)
  );

  // 4) Mueller-Muller PD
  mmpd_mueller_core u_pd (
    .x_n(x_n), .x_z1(x_z1),
    .d_n(d_bb), .d_z1(d_z1),
    .f_n(f_n)
  );

  // 5) PI with anti-windup (freeze)
  wire signed [31:0] v_raw;
  wire               freeze_aw;

  loop_filter_pi_aw #(.KP_SHIFT(KP_SHIFT), .KI_SHIFT(KI_SHIFT)) u_pi (
    .clk(clk), .rst(rst), .en(sample_en),
    .f_n(f_n), .freeze(freeze_aw),
    .v_ctrl(v_raw)
  );

  // 6) scale + clamp to tiny dfcw (phase-only feel)
  wire signed [31:0] df_unclamped = $signed(v_raw) >>> DFCW_SHIFT;

  wire signed [31:0] df_limited =
      (df_unclamped >  DFCW_CLAMP) ?  DFCW_CLAMP :
      (df_unclamped < -DFCW_CLAMP) ? -DFCW_CLAMP : df_unclamped;

  assign dfcw   = df_limited;
  assign v_ctrl = v_raw;

  // freeze integrator when clamped
  assign freeze_aw = (df_unclamped != df_limited);

  // 7) DCO: one-cycle sample_en pulse on phase wrap
  // NOTE: Because dfcw clamp is tiny relative to FCW_NOM, sum never underflows/overflows.
  // We therefore skip saturation and just do wrapping add, which is Icarus-safe.
  wire [PHASE_BITS-1:0] eff = FCW_NOM + dfcw[PHASE_BITS-1:0];

  dco_tick_on_wrap #(.PHASE_BITS(PHASE_BITS)) u_dco (
    .clk(clk), .rst(rst),
    .eff(eff),
    .sample_en(sample_en)
  );

endmodule

// -----------------------------------------------------------------------------
// Submodules
// -----------------------------------------------------------------------------

module sampler_ce (
  input  wire              clk,
  input  wire              rst,
  input  wire              sample_en,
  input  wire signed [7:0] x_in,
  output reg  signed [7:0] x_n
);
  always @(posedge clk) begin
    if (rst)            x_n <= 8'sd0;
    else if (sample_en) x_n <= x_in;
  end
endmodule

module delay_ce #(
  parameter integer W = 8
)(
  input  wire         clk,
  input  wire         rst,
  input  wire         en,
  input  wire [W-1:0] din,
  output reg  [W-1:0] dout
);
  always @(posedge clk) begin
    if (rst)     dout <= {W{1'b0}};
    else if (en) dout <= din;
  end
endmodule

module quantizer_sign2b (
  input  wire signed [7:0] x_n,
  output wire              d_bb,
  output wire [1:0]        d_q2
);
  // Hard decision: 1 if >=0, 0 if <0
  assign d_bb = ~x_n[7];

  // Two-bit soft bins: 00 = strong neg, 01 = weak neg, 10 = weak pos, 11 = strong pos
  wire neg = x_n[7];
  wire [6:0] mag = neg ? (~x_n[6:0] + 7'd1) : x_n[6:0];
  wire weak = (mag < 7'd8);

  assign d_q2 = neg ? (weak ? 2'b01 : 2'b00)
                    : (weak ? 2'b10 : 2'b11);
endmodule

module mmpd_mueller_core (
  input  wire signed [7:0]  x_n,
  input  wire signed [7:0]  x_z1,
  input  wire               d_n,
  input  wire               d_z1,
  output wire signed [15:0] f_n
);
  // Map decisions to +/-1
  wire signed [1:0] dn  = d_n  ? 2'sd1 : -2'sd1;
  wire signed [1:0] dm1 = d_z1 ? 2'sd1 : -2'sd1;

  // f[n] = d[n]*x[n-1] - d[n-1]*x[n]
  assign f_n = $signed(dn) * $signed(x_z1) - $signed(dm1) * $signed(x_n);
endmodule

// PI with anti-windup "freeze" input
module loop_filter_pi_aw #(
  parameter integer KP_SHIFT = 12,
  parameter integer KI_SHIFT = 18
)(
  input  wire               clk,
  input  wire               rst,
  input  wire               en,
  input  wire signed [15:0] f_n,
  input  wire               freeze,   // stop integrating when asserted
  output reg  signed [31:0] v_ctrl
);
  reg signed [31:0] acc;

  // proportional and integral paths are applied to v_ctrl incrementally
  wire signed [31:0] p = $signed(f_n) >>> KP_SHIFT;
  wire signed [31:0] i = acc          >>> KI_SHIFT;

  always @(posedge clk) begin
    if (rst) begin
      acc    <= 32'sd0;
      v_ctrl <= 32'sd0;
    end else if (en) begin
      if (!freeze) acc <= acc + $signed({{16{f_n[15]}}, f_n});
      v_ctrl <= v_ctrl + p + i;
    end
  end
endmodule

// DCO: simple phase accumulator; tick when phase wraps
module dco_tick_on_wrap #(
  parameter integer PHASE_BITS = 32
)(
  input  wire                      clk,
  input  wire                      rst,
  input  wire [PHASE_BITS-1:0]     eff,       // effective FCW (already combined)
  output wire                      sample_en
);
  reg [PHASE_BITS-1:0] phase;

  wire [PHASE_BITS-1:0] nxt = phase + eff;
  assign sample_en = (nxt < phase);  // wrap -> 1-cycle pulse

  always @(posedge clk) begin
    if (rst) phase <= {PHASE_BITS{1'b0}};
    else     phase <= nxt;
  end
endmodule

`default_nettype wire
