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
  assert (vec_out'length>=2)
    report "ERROR in " & cplx_vectorization'INSTANCE_NAME & 
           " Output vector must have at least two elements."
    severity failure;

  assert (vec_out'ascending)
    report "ERROR in " & cplx_vectorization'INSTANCE_NAME & 
           " Output vector must have 'TO' range."
    severity failure;
end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_vectorization is
  
  constant N : natural := vec_out'length;
  constant W : natural := ser_in.re'length;
  
  signal data_in : cplx_vector(0 to N-2);
  signal next_idx : natural range 0 to N-1 := 0;

begin

  -- NOTE:
  -- Consider that vec_out'range might not be "0 to N-1" but e.g. "3 to N+2"

  p : process(clk)
    variable v_din : cplx_vector(0 to N-1);
  begin
    if rising_edge(clk) then
      if rst='1' then
        data_in <= cplx_vector_reset(W,N-1);
        vec_out <= cplx_vector_reset(W,N);
        next_idx <= 0;
      elsif ser_in.vld='1' and next_idx=(N-1) then
        vec_out(vec_out'left to vec_out'right-1) <= data_in;
        vec_out(vec_out'right) <= ser_in;
        next_idx <= 0;
      else
        if ser_in.vld='1' and (start='1' or next_idx/=0) then
          -- note: work-around with variable that also works with N=2
          v_din(0 to N-2) := data_in;
          v_din(N-1) := ser_in;
          data_in <= v_din(1 to N-1);
          next_idx <= next_idx + 1;
        end if;
        for n in vec_out'range loop vec_out(n).vld<='0'; end loop;
      end if;
    end if;
  end process;

end architecture;
