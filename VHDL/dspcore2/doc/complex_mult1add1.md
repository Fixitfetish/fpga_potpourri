# COMPLEX_MULT1ADD1

This module multiplies two complex factors X and Y and adds one more complex summand Z.
Several results can be accumulated over time: `P = P + X*Y + Z`.
Furthermore, dynamic product negation and complex conjate of inputs X and Y are supported.
The module is the basis for many other modules like e.g.
* complex multiply accumulate
* complex dot product

Multiple instances of this module can be connected/chained in different ways to realize special operations.

## Overview

The following figure shows the abstract behavioral diagram of this module.
Note that all DSP internal pipeline registers are transformed into input registers
to demonstrate to concept. Implementation details are described further below. 

<p align="center">
  <img src="./complex_mult1add1.drawio.svg" width="50%">
</p>

The additional output logic is mostly implemented in logic and allows optional
* shift-right and rounding
* clipping/saturation
* overflow detection
* additional output pipeline registers


## Xilinx/AMD

The Xilinx/AMD implementation is rougly as follows

<p align="center">
  <img src="./complex_mult1add1_xilinx.drawio.svg" width="70%">
</p>

NOTES
* At least 2 input register are recommended for X and Y (i.e. one DSP input register and the DSP internal pipeline register M).
* The ALU supports a maximum of 3 simultaneous summands. Input valid signals dynamically control the ALU operation.
  - The Multiplier output only contributes to ALU result when inputs X and Y are valid.
  - The Z input contributes when Z is valid.
  - The Chain input contributes when CHAININ is valid.
  - The Accumulator feedback contributes when CLR=0. Round bit is added when CLR=1 and rounding is enabled.
* Dynamic complex conjugate of X and/or Y is supported.
* Dynamic product negation is supported.
* In general, to save resources and to improve timing, ...
  - set entity generics according to your needs 
  - leave unused inputs unconnected/open or set constant invalid and zero 
  - feed control inputs with constants if dynamic operation is not required
  - leave unused ouptuts open or terminate with unused dummy signals
* Typically, DSP internal round bit addition is supported.
  If DSP internal round bit addition is not possible then the round bit is added within the output logic.
  - If accumulation is possible and enabled then the round bit is added to the accu register in the first accumulation cycle when the accu is cleared.
  - If accumulation is disabled then the round bit is added in the first chain link where the chain input is unused.

### References

* **DSP48E2**: [Xilinx - UltraScale Architecture DSP Slice (UG579)](https://docs.amd.com/v/u/en-US/ug579-ultrascale-dsp)
* **DSP58**: [Xilinx/AMD - Versal ACAP DSP Engine (AM004)](https://docs.amd.com/r/en-US/am004-versal-dsp-engine)

### 4-DSP Implementation

This implementation requires 4 DPSs cells per complex multiplication.
The preadder functionality is not required but can be used for negation purposes.

 * `COre = CIre + Xre*Yre + Zre`
 * `COim = CIim + Xre*Yim + Zim`
 * `Result RE = COre - Xim*Yim = CIre + Xre*Yre - Xim*Yim + Zre`
 * `Result IM = COim + Xim*Yre = CIim + Xre*Yim + Xim*Yre + Zim`

Features
* Chaining and summation of N products is possible.
* The minimum latency is 2+2*N cycles.
* X input (27-bit) can have higher resolution then Y input (18-bit DSP48E2, 24-bit DSP58).
* An additional Z summand input is supported.
* Accumulation is supported.

### 3-DSP Implementation

This implementation requires 3 DPSs cells with preadder functionality per complex multiplication.
Several implementations with a slightly different mapping to DSP cells are possible.
The following split tries to use the DSP internal negation feature as efficient as possible and to avoid additional negation in logic.

* `Z = (Yre - Yim) * Xim`
* `Result RE = CIre + ( Xre - Xim) * Yre + Z  = CIre + Xre*Yre - Xim*Yim`
* `Result IM = CIim + ( Xre + Xim) * Yim + Z  = CIim + Xre*Yim + Xim*Yre`

Features
* Chaining and summation of N products is possible.
* The minimum latency is 4+N cycles.
* X and Y inputs are limited to same resolution (18-bit DSP48E2, 24-bit DSP58).
* An additional Z summand is **not** supported.
* Accumulation is only supported for N=1 (when simultaneous chain input is not needed).


### 2-DSP Implementation

This implementation requires 2 DPSs cells per complex multiplication and is a special implementation only supported by DSP58/DSPCPLX.

 * `Result RE = CIre + Xre*Yre - Xim*Yim + Zre`
 * `Result IM = CIim + Xre*Yim + Xim*Yre + Zim`

Features
* Chaining and summation of N products is possible.
* The minimum latency is 2+N cycles.
* X and Y inputs are limited to 18-bit.
* An additional Z summand input is supported.
* Final accumulation in last chain link is only supported when simultaneous Z summand or chain input are not needed.
