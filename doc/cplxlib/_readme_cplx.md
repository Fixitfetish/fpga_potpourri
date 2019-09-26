\brief This file includes the DOXYGEN documentation entry page of the CPLX Library.

\page CPLX_LIBRARY CPLX Library Overview

Introduction
============

The main goal of the CPLX library is to simplify the process of moving designs between
different FPGA device types and vendors with different DSP cell primitives.
For this reason all entities in this library do not directly include any device
type or vendor specific code but use entities of the DSP library instead.

The CPLX library includes
* common complex record type 
* basic building blocks for complex arithmetic
* support of rounding, clipping/saturation and overflow detection
* abstraction layer to hide FPGA device specific DSP primitives



Contents
========

|Entity Name               | Feature 1 | Feature 2  | Description
|:-------------------------|:---------:|:----------:|:-----------------
|cplx_exp                  | ---       | ---        | Complex exponential function
|cplx_fifo_sync            | ---       | ---        | Synchronous FIFO for complex type
|cplx_mult                 | ---       | ---        | N parallel and synchronous complex multiplications
|cplx_mult_accu            | ---       | ---        | N complex multiplications and accumulation of all results
|cplx_mult_sum             | ---       | ---        | N complex multiplications and summation of all results
|cplx_noise_normal         | ---       | ---        | Complex noise generator with normal (Gauss) distribution
|cplx_noise_uniform        | ---       | ---        | Complex noise generator with uniform distribution
|cplx_pipeline             | ---       | ---        | Delay pipeline with N stages
|cplx_vector_pipeline      | ---       | ---        | Delay vector pipeline with N stages
|cplx_vector_serialization | ---       | ---        | Serialize length N vector into data stream of N consecutive cycles
|cplx_vectorization        | ---       | ---        | Parallelize data stream of N consecutive cycles into length N vector
|cplx_weight               | ---       | ---        | N parallel and synchronous complex scaling
|cplx_weight_accu          | ---       | ---        | N complex scaling and accumulation of all results
|cplx_weight_sum           | ---       | ---        | N complex scaling and summation of all results

* MULT = full complex multiplication
* WEIGHT = multiply complex with real factor

CPLX Package
============

The complex package cplx_pkg includes basic types, functions and procedures for complex integer
arithmetic that are used for e.g. digital signal processing. A common complex data interface
supports FPGA developers to handle complex data streams and pipelines in an easier and quicker way.
The package is based on the IEEE "numeric_std" package and also needs the "ieee_extension" package
that includes the required additional "signed" arithmetic features.
The cplx_pkg is available for VHDL-1993 and VHDL-2008. 
While the VHDL-1993 variant has limitations and might need to be extended manually the VHDL-2008
variant has the full flexibility in terms of supported bit resolution.
Both variants have been developed to be more or less compatible.

The main interface base type is the complex record "CPLX" which includes the most common signals
required for pipelining and streaming of complex data.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- general unconstrained complex type (VHDL-2008)
  type cplx is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    ovf : std_logic; -- data overflow (or saturation/clipping)
    re  : signed; -- data real component ("downto" direction assumed)
    im  : signed; -- data imaginary component ("downto" direction assumed)
  end record;
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

An additional complex vector base type supports multiple parallel complex data streams.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- general unconstrained complex vector type ("to" direction assumed)
  type cplx_vector is array(integer range <>) of cplx; -- VHDL-2008
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Since unconstrained arrays in records are not supported in VHDL-1993 only a limited set of types is
predefined. The VHDL-1993 variant can be extended to any wanted data resolution if needed.
In VHDL-2008 subtypes with constrained data resolution are derived from the base types as follows:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  subtype cplx16 is cplx(re(15 downto 0), im(15 downto 0)); -- VHDL-2008
  subtype cplx16_vector is cplx_vector(open)(re(15 downto 0), im(15 downto 0)); -- VHDL-2008
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Note that always the base types or subtypes of the base types must be used.
Signals can be declared as follows: 

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  signal a16 : cplx(re(15 downto 0), im(15 downto 0)); -- use base type (VHDL-2008 only)
  signal b16 : cplx16; -- use predefined subtype (i.e. base type in VHDL-1993)

  signal vec_a16 : cplx_vector(0 to 3)(re(15 downto 0), im(15 downto 0)); -- use base type (VHDL-2008 only)
  signal vec_b16 : cplx16_vector(0 to 3); -- use predefined subtype (i.e. base type in VHDL-1993)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Some options are predefined to switch on/off commonly used features.
By default all options are disabled to keep to FPGA resource requirements low.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  type cplx_option is (
    '-', -- don't care, use defaults
    'D', -- round down towards minus infinity, floor (default, just remove LSBs)
    'I', -- round towards plus/minus infinity, i.e. away from zero
    'N', -- round to nearest (standard rounding, i.e. +0.5 and then remove LSBs)
    'O', -- enable overflow/underflow detection (by default off)
    'R', -- use reset on RE/IM (set RE=0 and IM=0)
    'S', -- enable saturation/clipping (by default off)
    'U', -- round up towards plus infinity, ceil
    'X'  -- ignore/discard input overflow flag
    'Z'  -- round towards zero, truncate
  );
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The operation mode is a combination of one or several options and can be set for each function or
procedure separately. Note that some options can not be combined, e.g. different rounding options.
Use options carefully and only when really required. Some options can have a negative influence on
logic consumption and timing.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  type cplx_mode is array(integer range <>) of cplx_option; -- the default mode is "-"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Example: The mode "ROS" switches on data reset, overflow detection and saturation.


RESET
=====
There are three ways of resetting.
1. Disable reset - constantly force cplx.rst='0' in the beginning of the pipeline.
   RST will not be considered and will be optimized out.
2. Reset only control signals VLD and OVF - drive cplx.rst='1' as needed. 
   RST propagates through the pipeline and resets the control signals in each pipeline stage when cplx.rst='1'.
3. Reset data and control signals -
   Same as 2.) but additionally use option 'R' to reset real and imaginary data to 0 when cplx.rst='1'.

Note that the 'R' option typically increases the reset fanout since all data bit are resets. 
Hence, it is recommended to use the 'R' option only if really needed.
   
Furthermore manual resetting is always possible, i.e. not using cplx.rst but resetting the whole CPLX record.
The functions cplx_reset() and cplx_vector_reset() are useful to generate a constant reset value. Examples:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  signal b16 : cplx16 := cplx_reset(16,"R"); -- with RE/IM reset
  signal vec_b16 : cplx16_vector(0 to 3) := cplx_vector_reset(16,4,"-"); -- without RE/IM reset
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Another possibility is to plug a reset block into the data pipeline.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  dout <= cplx_reset(din,"R"); -- with RE/IM reset
  vec_dout <= cplx_vector_reset(vec_din); -- without RE/IM reset
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


RESIZE FUNCTIONS
================
The complex resize operation is similar to the numeric_std resize.
Sign bits are extended when resizing up. MSBs are discarded when resizing down.
Resizing down supports saturation/clipping and overflow detection.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- function
  r18 <= resize(b16,18,'X'); -- resize up and ignore input overflows 
  vec_r12 <= resize(vec_b16,12,"SO"); -- resize down with overflow detection and saturation/clipping
  
  -- procedure (automatic resize from input to output length)
  resize(b16,r18,'X'); -- resize up and ignore input overflows 
  resize(vec_b16,vec_r12,"SO"); -- resize down with overflow detection and saturation/clipping
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 

ARITHMETIC FUNCTIONS
====================
**Basic** functions
* Complex negation is supported, i.e. overloading of the minus operator. Note that overflow can occur when real or imaginary input is most-negative number.
* Complex conjugate function **conj()** is available. CAUTION : overflow can occur when imaginary input is most-negative number.
* The function **swap()** swaps the real and imaginary component.

**Addition** (using FPGA logic not DSP !)
* addition of complex numbers of different length is always supported
* supported for single complex numbers and complex vectors

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- plus operator overloading
  r18 <= a18 + b16; -- output length is maximum of both input lengths
  
  -- function
  r15 <= add(a18,b16,15,"SO"); -- variable output length with resize and options
  r <= add(a18,b16,r.re'length,"SO"); -- variable output length with resize and options
  
  -- procedure (automatic resize from input to output length)
  add(a18,b16,r15,"SO"); -- variable output length with resize and options
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Summation** of vector elements. This function is critical because many successive logic elements might be required.
Hence, the function sum() is only recommended for vectors with a few elements and/or smaller bit widths.
Note that pipeline registers cannot be added as part of the function. An adder tree pipeline could be used instead.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl
  -- function
  r20 <= sum(vec_a18,20,"SO"); -- variable output length with resize and options
  r <= sum(vec_a18,r.re'length,"SO"); -- variable output length with resize and options
  
  -- procedure (automatic resize from input to output length)
  sum(vec_a18,r20,"SO"); -- variable output length with resize and options
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Subtraction** (using FPGA logic not DSP !)
* subtraction of complex numbers of different length is always supported
* supported for single complex numbers and complex vectors

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- minus operator overloading
  r18 <= a18 - b16; -- output length is maximum of both input lengths
  
  -- function
  r15 <= sub(a18,b16,15,"SO"); -- variable output length with resize and options
  r <= sub(a18,b16,r.re'length,"SO"); -- variable output length with resize and options
  
  -- procedure (automatic resize from input to output length)
  sub(a18,b16,r15,"SO"); -- variable output length with resize and options
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


SHIFT FUNCTIONS
===============
**shift_left()** : Complex signed shift-left by n bits with optional clipping/saturation and overflow detection.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- function
  r18 <= shift_left(a18,4,"SO"); -- output length equals input length

  -- function (vector)
  vec_r18 <= shift_left(vec_a18,4,"SO"); -- output length equals input length
  
  -- procedure (automatic resize from input to output length)
  shift_left(a18,r20,4,"SO"); -- variable output length with resize
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**shift_right()** : Complex signed shift-right by n bits with optional rounding.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- function
  r18 <= shift_right(a18,4,"N"); -- output length equals input length

  -- function (vector)
  vec_r18 <= shift_right(vec_a18,4,"N"); -- output lengths equal input length
  
  -- procedure (automatic resize from input to output length)
  shift_right(a18,r12,4,"NOS"); -- variable output length with resize
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

CONVERSION FUNCTIONS
====================
 **reverse()** :
Reverse order of vector elements without changing the index direction.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- function (output vector length equals input vector length)
  cplx_vector <= reverse(cplx_vector);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**to_cplx_vector()** :
Merge separate vectors of signed real and imaginary values into one CPLX vector.
Input real and imaginary vectors must have same length.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- function (output vector length equals input vector length)
  vec_r18 <= to_cplx_vector(re=>vec_re18, im=>vec_im18, vld=>valid, rst=>reset);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**real() / imag()** : 
Extract all real or imaginary components of a CPLX vector and output as signed vector.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  -- function (output vector length equals input vector length)
  vec_re <= real(cplx_vector);
  vec_im <= imag(cplx_vector);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


More TODO ...

---
MIT License : Copyright (c) 2017-2019 Fixitfetish
 - <https://opensource.org/licenses/MIT>
 - <https://en.wikipedia.org/wiki/MIT_License>
