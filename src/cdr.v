

// -------------------------------------------------------------------
// CDR (baud-rate, Mueller\u2013M\u00fcller) \u2014 phase-only feeling, fixed baud
//  \u2022 clk = 50 MHz
//  \u2022 sample_en \u2248 25 MHz (UI = 2 clocks) via FCW_NOM = 0x8000_0000
//  \u2022 dfcw impact is tiny to keep baud nearly constant
//  \u2022 PI has anti-windup (freeze integrator when dfcw clamps)
// -------------------------------------------------------------------
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
  localparam integer PHASE_BITS         = 32;

  // 25 MHz tick @ 50 MHz clk  =>  UI = 2 clocks
  localparam [PHASE_BITS-1:0] FCW_NOM   = 32'h8000_0000;

  // loop gains (conservative)
  localparam integer KP_SHIFT           = 12;
  localparam integer KI_SHIFT           = 18;

  // keep dfcw tiny vs FCW_NOM (phase-only feel)
  localparam integer DFCW_SHIFT         = 29;                       // very weak freq trim
  localparam [PHASE_BITS-1:0] DFCW_STEP = (FCW_NOM >> 10);          // \u2248 0.098% of FCW
  localparam signed  [31:0] DFCW_CLAMP  = $signed({1'b0, DFCW_STEP}); // \u00b1step

  wire rst = ~rst_n;

  // 1) sampler: update only on sample_en
  sampler_ce u_sampler (.clk(clk), .rst(rst), .sample_en(sample_en), .x_in(y_n), .x_n(x_n));

  // 2) quantizer (hard + 2b soft kept)
  quantizer_sign2b u_q (.x_n(x_n), .d_bb(d_bb), .d_q2(d_q2));

  // 3) one-UI delays for MMPD
  wire signed [7:0] x_z1; wire d_z1;
  delay_ce #(.W(8)) u_dx (.clk(clk), .rst(rst), .en(sample_en), .din(x_n), .dout(x_z1));
  delay_ce #(.W(1)) u_dd (.clk(clk), .rst(rst), .en(sample_en), .din(d_bb), .dout(d_z1));

  // 4) Mueller\u2013M\u00fcller PD
  mmpd_mueller_core u_pd (.x_n(x_n), .x_z1(x_z1), .d_n(d_bb), .d_z1(d_z1), .f_n(f_n));

  // 5) PI with anti-windup (freeze)
  wire signed [31:0] v_raw;
  wire freeze_aw;
  loop_filter_pi_aw #(.KP_SHIFT(KP_SHIFT), .KI_SHIFT(KI_SHIFT))
    u_pi (.clk(clk), .rst(rst), .en(sample_en), .f_n(f_n), .freeze(freeze_aw), .v_ctrl(v_raw));

  // 6) scale + clamp to tiny dfcw
  wire signed [31:0] df_unclamped = $signed(v_raw) >>> DFCW_SHIFT;
  wire signed [31:0] df_limited   =
      (df_unclamped >  DFCW_CLAMP) ?  DFCW_CLAMP :
      (df_unclamped < -DFCW_CLAMP) ? -DFCW_CLAMP : df_unclamped;

  assign dfcw   = df_limited;
  assign v_ctrl = v_raw;

  // freeze integrator when clamped
  assign freeze_aw = (df_unclamped != df_limited);

  // 7) DCO: one-cycle sample_en pulse on phase wrap
  wire [PHASE_BITS-1:0] phase_unused;
  dco_tick_on_wrap #(.PHASE_BITS(PHASE_BITS)) u_dco (
    .clk(clk), .rst(rst),
    .fcw_nom(FCW_NOM), .dfcw(dfcw[PHASE_BITS-1:0]),
    .phase(phase_unused), .sample_en(sample_en)
  );
endmodule


// ---------------- submodules ----------------

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
  assign d_bb = ~x_n[7];
  wire neg = x_n[7];
  wire [6:0] mag = neg ? (~x_n[6:0] + 1'b1) : x_n[6:0];
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
  wire signed [1:0] dn  = d_n  ? 2'sd1 : -2'sd1;
  wire signed [1:0] dm1 = d_z1 ? 2'sd1 : -2'sd1;
  assign f_n = $signed(dn)*$signed(x_z1) - $signed(dm1)*$signed(x_n);
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
  wire signed [31:0] p = $signed(f_n) >>> KP_SHIFT;
  wire signed [31:0] i = acc         >>> KI_SHIFT;
  always @(posedge clk) begin
    if (rst) begin
      acc   <= 32'sd0;
      v_ctrl<= 32'sd0;
    end else if (en) begin
      if (!freeze) acc <= acc + $signed({{16{f_n[15]}}, f_n});
      v_ctrl <= v_ctrl + p + i;
    end
  end
endmodule

// DCO: one-cycle tick on wrap
module dco_tick_on_wrap #(
  parameter integer PHASE_BITS = 32
)(
  input  wire                          clk,
  input  wire                          rst,
  input  wire [PHASE_BITS-1:0]         fcw_nom,
  input  wire signed [PHASE_BITS-1:0]  dfcw,
  output reg  [PHASE_BITS-1:0]         phase,
  output wire                          sample_en
);
  // effective FCW with saturation
  wire signed [PHASE_BITS:0] sum =
      $signed({1'b0, fcw_nom}) + $signed({dfcw[PHASE_BITS-1], dfcw});
  wire [PHASE_BITS-1:0] eff =
      (sum <= 0) ? {PHASE_BITS{1'b0}} :
      (sum >  $signed({1'b0,{PHASE_BITS{1'b1}}})) ? {PHASE_BITS{1'b1}} :
       sum[PHASE_BITS-1:0];

  wire [PHASE_BITS-1:0] nxt = phase + eff;
  assign sample_en = (nxt < phase);   // wrap \u2192 1-cycle pulse

  always @(posedge clk) begin
    if (rst) phase <= {PHASE_BITS{1'b0}};
    else     phase <= nxt;
  end
endmodule

`default_nettype wire
