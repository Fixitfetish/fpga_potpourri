-------------------------------------------------------------------------------
--! @file       cplx_vectorization.vhdl
--! @author     Fixitfetish
--! @date       06/Jun/2017
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

--! @brief Parallelize a complex data stream of N consecutive cycles into a complex
--! vector of length N.
--!
--! See also : cplx_vector_serialization

entity cplx_vectorization is
port (
  clk     : in  std_logic; --! Standard system clock
  rst     : in  std_logic; --! Reset
  start   : in  std_logic; --! Start serialization process (pulse)
  ser_in  : in  cplx; --! Serial data input stream
  vec_out : out cplx_vector --! Data output vector of length N
);
begin

  -- synthesis translate_off (Altera Quartus)
  -- pragma translate_off (Xilinx Vivado , Synopsys)
  assert (vec_out'length>=2)
    report "ERROR in " & cplx_vectorization'INSTANCE_NAME & 
           " Output vector must have at least two elements."
    severity failure;

  assert (vec_out'ascending)
    report "ERROR in " & cplx_vectorization'INSTANCE_NAME & 
           " Output vector must have 'TO' range."
    severity failure;
  -- synthesis translate_on (Altera Quartus)
  -- pragma translate_on (Xilinx Vivado , Synopsys)

end entity;
