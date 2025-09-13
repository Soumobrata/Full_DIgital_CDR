/* SPDX-License-Identifier: Apache-2.0 */
`default_nettype none

// -----------------------------------------------------------------------------
// ADPLL core top (padless). All logic is synchronous to the TT clock domain.
// -----------------------------------------------------------------------------
module adpll_top(
  input  wire        clk,
  input  wire        rst, 
  input  wire        clk90, 
  input  wire        clk_ref,
  input  wire        clr,
  input  wire        pgm,
  input  wire        out_sel,
  input  wire [2:0]  param_sel, 
  input  wire [4:0]  pgm_value,   // was inout
  output wire        fb_clk,      // was inout
  output wire        dco_out,     // was inout
  output wire [4:0]  dout,
  output wire        sign
);
  reg [4:0] alpha_var_buf;
  reg [4:0] beta_var_buf;
  reg [4:0] dco_offset_buf;
  reg [4:0] dco_thresh_buf;
  reg [4:0] kdco_buf;
  reg [3:0] ndiv;

  wire [4:0] filter_out;
  wire [4:0] integ_out;
  wire       filter_sign;
  wire       integ_sign;

  wire alpha_en, beta_en, dco_offset_en, dco_thresh_en, kdco_en, ndiv_ld;

  // programming option selects
  assign ndiv_ld       = (pgm) ? ((param_sel==3'd0)?1:0) : 0;
  assign alpha_en      = (pgm) ? ((param_sel==3'd1)?1:0) : 0;
  assign beta_en       = (pgm) ? ((param_sel==3'd2)?1:0) : 0;
  assign dco_offset_en = (pgm) ? ((param_sel==3'd3)?1:0) : 0;
  assign dco_thresh_en = (pgm) ? ((param_sel==3'd4)?1:0) : 0;
  assign kdco_en       = (pgm) ? ((param_sel==3'd5)?1:0) : 0;

  // output select
  assign {sign, dout}  = (out_sel) ? {integ_sign,integ_out} : {filter_sign, filter_out};

  // core
  adpll_5bit u0(
    .clk           (clk),
    .reset         (rst),
    .clk90         (clk90),
    .clk_ref       (clk_ref),
    .ndiv          (ndiv),
    .alpha_var     (alpha_var_buf),
    .beta_var      (beta_var_buf),
    .dco_offset    (dco_offset_buf),
    .dco_thresh_val(dco_thresh_buf),
    .kdco          (kdco_buf),
    .fb_clk        (fb_clk),
    .integ_out     (integ_out),
    .integ_sign    (integ_sign),
    .filter_out    (filter_out),
    .filter_sign   (filter_sign),
    .dco_out       (dco_out)
  );

  // programming flops
  always @(posedge clk or posedge clr) begin
    if (clr)        ndiv <= 4'd0;
    else if (ndiv_ld) ndiv <= pgm_value[3:0];
  end

  always @(posedge clk or posedge clr) begin
    if (clr)        alpha_var_buf <= 5'd0;
    else if (alpha_en) alpha_var_buf <= pgm_value;
  end

  always @(posedge clk or posedge clr) begin
    if (clr)        beta_var_buf <= 5'd0;
    else if (beta_en) beta_var_buf <= pgm_value;
  end

  always @(posedge clk or posedge clr) begin
    if (clr)        dco_offset_buf <= 5'd0;
    else if (dco_offset_en) dco_offset_buf <= pgm_value;
  end

  always @(posedge clk or posedge clr) begin
    if (clr)        dco_thresh_buf <= 5'd0;
    else if (dco_thresh_en) dco_thresh_buf <= pgm_value;
  end

  always @(posedge clk or posedge clr) begin
    if (clr)        kdco_buf <= 5'd0;
    else if (kdco_en) kdco_buf <= pgm_value;
  end
endmodule

// -----------------------------------------------------------------------------
// ADPLL core
// -----------------------------------------------------------------------------
module adpll_5bit(
  input  wire        clk,
  input  wire        reset,
  input  wire        clk90,
  input  wire        clk_ref,
  input  wire [3:0]  ndiv,
  input  wire [4:0]  alpha_var,
  input  wire [4:0]  beta_var,
  input  wire [4:0]  dco_offset,
  input  wire [4:0]  dco_thresh_val,
  input  wire [4:0]  kdco,
  output wire        fb_clk,        // was inout
  output wire [4:0]  integ_out,
  output wire        integ_sign,
  output wire [4:0]  filter_out,    // was inout
  output wire        filter_sign,   // was inout
  output wire        dco_out        // was inout
);
  wire [31:0] up_error, dwn_error;
  wire [4:0]  bin_up_error, bin_dwn_error, bin_error;
  wire        error_sign;
  wire        freq_div_buf;
  wire        clk2x;

/* (remove clk2x entirely) */
/* ... */
dco_5bit i5_dco(.clk(clk), .reset(reset), .kdco(kdco),
                .ctrl_sign(filter_sign), .ctrl(filter_out),
                .dco_offset(dco_offset), .thresh_val(dco_thresh_val),
                .dco_clk(dco_out));

  // 4. Loop filter
  pi_filter_5bit i4_pi_filter(.clk(clk), .reset(reset), .error_sign(error_sign), .error(bin_error),
                              .alpha_var(alpha_var), .beta_var(beta_var),
                              .integ_out(integ_out), .integ_sign(integ_sign),
                              .filter_out(filter_out), .filter_sign(filter_sign));

  // 5. DCO
  dco_5bit i5_dco(.clk(clk2x), .reset(reset), .kdco(kdco),
                  .ctrl_sign(filter_sign), .ctrl(filter_out),
                  .dco_offset(dco_offset), .thresh_val(dco_thresh_val),
                  .dco_clk(dco_out));

  // 6. Divider
  freq_divider_5bit i6_freq_div(.clk(dco_out), .reset(reset), .ndiv(ndiv), .freq_div_out(freq_div_buf));

  // 7. Mux divider or raw dco
  assign fb_clk = (ndiv==4'd0) ? dco_out : freq_div_buf;
endmodule

// -----------------------------------------------------------------------------
// Thermometer-coded TDC PD (all logic synchronous to clk)
// -----------------------------------------------------------------------------
module tdc_sr_5bit(
  input  wire       clk,       // TT clock domain (50 MHz)
  input  wire       reset,
  input  wire       clk_ref,   // async
  input  wire       fb_clk,    // async
  output reg [31:0] up_error,
  output reg [31:0] dwn_error
);
  // 1) Synchronize async clocks into clk domain
  reg [2:0] clk_ref_sync, fb_clk_sync;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      clk_ref_sync <= 3'b000;
      fb_clk_sync  <= 3'b000;
    end else begin
      clk_ref_sync <= {clk_ref_sync[1:0], clk_ref};
      fb_clk_sync  <= {fb_clk_sync[1:0],  fb_clk};
    end
  end

  // 2) Rising edge detection (clk domain)
  wire clk_ref_rise =  clk_ref_sync[2] & ~clk_ref_sync[1];
  wire fb_clk_rise  =  fb_clk_sync[2]  & ~fb_clk_sync[1];

  // 3) Sequential PD in clk domain
  reg start, up, dwn;
  reg reset_trig;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      start      <= 1'b0;
      up         <= 1'b0;
      dwn        <= 1'b0;
      reset_trig <= 1'b1;
    end else begin
      // Start after the first clk_ref edge
      if (clk_ref_rise)
        start <= 1'b1;

      // Assert UP/DWN on edges
      if (clk_ref_rise)
        up <= start;
      if (fb_clk_rise)
        dwn <= start;

      // Reset when both asserted
      reset_trig <= up & dwn;
      if (reset_trig) begin
        up  <= 1'b0;
        dwn <= 1'b0;
      end
    end
  end

  // 4) TDC shift registers (clk domain)
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      up_error  <= 32'd0;
      dwn_error <= 32'd0;
    end else if (reset_trig) begin
      up_error  <= 32'd0;
      dwn_error <= 32'd0;
    end else begin
      up_error[0]     <= up;
      up_error[31:1]  <= up_error[30:0];
      dwn_error[0]    <= dwn;
      dwn_error[31:1] <= dwn_error[30:0];
    end
  end
endmodule

// -----------------------------------------------------------------------------
// 5-bit PI filter
// -----------------------------------------------------------------------------
module pi_filter_5bit(
  input  wire       clk,
  input  wire       reset,
  input  wire       error_sign,
  input  wire [4:0] error,
  input  wire [4:0] alpha_var,
  input  wire [4:0] beta_var,
  output wire [4:0] integ_out,
  output wire       integ_sign,
  output wire [4:0] filter_out,
  output wire       filter_sign
);
  reg  [4:0] integ_store;
  reg        integ_store_sign;
  wire [4:0] integ_var = error * alpha_var;
  wire [4:0] prop_var  = error * beta_var;

  // Delay
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      integ_store      <= 5'd0;
      integ_store_sign <= 1'b0;
    end else begin
      integ_store      <= integ_out;
      integ_store_sign <= integ_sign;
    end
  end

  // Integrator sum
  acs_5bit acs0(.sign_in1(error_sign), .in1(integ_var),
                .sign_in2(integ_store_sign), .in2(integ_store),
                .sum(integ_out), .sign_out(integ_sign));

  // Filter out = prop + integ
  acs_5bit acs1(.sign_in1(error_sign), .in1(prop_var),
                .sign_in2(integ_sign), .in2(integ_out),
                .sum(filter_out), .sign_out(filter_sign));
endmodule

// -----------------------------------------------------------------------------
// Ones counter (32 -> 5 bits)
// -----------------------------------------------------------------------------
// Fast 32-bit popcount using a balanced adder tree.
// Latency: 0 cycles (pure combinational). Add the optional register if needed.
module ones_counter_5bit(
  input  wire [31:0] data_in,
  output wire [4:0]  data_out
);
  // 32 → 16 (2-bit sums), 16 → 8 (3-bit), 8 → 4 (4-bit), 4 → 2 (5-bit), 2 → 1 (5-bit)
  wire [1:0] s16 [15:0];
  genvar i;
  generate
    for (i=0;i<16;i=i+1) begin : L1
      assign s16[i] = data_in[2*i] + data_in[2*i+1];
    end
  endgenerate

  wire [2:0] s8  [7:0];
  generate
    for (i=0;i<8;i=i+1) begin : L2
      assign s8[i] = s16[2*i] + s16[2*i+1]; // max 2+2 = 4 -> fits in 3 bits
    end
  endgenerate

  wire [3:0] s4 [3:0];
  generate
    for (i=0;i<4;i=i+1) begin : L3
      assign s4[i] = s8[2*i] + s8[2*i+1];   // max 3+3 = 6 -> fits in 4 bits
    end
  endgenerate

  wire [4:0] s2 [1:0];
  assign s2[0] = s4[0] + s4[1];             // max 4+4 = 8 -> fits in 5 bits
  assign s2[1] = s4[2] + s4[3];

  assign data_out = s2[0] + s2[1];          // max 8+8 = 16 -> fits in 5 bits

  // OPTIONAL PIPELINE (uncomment if timing still misses by a hair):
  // reg [4:0] r_data_out;
  // always @(posedge clk) r_data_out <= s2[0] + s2[1];
  // assign data_out = r_data_out;
endmodule


// -----------------------------------------------------------------------------
// DCO (fixed: single ACS instance name)
// -----------------------------------------------------------------------------
module dco_5bit(
  input  wire       clk,
  input  wire       reset,
  input  wire [4:0] kdco,
  input  wire       ctrl_sign,
  input  wire [4:0] ctrl,
  input  wire [4:0] dco_offset,
  input  wire [4:0] thresh_val,
  output reg        dco_clk
);
  // 1) Buffer control on reset
  wire [4:0] ctrl_buf = (reset) ? 5'd0 : ctrl;

  // 2) Pipeline multiply to ease timing
  reg  [4:0] phase_r;
  always @(posedge clk or posedge reset) begin
    if (reset) phase_r <= 5'd0;
    else       phase_r <= (ctrl_buf * kdco) >> 1;
  end

  // 3) Compute threshold = thresh_val (+/-) phase_r, then add offset, clamp
  wire [4:0] thresh_buf;
  wire       thresh_sign;

  // (only one ACS instance in this module)
  acs_5bit acs_thresh(
    .sign_in1(1'b0),      .in1(thresh_val),
    .sign_in2(~ctrl_sign), .in2(phase_r),
    .sum(thresh_buf),     .sign_out(thresh_sign)
  );

  wire [4:0] thresh_buf2 = thresh_buf + dco_offset;
  wire [4:0] thresh      = (thresh_sign) ? 5'd0
                                         : (thresh_buf2 > 5'd30 ? 5'd31 : thresh_buf2);

  // 4) Toggle output based on threshold
  reg  [4:0] counter;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      dco_clk <= 1'b0;
      counter <= 5'd0;
    end else begin
      if (counter >= thresh) begin
        dco_clk <= ~dco_clk;
        counter <= dco_offset;
      end else begin
        counter <= counter + 1;
      end
    end
  end
endmodule


// -----------------------------------------------------------------------------
// Programmable frequency divider (<= in sequential logic)
// -----------------------------------------------------------------------------
module freq_divider_5bit(
  input  wire       clk,
  input  wire       reset,
  input  wire [3:0] ndiv,
  output reg        freq_div_out
);
  wire [3:0] thresh = ndiv >> 1;
  reg  [3:0] counter;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      counter      <= 4'd0;
      freq_div_out <= 1'b0;
    end else begin
      if (counter >= thresh) begin
        freq_div_out <= ~freq_div_out;
        counter      <= 4'd0;
      end else begin
        counter      <= counter + 1;
      end
    end
  end
endmodule

// -----------------------------------------------------------------------------
// 5-bit Adder/Subtractor with sign
// -----------------------------------------------------------------------------
module acs_5bit(
  input  wire       sign_in1,
  input  wire [4:0] in1,
  input  wire       sign_in2,
  input  wire [4:0] in2,
  output wire [4:0] sum,
  output wire       sign_out
);
  wire [4:0] min1 = ~in1 + 1;
  wire [4:0] min2 = ~in2 + 1;

  wire [4:0] in1_buf = sign_in1 ? min1 : in1;
  wire [4:0] in2_buf = sign_in2 ? min2 : in2;

  wire [4:0] result = in1_buf + in2_buf;
  wire [4:0] sbuf   = result;

  wire comp = (in1 > in2);
  wire eq   = (in1 == in2);

  assign sign_out = ((sign_in1 & sign_in2) | (sign_in2 & (~comp)) | (sign_in1 & comp)) & (~eq)
                  | (sign_in1 & sign_in2 & (~comp) & eq);

  assign sum = sign_out ? (~sbuf + 1) : sbuf;
endmodule

`default_nettype wire
