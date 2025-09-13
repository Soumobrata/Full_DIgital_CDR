# How it works

This project implements a **digital Clock and Data Recovery (CDR)** loop using a custom **open-loop VCO-ADC front-end** as a sampler.

- The **sampler** is based on a phase accumulator (VCO-ADC), which converts the 8-bit input (`ui_in[7:0]`) into sampled outputs.
