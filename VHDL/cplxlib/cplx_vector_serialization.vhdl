-------------------------------------------------------------------------------
--! @file       cplx_vector_serialization.vhdl
--! @author     Fixitfetish
--! @date       01/May/2017
--! @version    0.20
--! @copyright  MIT License
--! @note       VHDL-1993
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
  assert (vec_in'length>=2)
    report "ERROR in " & cplx_vector_serialization'INSTANCE_NAME & 
           " Input vector must have at least two elements."
    severity failure;

  assert (vec_in'ascending)
    report "ERROR in " & cplx_vector_serialization'INSTANCE_NAME & 
           " Input vector must have 'TO' range."
    severity failure;
end entity;

-------------------------------------------------------------------------------

architecture rtl of cplx_vector_serialization is
  
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
