![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)



# All Digital PLL (ADPLL) on TinyTapeout

Fully programmable all-digital PLL with TDC-based phase detector, PI filter, DCO, and programmable parameters.

- **Top**: `tt_um_adpll`
- **Clock**: 50 MHz global `clk`
- **Reset**: active-low `rst_n` (inverted internally)

## Pinout

| Pin       | Name        | Dir | Notes                                                 |
|-----------|-------------|-----|-------------------------------------------------------|
| ui[0]     | clk90       | In  | Optional external 90° (not guaranteed phase-locked)  |
| ui[1]     | clk_ref     | In  | Reference clock                                      |
| ui[2]     | clr         | In  | Clear programmed values                              |
| ui[3]     | pgm         | In  | Programming enable                                   |
| ui[4]     | out_sel     | In  | Select filter vs integrator output                   |
| ui[7:5]   | param_sel   | In  | Parameter select                                     |
| uo[4:0]   | dout        | Out | Data                                                  |
| uo[5]     | sign        | Out | Sign                                                  |
| uio[0]    | fb_clk      | Out | Feedback clock                                       |
| uio[1]    | dco_out     | Out | DCO output                                           |
| uio[6:2]  | pgm_value   | In  | 5-bit programming value                               |

**Note:** Only one global 50 MHz clock is guaranteed by TinyTapeout. `clk90` via GPIO is not phase-locked.

## Sources
- `src/tt_um_adpll.v` – TT wrapper (pads, reset invert, uio_oe)
- `src/project.v` – All ADPLL modules (no `tt_um_*` here)

License: Apache-2.0
