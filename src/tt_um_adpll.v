


/* SPDX-License-Identifier: Apache-2.0 */
`default_nettype none

// TinyTapeout wrapper (the ONLY top-level module)
module tt_um_adpll (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1=output, 0=input)
    input  wire       ena,      // design selected
    input  wire       clk,      // 50 MHz global clock
    input  wire       rst_n     // active-low reset
);

  // Internal active-high reset for your blocks
  wire rst = ~rst_n;

  // Inputs from UI
  wire        clk90       = ui_in[0];
  wire        clk_ref     = ui_in[1];
  wire        clr         = ui_in[2];
  wire        pgm         = ui_in[3];
  wire        out_sel     = ui_in[4];
  wire [2:0]  param_sel   = ui_in[7:5];

  // UIO mapping
  wire [4:0]  pgm_value   = uio_in[6:2];
  wire        fb_clk;
  wire        dco_out;

  // Core outputs
  wire [4:0]  dout;
  wire        sign;

  // Drive UIOs and directions
  assign uio_out[0] = fb_clk;      // output
  assign uio_out[1] = dco_out;     // output
  assign uio_out[2] = uio_in[2];   // safe pass-throughs (optional)
  assign uio_out[3] = uio_in[3];
  assign uio_out[4] = uio_in[4];
  assign uio_out[5] = uio_in[5];
  assign uio_out[6] = uio_in[6];
  assign uio_out[7] = ena;         // status

  assign uio_oe[1:0] = 2'b11;      // uio[0], uio[1] are outputs
  assign uio_oe[6:2] = 5'b00000;   // uio[6:2] are inputs
  assign uio_oe[7]   = 1'b0;       // unused

  // Dedicated outputs
  assign uo_out[4:0] = dout;
  assign uo_out[5]   = sign;
  assign uo_out[6]   = 1'b0;
  assign uo_out[7]   = 1'b0;

  // Instantiate ADPLL core wrapper
  adpll_top u_adpll (
    .clk        (clk),
    .rst        (rst),
    .clk90      (clk90),
    .clk_ref    (clk_ref),
    .clr        (clr),
    .pgm        (pgm),
    .out_sel    (out_sel),
    .param_sel  (param_sel),
    .pgm_value  (pgm_value), // input
    .fb_clk     (fb_clk),    // outputs
    .dco_out    (dco_out),
    .dout       (dout),
    .sign       (sign)
  );

  // Silence "unused" warnings if needed
  wire _unused = &{ena, 1'b0};

endmodule

`default_nettype wire




