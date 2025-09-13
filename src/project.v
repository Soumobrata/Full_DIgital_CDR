/* SPDX-License-Identifier: Apache-2.0 */
`default_nettype none

// Top of the ADPLL core (NO TinyTapeout pads here)
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
    .clk          (clk),
    .reset        (rst),
    .clk90        (clk90),
    .clk_ref      (clk_ref),
    .ndiv         (ndiv),
    .alpha_var    (alpha_var_buf),
    .beta_var     (beta_var_buf),
    .dco_offset   (dco_offset_buf),
    .dco_thresh_val(dco_thresh_buf),
    .kdco         (kdco_buf),
    .fb_clk       (fb_clk),
    .integ_out    (integ_out),
    .integ_sign   (integ_sign),
    .filter_out   (filter_out),
    .filter_sign  (filter_sign),
    .dco_out      (dco_out)
  );

  // programming flops
  always @(posedge ndiv_ld or posedge clr) begin
    if (~clr) ndiv <= pgm_value[3:0];
    else      ndiv <= 4'd0;
  end

  always @(posedge alpha_en or posedge clr) begin
    if (~clr) alpha_var_buf <= pgm_value;
    else      alpha_var_buf <= 5'd0;
  end

  always @(posedge beta_en or posedge clr) begin
    if (~clr) beta_var_buf <= pgm_value;
    else      beta_var_buf <= 5'd0;
  end

  always @(posedge dco_offset_en or posedge clr) begin
    if (~clr) dco_offset_buf <= pgm_value;
    else      dco_offset_buf <= 5'd0;
  end

  always @(posedge dco_thresh_en or posedge clr) begin
    if (~clr) dco_thresh_buf <= pgm_value;
    else      dco_thresh_buf <= 5'd0;
  end

  always @(posedge kdco_en or posedge clr) begin
    if (~clr) kdco_buf <= pgm_value;
    else      kdco_buf <= 5'd0;
  end
endmodule

// 5-bit ADPLL core
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

  // 1. Sampling clock 2x
  assign clk2x = clk ^ clk90;

  // 2. Phase Detection
  tdc_sr_5bit i0_tdc(.clk(clk), .reset(reset), .clk_ref(clk_ref), .fb_clk(fb_clk),
                     .up_error(up_error), .dwn_error(dwn_error));

  // 3. Thermo -> binary & subtract
  ones_counter_5bit i1_oc(.data_in(up_error),  .data_out(bin_up_error));
  ones_counter_5bit i2_oc(.data_in(dwn_error), .data_out(bin_dwn_error));
  acs_5bit i3_sub(.sign_in1(1'b0), .in1(bin_up_error),
                  .sign_in2(1'b1), .in2(bin_dwn_error),
                  .sum(bin_error), .sign_out(error_sign));

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

// Thermometer-coded TDC PD
module tdc_sr_5bit(
  input  wire        clk,
  input  wire        reset,
  input  wire        clk_ref,
  input  wire        fb_clk,
  output reg [31:0]  up_error,
  output reg [31:0]  dwn_error
);
  reg start;
  reg up, dwn;
  reg reset_trig;

  // 1. make synchronous reset for PD/TDC
  always @(posedge clk or posedge reset) begin
    if (reset) reset_trig <= 1'b1;
    else       reset_trig <= up & dwn;
  end

  // 2. UP
  always @(posedge clk_ref or posedge reset_trig) begin
    if (reset_trig) up <= 1'b0;
    else            up <= start;
  end

  // 3. DOWN
  always @(posedge fb_clk or posedge reset_trig) begin
    if (reset_trig) dwn <= 1'b0;
    else            dwn <= start;
  end

  // 4. TDC shift registers
  always @(posedge clk or posedge reset_trig) begin
    if (reset_trig) begin
      up_error  <= 32'd0;
      dwn_error <= 32'd0;
    end else begin
      up_error[0]     <= up;
      up_error[31:1]  <= up_error[30:0];
      dwn_error[0]    <= dwn;
      dwn_error[31:1] <= dwn_error[30:0];
    end
  end

  // 5. start after clk_ref
  always @(posedge clk_ref or posedge reset) begin
    if (reset) start <= 1'b0;
    else       start <= 1'b1;
  end
endmodule

// 5-bit PI filter
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

// Ones counter (32 -> 5 bits)
module ones_counter_5bit(
  input  wire [31:0] data_in,
  output wire [4:0]  data_out
);
  wire [4:0] d[31:0];
  genvar i;
  generate
    for (i=0; i<32; i=i+1) begin : G
      assign d[i] = {4'b0000, data_in[i]};
    end
  endgenerate
  assign data_out =
      d[0] + d[1] + d[2] + d[3] + d[4] + d[5] + d[6] + d[7] +
      d[8] + d[9] + d[10] + d[11] + d[12] + d[13] + d[14] + d[15] +
      d[16] + d[17] + d[18] + d[19] + d[20] + d[21] + d[22] + d[23] +
      d[24] + d[25] + d[26] + d[27] + d[28] + d[29] + d[30] + d[31];
endmodule

// DCO
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
  wire [4:0] ctrl_buf   = (reset) ? 5'd0 : ctrl;
  wire [4:0] phase      = (ctrl_buf * kdco) >> 1;

  wire [4:0] thresh_buf;
  wire       thresh_sign;
  acs_5bit acs0(.sign_in1(1'b0), .in1(thresh_val),
                .sign_in2(~ctrl_sign), .in2(phase),
                .sum(thresh_buf), .sign_out(thresh_sign));

  wire [4:0] thresh_buf2 = thresh_buf + dco_offset;
  wire [4:0] thresh      = (thresh_sign) ? 5'd0
                                         : (thresh_buf2 > 5'd30 ? 5'd31 : thresh_buf2);

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

// Programmable frequency divider
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
      counter      = 4'd0;
      freq_div_out = 1'b0;
    end else begin
      if (counter >= thresh) begin
        freq_div_out = ~freq_div_out;
        counter      = 4'd0;
      end else begin
        counter      = counter + 1;
      end
    end
  end
endmodule

// 5-bit Adder/Subtractor with sign
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
