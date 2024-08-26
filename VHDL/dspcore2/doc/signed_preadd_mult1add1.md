# SIGNED_PREADD_MULT1ADD1

This module is the basis for many other and more flexible modules like e.g.
* vector multiplier
* dot product
* complex (vector) multiplication

Multiple instances of this module can be connected/chained in different ways to realize special operations.

## Overview

The following figure shows the abstract behavioral diagram of this module.
Note that all DSP internal pipeline registers are transformed into input registers
to demonstrate to concept. Implementation details are described below. 

<p align="center">
  <img src="./signed_preadd_mult1add1.drawio.svg" width="60%">
</p>

The additional output logic is mostly implemented in logic and allows optional
* rounding
* clipping/saturation
* overflow detection
* additional output pipeline registers


## Xilinx/AMD

The Xilinx/AMD implementation is rougly as follows

<p align="center">
  <img src="./signed_preadd_mult1add1_xilinx.drawio.svg" width="70%">
</p>

NOTES
* The ALU supports a maximum of 3 simultaneous summands. 
* At least 2 input register are recommended for XA, XB and Y.

### DSP48E

Reference: [Xilinx - UltraScale Architecture DSP Slice (UG579)](https://docs.amd.com/v/u/en-US/ug579-ultrascale-dsp)

The DSP48E is used in Ultrascale(+) devices and has the following features
* 27x18 Multiplication, 27-bit XA and XB, 18-bit Y
* 27-bit Preadder
* 48-bit accumulator and output register width


### DSP58

Reference: [Xilinx/AMD - Versal ACAP DSP Engine (AM004)](https://docs.amd.com/r/en-US/am004-versal-dsp-engine)

With Versal ACAP the new DSP58 has been introduced. The main changes to the previous DSP48E in respect to the SIGNED_PREADD_MULT1ADD1 module are
* 27x24 Multiplication, 27-bit XA and XB, 24-bit Y
* additional product negation within multiplier
* 58-bit accumulator and output register width
