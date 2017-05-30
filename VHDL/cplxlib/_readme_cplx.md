\brief This file includes the DOXYGEN documentation entry page of the CPLX Library.

\page CPLX_LIBRARY CPLX Library Overview
\section section_intro Introduction
The CPLX library
* basic building blocks for complex arithmetic
* common complex record type 
* support of rounding, clipping/saturation and overflow detection
* abstraction layer to hide FPGA device specific DSP primitives

The main goal of this library is simplify the process of moving designs between
different FPGA device types and vendors with different DSP cell primitives.
For this reason all entities in this library do not directly include any device
type or vendor specific code but use entities of the DSP library instead.

---

\section section_contents Contents


|Entity Name               | Feature 1 | Feature 2  | Description
|:-------------------------|:---------:|:----------:|:-----------------
|cplx_mult                 | ---       | ---        | N parallel and synchronous complex multiplications
|cplx_mult_accu            | ---       | ---        | N complex multiplications and accumulation of all results
|cplx_mult_sum             | ---       | ---        | N complex multiplications and summation of all results
|cplx_pipeline             | ---       | ---        | Delay pipeline with N stages
|cplx_vector_serialization | ---       | ---        | Serialize length N vector into data stream of N consecutive cycles
|cplx_vectorization        | ---       | ---        | Parallelize data stream of N consecutive cycles into length N vector
|cplx_weight               | ---       | ---        | N parallel and synchronous complex scaling
|cplx_weight_accu          | ---       | ---        | N complex scaling and accumulation of all results
|cplx_weight_sum           | ---       | ---        | N complex scaling and summation of all results

---
\section section_pkg CPLX Package

The complex package "CPLX_PKG" includes basic types, functions and procedures for complex integer
arithmetic that are used for e.g. digital signal processing. It supports FPGA developers to handle
complex data streams and pipelines in an easier and quicker way using a common complex data
interface.
The package is based on the IEEE "numeric_std" package and also needs the "ieee_extension" package
that includes the required additional "signed" arithmetic and comes with this package. The CPLX_PKG
is available for VHDL-1993 and VHDL-2008. While the VHDL-1993 variant has limitations and might
need to be extended manually the VHDL-2008 variant has the full flexibility in terms of supported
bit resolution. Both variants have been developed to be more or less compatible.

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
  subtype cplx16 is cplx(re(15 downto 0), im(15 downto 0));
  subtype cplx16_vector is cplx_vector(open)(re(15 downto 0), im(15 downto 0));
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
1.) Disable reset - constantly force cplx.rst='0' in the beginning of the pipeline
    RST will be not considered and will be optimized out.
2.) Reset only control signals VLD and OVF - drive cplx.rst='1' as needed. 
    RST propagates through the pipeline and resets the control signals in each pipeline stage when cplx.rst='1'.
3.) Reset data and control signals
    Same as 2.) but additionally use option 'R' to reset real and imaginary data to 0 when cplx.rst='1'.
Furthermore manual resetting is always possible, i.e. not using cplx.rst but resetting the whole CPLX record.

The functions cplx_reset() and cplx_vector_reset() are useful to generate a constant reset value. Examples:

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
  signal b16 : cplx16 := cplx_reset(16,"R");
  signal vec_b16 : cplx16_vector(0 to 3) := cplx_vector_reset(16,4,"-");
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


RESIZE FUNCTIONS
================
todo

ARITHMETIC FUNCTIONS
====================
todo

SHIFT FUNCTIONS
===============
todo

CONVERSION FUNCTIONS
====================
todo


MIT License : Copyright (c) 2017 Fixitfetish
 - [https://opensource.org/licenses/MIT] (https://opensource.org/licenses/MIT)
 - [https://en.wikipedia.org/wiki/MIT_License] (https://en.wikipedia.org/wiki/MIT_License)
