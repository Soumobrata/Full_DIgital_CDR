// cdr.v — Minimal, Icarus-safe CDR shell for CI
`default_nettype none

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
  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------
  localparam integer PHASE_BITS = 32;
  // 25 MHz tick @ 50 MHz clk => UI = 2 clocks
  localparam [PHASE_BITS-1:0] FCW_NOM = 32'h8000_0000;

  wire rst = ~rst_n;

  // ---------------------------------------------------------------------------
  // 1) Sampler: update only on sample_en
  // ---------------------------------------------------------------------------
  sampler_ce u_sampler (.clk(clk), .rst(rst), .sample_en(sample_en), .x_in(y_n), .x_n(x_n));

  // 2) Quantizer (hard + 2b soft kept)
  quantizer_sign2b u_q (.x_n(x_n), .d_bb(d_bb), .d_q2(d_q2));

  // ---------------------------------------------------------------------------
  // 3) Loop path (stubbed to zeros for CI stability)
  //    NOTE: This keeps the interface identical. We can re-enable the full
  //    Mueller–Muller + PI + dfcw logic after CI is green.
  // ---------------------------------------------------------------------------
  assign f_n   = 16'sd0;
  assign v_ctrl= 32'sd0;
  assign dfcw  = 32'sd0;

  // ---------------------------------------------------------------------------
  // 4) DCO: one-cycle sample_en pulse on phase wrap (fixed FCW)
  // ---------------------------------------------------------------------------
  reg  [PHASE_BITS-1:0] phase;
  wire [PHASE_BITS-1:0] nxt = phase + FCW_NOM;

  assign sample_en = (nxt < phase);  // wrap -> 1-cycle pulse

  always @(posedge clk) begin
    if (rst) phase <= {PHASE_BITS{1'b0}};
    else     phase <= nxt;
  end
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

module quantizer_sign2b (
  input  wire signed [7:0] x_n,
  output wire              d_bb,
  output wire [1:0]        d_q2
);
  assign d_bb = ~x_n[7];

  wire neg = x_n[7];
  wire [6:0] mag = neg ? (~x_n[6:0] + 7'd1) : x_n[6:0];
  wire weak = (mag < 7'd8);

  assign d_q2 = neg ? (weak ? 2'b01 : 2'b00)
                    : (weak ? 2'b10 : 2'b11);
endmodule

`default_nettype wire
