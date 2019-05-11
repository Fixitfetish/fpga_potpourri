-------------------------------------------------------------------------------
--! @file       cplx_vector_serialization.rtl_1993.vhdl
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
architecture rtl_1993 of cplx_vector_serialization is
  
  constant N : natural := vec_in'length;
  constant W : natural := vec_in(vec_in'left).re'length;
  
  signal vec_in_q : cplx_vector(0 to N-1);
  signal idx : natural range 0 to N := 0;

begin

  p : process(clk)
  begin
    if rising_edge(clk) then
      if rst='1' then
        vec_in_q <= cplx_vector_reset(W,N);
        idx <= N;
      elsif start='1' then
        vec_in_q <= vec_in;
        idx <= 0;
      else 
        vec_in_q(0 to N-2) <= vec_in_q(1 to N-1);
        vec_in_q(N-1).vld <= '0';
        if idx/=N then idx<=idx+1; end if; 
      end if;
    end if;
  end process;

  idx_out <= idx;
  ser_out <= vec_in_q(0);

end architecture;
