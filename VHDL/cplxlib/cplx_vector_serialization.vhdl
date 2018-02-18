-------------------------------------------------------------------------------
--! @file       cplx_vector_serialization.vhdl
--! @author     Fixitfetish
--! @date       17/Feb/2018
--! @version    0.30
--! @note       VHDL-1993
--! @copyright  <https://en.wikipedia.org/wiki/MIT_License> ,
--!             <https://opensource.org/licenses/MIT>
-------------------------------------------------------------------------------
-- Includes DOXYGEN support.
-------------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
library cplxlib;
  use cplxlib.cplx_pkg.all;

--! @brief Serialize a complex vector of length N into a complex data stream of
--! N consecutive cycles.
--!
--! With start='1' the complete input vector icluding RST, VLD and OVF is 
--! captured and serialized. The first complex output with index 0 is the first
--! element of the vector input. After serialization VLD and OVF are set to '0'.
--! For normal operation the start pulse period should be at least N cycles long.  
--!
--! @image html cplx_vector_serialization.svg "" width=600px
--!
--! See also : cplx_vectorization
--!
--! VHDL Instantiation Template:
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{.vhdl}
--! I1 : cplx_vector_serialization
--! port map(
--!   clk        => in  std_logic, -- clock
--!   rst        => in  std_logic, -- reset
--!   start      => in  std_logic, -- start pulse
--!   vec_in     => in  cplx_vector, -- complex vector input
--!   idx_out    => out natural, -- index output
--!   ser_out    => out cplx -- complex output
--! );
--! ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

entity cplx_vector_serialization is
port (
  clk     : in  std_logic; --! Standard system clock
  rst     : in  std_logic; --! Reset
  start   : in  std_logic; --! Start/restart serialization process (pulse)
  vec_in  : in  cplx_vector; --! Data input vector of length N
  idx_out : out natural; --! Data index output
  ser_out : out cplx --! Serial data output stream
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (vec_in'length>=2)
    report "ERROR in " & cplx_vector_serialization'INSTANCE_NAME & 
           " Input vector must have at least two elements."
    severity failure;

  assert (vec_in'ascending)
    report "ERROR in " & cplx_vector_serialization'INSTANCE_NAME & 
           " Input vector must have 'TO' range."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
