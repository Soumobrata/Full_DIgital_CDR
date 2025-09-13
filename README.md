
# All Digital PLL (ADPLL) on TinyTapeout

This project implements a **fully programmable all-digital phase-locked loop (ADPLL)** in Verilog.  
It uses a TDC-based phase detector, PI filter, DCO, and programmable parameters for flexibility.

- **Top module**: `tt_um_adpll`
- **Clock**: 50 MHz global `clk` provided by TinyTapeout
- **Reset**: `rst_n` (active-low, inverted internally to active-high)

---

## Pinout

| Pin    | Name / Function     | Direction | Notes |
|--------|---------------------|-----------|-------|
| `ui[0]` | `clk90`             | Input     | External 90° shifted clock (optional; not guaranteed phase-aligned) |
| `ui[1]` | `clk_ref`           | Input     | Reference clock input |
| `ui[2]` | `clr`               | Input     | Clear all programmed values (active-high) |
| `ui[3]` | `pgm`               | Input     | Programming enable (set high while loading parameters) |
| `ui[4]` | `out_sel`           | Input     | Selects filter or integrator output |
| `ui[7:5]` | `param_sel[2:0]`  | Input     | Selects which parameter to program |
| `uo[4:0]` | `dout[4:0]`       | Output    | Filter / integrator data output |
| `uo[5]` | `sign`              | Output    | Sign of filter/integrator output |
| `uo[6]` | —                   | Output    | Unused (0) |
| `uo[7]` | —                   | Output    | Unused (0) |
| `uio[0]` | `fb_clk`           | Output    | Feedback clock from divider/DCO |
| `uio[1]` | `dco_out`          | Output    | Digitally controlled oscillator output |
| `uio[6:2]` | `pgm_value[4:0]` | Input     | 5-bit programming value |
| `uio[7]` | —                  | —         | Unused |

---

## Notes

- Only one global 50 MHz clock is guaranteed in TinyTapeout. An external `clk90` input via `ui[0]` will not be phase-locked or low-jitter with respect to `clk`.  
- Internal reset is **active-high**, so `tt_um_adpll` inverts `rst_n` before passing it down.  
- `uio[0]` and `uio[1]` are outputs (`uio_oe=1`), while `uio[6:2]` are inputs (`uio_oe=0`).  

---

## Source Files

- `src/tt_um_adpll.v` — TinyTapeout wrapper (handles pad mapping, reset inversion, I/O enables).  
- `src/project.v` — Contains all ADPLL submodules:


---

## License

Apache-2.0 (SPDX identifier: `Apache-2.0`)
