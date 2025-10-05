// CDR core and submodules (sampler is a simple DFF)
`default_nettype none

module cdr_core #(
  parameter integer PHASE_BITS  = 32,
  parameter [PHASE_BITS-1:0] FCW_NOM = 32'h8000_0000, // 25 MHz @ 50 MHz clk
  parameter integer KP_SHIFT    = 12,
  parameter integer KI_SHIFT    = 18,
  parameter integer DFCW_SHIFT  = 29,
  parameter signed  [31:0] DFCW_CLAMP = 32'sd8388608
)(
  input  wire               clk,
  input  wire               rst,
  input  wire signed [7:0]  y_n,
  output wire               sample_en,
  output wire signed [7:0]  x_n,
  output wire               d_bb,
  output wire [1:0]         d_q2,
  output wire signed [31:0] v_ctrl,
  output wire signed [31:0] dfcw
);

  // --- 1) Sampler: just a DFF that captures y_n on sample_en ---
  sampler_dff u_samp (
    .clk(clk), .rst(rst), .sample_en(sample_en),
    .d(y_n), .q(x_n)
  );

  // --- 2) Quantizer ---
  quantizer_sign2b u_q (
    .x_n(x_n), .d_bb(d_bb), .d_q2(d_q2)
  );

  // --- 3) Mueller–Muller phase detector (sequential, updates on sample_en) ---
  wire signed [15:0] f_n;
  mmpd_mueller u_pd (
    .clk(clk), .rst(rst), .sample_en(sample_en),
    .x_n(x_n), .d_bb(d_bb), .f_n(f_n)
  );

  // --- 4) PI loop filter (no anti-windup here; simple and robust) ---
  loop_filter_pi #(.KP_SHIFT(KP_SHIFT), .KI_SHIFT(KI_SHIFT)) u_lpf (
    .clk(clk), .rst(rst), .en(sample_en), .f_n(f_n), .v_ctrl(v_ctrl)
  );

  // --- 5) Scale and clamp to tiny dfcw ---
  wire signed [31:0] df_raw = $signed(v_ctrl) >>> DFCW_SHIFT;

  reg  signed [31:0] df_lim;
  always @* begin
    if (DFCW_CLAMP == 0)
      df_lim = df_raw;
    else if (df_raw >  DFCW_CLAMP)
      df_lim = DFCW_CLAMP;
    else if (df_raw < -DFCW_CLAMP)
      df_lim = -DFCW_CLAMP;
    else
      df_lim = df_raw;
  end
  assign dfcw = df_lim;

  // --- 6) DCO / NCO: symbol strobe on phase wrap ---
  nco_dco #(.PHASE_BITS(PHASE_BITS)) u_dco (
    .clk(clk), .rst(rst),
    .fcw_nom(FCW_NOM),
    .dfcw(dfcw[PHASE_BITS-1:0]), // modulo add is fine here
    .sample_en(sample_en)
  );
endmodule

// ---------------------------------------------------------------------------
// Submodules
// ---------------------------------------------------------------------------

module sampler_dff (
  input  wire              clk,
  input  wire              rst,
  input  wire              sample_en,
  input  wire signed [7:0] d,
  output reg  signed [7:0] q
);
  always @(posedge clk) begin
    if (rst)            q <= 8'sd0;
    else if (sample_en) q <= d;
  end
endmodule

module quantizer_sign2b (
  input  wire signed [7:0] x_n,
  output wire              d_bb,
  output wire [1:0]        d_q2
);
  // hard decision
  assign d_bb = ~x_n[7];

  // simple 2-bit soft decision (ASCII-only, iverilog-friendly)
  reg [1:0] d_q2_r;
  reg [6:0] mag;
  reg       neg;
  assign d_q2 = d_q2_r;

  always @* begin
    neg = x_n[7];
    if (neg) mag = (~x_n[6:0]) + 7'd1; else mag = x_n[6:0];

    if (neg) begin
      if (mag < 7'd8) d_q2_r = 2'b01; else d_q2_r = 2'b00;
    end else begin
      if (mag < 7'd8) d_q2_r = 2'b10; else d_q2_r = 2'b11;
    end
  end
endmodule

module mmpd_mueller (
  input  wire               clk,
  input  wire               rst,
  input  wire               sample_en,
  input  wire signed [7:0]  x_n,
  input  wire               d_bb,
  output reg  signed [15:0] f_n
);
  reg signed [7:0] x_z1;
  reg              d_z1;
  wire signed [1:0] d_now = d_bb ? 2'sd1 : -2'sd1;
  wire signed [1:0] d_p1  = d_z1 ? 2'sd1 : -2'sd1;

  always @(posedge clk) begin
    if (rst) begin
      x_z1 <= 8'sd0;
      d_z1 <= 1'b0;
      f_n  <= 16'sd0;
    end else if (sample_en) begin
      f_n  <= $signed(d_now) * $signed(x_z1) - $signed(d_p1) * $signed(x_n);
      x_z1 <= x_n;
      d_z1 <= d_bb;
    end
  end
endmodule

module loop_filter_pi #(
  parameter integer KP_SHIFT = 12,
  parameter integer KI_SHIFT = 18
)(
  input  wire               clk,
  input  wire               rst,
  input  wire               en,
  input  wire signed [15:0] f_n,
  output reg  signed [31:0] v_ctrl
);
  reg signed [31:0] acc;
  wire signed [31:0] p_term = $signed(f_n) >>> KP_SHIFT;
  wire signed [31:0] i_term = acc          >>> KI_SHIFT;

  always @(posedge clk) begin
    if (rst) begin
      acc    <= 32'sd0;
      v_ctrl <= 32'sd0;
    end else if (en) begin
      acc    <= acc + $signed({{16{f_n[15]}}, f_n});
      v_ctrl <= v_ctrl + p_term + i_term;
    end
  end
endmodule

// Very simple NCO/DCO: modulo add, pulse on wrap
module nco_dco #(
  parameter integer PHASE_BITS = 32
)(
  input  wire                      clk,
  input  wire                      rst,
  input  wire [PHASE_BITS-1:0]     fcw_nom,
  input  wire [PHASE_BITS-1:0]     dfcw,      // already small; modulo add is fine
  output wire                      sample_en
);
  reg  [PHASE_BITS-1:0] phase;
  wire [PHASE_BITS-1:0] eff  = fcw_nom + dfcw;   // modulo
  wire [PHASE_BITS-1:0] nxt  = phase + eff;
  assign sample_en = (nxt < phase);             // wrap -> 1-cycle pulse

  always @(posedge clk) begin
    if (rst) phase <= {PHASE_BITS{1'b0}};
    else     phase <= nxt;
  end
endmodule

`default_nettype wire
