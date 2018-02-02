-------------------------------------------------------------------------------
--! @file       cplx_vector_serialization.vhdl
--! @author     Fixitfetish
--! @date       01/May/2017
--! @version    0.20
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
--! See also : cplx_vectorization

entity cplx_vector_serialization is
port (
  clk     : in  std_logic; --! Standard system clock
  rst     : in  std_logic; --! Reset
  start   : in  std_logic; --! Start serialization process (pulse)
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
