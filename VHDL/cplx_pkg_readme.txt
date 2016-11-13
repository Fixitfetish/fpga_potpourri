-------------------------------------------------------------------------------
-- FILE    : cplx_pkg_readme.txt
-- AUTHOR  : Fixitfetish
-- DATE    : 13/Nov/2016
-- VERSION : 0.2
-- LICENSE : MIT License  https://opensource.org/licenses/MIT
--                        https://en.wikipedia.org/wiki/MIT_License
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Fixitfetish
-------------------------------------------------------------------------------

The complex package "CPLX_PKG" includes basic types, functions and procedures for complex integer
arithmetic that are used for e.g. digital signal processing. It supports FPGA developers to handle
complex data streams and pipelines in an easier and quicker way using a common complex data
interface.
The package is based on the IEEE "numeric_std" package and also needs the "ieee_extension" package
that includes the required additional "signed" arithmetic and comes with this package. The CPLX_PKG
is available for VHDL-1993 and VHDL-2008. While the VHDL-1993 variant has limitations and might
need to be extended manually the VHDL-2008 variant has the full flexibility in terms of supported
bit resolution. Boths variants have been developed to be more or less compatible.

The main interface base type is the complex record "CPLX" which includes the most common signals
required for pipelining and streaming of complex data.

  -- general unconstrained complex type (VHDL-2008)
  type cplx is
  record
    rst : std_logic; -- reset
    vld : std_logic; -- data valid
    ovf : std_logic; -- data overflow (or saturation/clipping)
    re  : signed; -- data real component ("downto" direction assumed)
    im  : signed; -- data imaginary component ("downto" direction assumed)
  end record;

An additional complex vector base type supports multiple parallel complex data streams.

  -- general unconstrained complex vector type (preferably "to" direction)
  type cplx_vector is array(integer range <>) of cplx; -- VHDL-2008

Since unconstrained arrays in records are not supported in VHDL-1993 only a limited set of types is
predefined. The VHDL-1993 variant can be extended to any wanted data resolution if needed.
In VHDL-2008 subtypes with constrained data resolution are derived from the base types as follows:

  subtype cplx16 is cplx(re(15 downto 0), im(15 downto 0));
  subtype cplx16_vector is cplx_vector(open)(re(15 downto 0), im(15 downto 0));

Note that always the base types or subtypes of the base types must be used.
Signals can be declared as follows: 

  signal a16 : cplx(re(15 downto 0), im(15 downto 0)); -- use base type (VHDL-2008 only)
  signal b16 : cplx16; -- use subtype (i.e. base type in VHDL-1993)

  signal vec_a16 : cplx_vector(0 to 3)(re(15 downto 0), im(15 downto 0)); -- use base type (VHDL-2008 only)
  signal vec_b16 : cplx16_vector(0 to 3); -- use subtype (i.e. base type in VHDL-1993)

Some options are predefined to switch on/off commonly used features.

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

The operation mode is a combination of one or several options and can be set for each function or
procedure separately. Note that some options can not be combined, e.g. different rounding options.

  type cplx_mode is array(integer range <>) of cplx_option; -- the default mode is "-"
  Example: The mode "ROS" switches on data reset, overflow detection and saturation.


RESET
=====
There are three ways of resetting.
1.) Disable reset - constantly force cplx.rst='0' in the begining of the pipeline
    RST will be not considered and will be optimized out.
2.) Reset only control signals VLD and OVF - drive cplx.rst='1' as needed. 
    RST propagates through the pipeline and resets the control signals in each pipeline stage when cplx.rst='1'.
3.) Reset data and control signals
    Same as 2.) but additionally use option 'R' to reset real and imaginary data to 0 when cplx.rst='1'.
Furthermore manual resetting is always possible, i.e. not using cplx.rst but resetting the whole CPLX record.
